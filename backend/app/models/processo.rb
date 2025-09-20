class Processo < ApplicationRecord
  # Relacionamentos
  belongs_to :cidadao
  belongs_to :relator, optional: true
  has_many :votos, dependent: :destroy
  has_many :julgadores, through: :votos
  has_many :documentos, dependent: :destroy
  has_many :notificacoes, class_name: 'Notificacao', dependent: :destroy

  # Enums
  enum :tipo_infracao, {
    velocidade: 0,
    rodizio: 1,
    semaforo: 2
  }

  enum :status, {
    rascunho: 0,
    triagem: 1,
    distribuido: 2,
    em_analise: 3,
    em_votacao: 4,
    decidido: 5,
    rejeitado: 6
  }

  enum :decisao_final, {
    deferido: 0,
    indeferido: 1
  }, prefix: true

  # Validações
  validates :codigo_acompanhamento, presence: true, uniqueness: true, length: { is: 12 }
  validates :tipo_infracao, presence: true
  validates :status, presence: true
  validates :data_criacao, presence: true
  validates :data_limite, presence: true
  validates :cidadao, presence: true

  # Validações condicionais
  validates :relator, presence: true, if: :requires_relator?
  validates :parecer_relator, presence: true, if: :em_votacao?
  validates :data_decisao, presence: true, if: :decidido?
  validates :decisao_final, presence: true, if: :decidido?
  validates :justificativa_rejeicao, presence: true, if: :rejeitado?

  # Validações customizadas
  validate :data_limite_valida
  validate :transicao_status_valida
  validate :documentos_obrigatorios_presentes, if: :triagem?

  # Callbacks
  before_validation :generate_codigo_acompanhamento, on: :create
  before_validation :set_data_criacao, on: :create
  before_validation :set_data_limite, on: :create
  after_update :atualizar_contador_relator, if: :saved_change_to_relator_id?
  after_update :finalizar_votacao_se_quorum_atingido, if: :em_votacao?

  # Scopes
  scope :por_cidadao, ->(cidadao) { where(cidadao: cidadao) }
  scope :por_relator, ->(relator) { where(relator: relator) }
  scope :por_status, ->(status) { where(status: status) }
  scope :por_tipo_infracao, ->(tipo) { where(tipo_infracao: tipo) }
  scope :vencendo_prazo, -> { where('data_limite <= ?', 2.days.from_now) }
  scope :em_atraso, -> { where('data_limite < ?', Time.current) }
  scope :pendentes, -> { where(status: [:triagem, :distribuido, :em_analise, :em_votacao]) }

  # Métodos de estado
  def pendente?
    !decidido? && !rejeitado?
  end

  def pode_transicionar_para?(novo_status)
    case status.to_sym
    when :rascunho
      [:triagem].include?(novo_status.to_sym)
    when :triagem
      [:distribuido, :rejeitado].include?(novo_status.to_sym)
    when :distribuido
      [:em_analise].include?(novo_status.to_sym)
    when :em_analise
      [:em_votacao, :rejeitado].include?(novo_status.to_sym)
    when :em_votacao
      [:decidido].include?(novo_status.to_sym)
    else
      false
    end
  end

  def transicionar_para!(novo_status, usuario: nil, motivo: nil)
    raise ArgumentError, "Transição inválida de #{status} para #{novo_status}" unless pode_transicionar_para?(novo_status)

    case novo_status.to_sym
    when :triagem
      self.status = :triagem
      criar_notificacao!(:triagem)
    when :distribuido
      distribuir_para_relator!
    when :em_analise
      self.status = :em_analise
      criar_notificacao!(:analise)
    when :em_votacao
      iniciar_votacao!
    when :decidido
      finalizar_processo!
    when :rejeitado
      rejeitar_processo!(motivo)
    end

    save!
  end

  def distribuir_para_relator!
    relator_disponivel = encontrar_relator_disponivel
    raise StandardError, 'Nenhum relator disponível' unless relator_disponivel

    self.relator = relator_disponivel
    self.status = :distribuido
    relator_disponivel.atribuir_processo!
    criar_notificacao!(:distribuicao)
  end

  def iniciar_votacao!
    raise StandardError, 'Parecer do relator é obrigatório' if parecer_relator.blank?

    self.status = :em_votacao
    criar_notificacao!(:votacao)
  end

  def finalizar_processo!
    resultado = calcular_resultado_votacao
    raise StandardError, 'Quórum não atingido' unless resultado[:quorum_atingido]

    self.decisao_final = resultado[:decisao]
    self.data_decisao = Time.current
    self.status = :decidido

    relator.finalizar_processo! if relator
    relator.atualizar_metricas(tempo_total_analise, resultado[:decisao])

    criar_notificacao!(:decisao)
  end

  def rejeitar_processo!(motivo)
    self.status = :rejeitado
    self.justificativa_rejeicao = motivo
    self.data_decisao = Time.current

    relator&.finalizar_processo!
    criar_notificacao!(:decisao)
  end

  # Métodos de votação
  def calcular_resultado_votacao
    total_votos = votos.count
    votos_favoraveis = votos.where(decisao: 'concordo').count
    votos_contrarios = votos.where(decisao: 'discordo').count

    quorum_atingido = total_votos >= 3
    decisao = if quorum_atingido
                votos_favoraveis > votos_contrarios ? 'deferido' : 'indeferido'
              else
                nil
              end

    {
      total_votos: total_votos,
      votos_favoraveis: votos_favoraveis,
      votos_contrarios: votos_contrarios,
      quorum_atingido: quorum_atingido,
      decisao: decisao
    }
  end

  def pode_receber_voto?(julgador)
    em_votacao? && !julgador.ja_votou_processo?(self) && julgador.pode_votar_processo?(self)
  end

  # Métodos auxiliares
  def dias_para_vencimento
    return 0 if data_limite.past?
    ((data_limite - Time.current) / 1.day).ceil
  end

  def em_atraso?
    data_limite < Time.current && pendente?
  end

  def tempo_total_analise
    return 0 unless data_decisao && data_criacao
    ((data_decisao - data_criacao) / 1.hour).round(2)
  end

  def progresso_percentual
    case status.to_sym
    when :rascunho then 0
    when :triagem then 20
    when :distribuido then 40
    when :em_analise then 60
    when :em_votacao then 80
    when :decidido, :rejeitado then 100
    else 0
    end
  end

  def codigo_acompanhamento_formatado
    return codigo_acompanhamento if codigo_acompanhamento.blank?
    "#{codigo_acompanhamento[0..3]}-#{codigo_acompanhamento[4..7]}-#{codigo_acompanhamento[8..11]}"
  end

  def documentos_obrigatorios_completos?
    tipos_obrigatorios = %w[cnh]
    tipos_obrigatorios << 'crlv' if %w[velocidade rodizio].include?(tipo_infracao)

    tipos_obrigatorios.all? do |tipo|
      documentos.where(tipo: tipo, status_validacao: 'aprovado').exists?
    end
  end

  private

  def requires_relator?
    [:distribuido, :em_analise, :em_votacao, :decidido].include?(status.to_sym)
  end

  def generate_codigo_acompanhamento
    return if codigo_acompanhamento.present?

    loop do
      self.codigo_acompanhamento = SecureRandom.alphanumeric(12).upcase
      break unless self.class.exists?(codigo_acompanhamento: codigo_acompanhamento)
    end
  end

  def set_data_criacao
    self.data_criacao ||= Time.current
  end

  def set_data_limite
    self.data_limite ||= (data_criacao || Time.current) + 29.days
  end

  def data_limite_valida
    return unless data_criacao && data_limite

    if data_limite <= data_criacao
      errors.add(:data_limite, 'deve ser posterior à data de criação')
    end

    if data_limite > data_criacao + 30.days
      errors.add(:data_limite, 'não pode ser superior a 30 dias da criação')
    end
  end

  def transicao_status_valida
    return unless status_changed?

    status_anterior = status_was&.to_sym
    status_atual = status.to_sym

    return if status_anterior.nil? # Criação inicial

    unless pode_transicionar_para?(status_atual)
      errors.add(:status, "transição inválida de #{status_anterior} para #{status_atual}")
    end
  end

  def documentos_obrigatorios_presentes
    unless documentos_obrigatorios_completos?
      errors.add(:documentos, 'documentos obrigatórios não foram aprovados')
    end
  end

  def atualizar_contador_relator
    # Decrementar do relator anterior
    if relator_id_before_last_save
      relator_anterior = Relator.find(relator_id_before_last_save)
      relator_anterior.finalizar_processo!
    end

    # Incrementar no novo relator
    relator&.atribuir_processo!
  end

  def finalizar_votacao_se_quorum_atingido
    resultado = calcular_resultado_votacao
    finalizar_processo! if resultado[:quorum_atingido]
  end

  def encontrar_relator_disponivel
    Relator.joins("LEFT JOIN processos ON relators.id = processos.relator_id")
          .select('relators.*, COUNT(processos.id) as carga_atual')
          .where(disponivel: true)
          .where('relators.processos_ativos < relators.capacidade_maxima')
          .where('relators.especializacoes @> ? OR relators.especializacoes @> ?',
                 [tipo_infracao].to_json, ['geral'].to_json)
          .group('relators.id')
          .order('carga_atual ASC, relators.created_at ASC')
          .first
  end

  def criar_notificacao!(tipo)
    Notificacao.create!(
      processo: self,
      destinatario_email: cidadao.email,
      tipo: tipo,
      assunto: gerar_assunto_notificacao(tipo),
      conteudo: gerar_conteudo_notificacao(tipo),
      status_envio: 'pendente',
      data_criacao: Time.current,
      tentativas: 0
    )
  end

  def gerar_assunto_notificacao(tipo)
    case tipo.to_sym
    when :triagem then "Processo #{codigo_acompanhamento_formatado} - Em análise inicial"
    when :distribuicao then "Processo #{codigo_acompanhamento_formatado} - Distribuído para análise"
    when :analise then "Processo #{codigo_acompanhamento_formatado} - Em análise jurídica"
    when :votacao then "Processo #{codigo_acompanhamento_formatado} - Em votação"
    when :decisao then "Processo #{codigo_acompanhamento_formatado} - Decisão final"
    else "Processo #{codigo_acompanhamento_formatado} - Atualização"
    end
  end

  def gerar_conteudo_notificacao(tipo)
    case tipo.to_sym
    when :triagem
      "Seu processo de defesa de trânsito foi recebido e está sendo analisado pela equipe técnica."
    when :distribuicao
      "Seu processo foi distribuído para um relator especializado e está sendo analisado."
    when :analise
      "O relator iniciou a análise jurídica do seu processo."
    when :votacao
      "Seu processo está em votação pelo colegiado de julgadores."
    when :decisao
      if decidido?
        resultado = decisao_final_deferido? ? 'DEFERIDO' : 'INDEFERIDO'
        "Seu processo foi finalizado com resultado: #{resultado}."
      else
        "Seu processo foi rejeitado. Motivo: #{justificativa_rejeicao}"
      end
    else
      "Houve uma atualização no status do seu processo."
    end
  end
end
