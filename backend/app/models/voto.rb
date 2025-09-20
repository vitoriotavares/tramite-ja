class Voto < ApplicationRecord
  # Relacionamentos
  belongs_to :processo
  belongs_to :julgador

  # Enums
  enum decisao: {
    concordo: 0,
    discordo: 1
  }

  # Validações
  validates :processo, presence: true
  validates :julgador, presence: true
  validates :decisao, presence: true
  validates :data_voto, presence: true
  validates :tempo_analise, presence: true, numericality: { greater_than_or_equal_to: 0 }

  # Validações condicionais
  validates :justificativa, presence: true, if: :discordo?

  # Validações customizadas
  validate :julgador_pode_votar_processo
  validate :processo_em_votacao
  validate :voto_unico_por_julgador

  # Callbacks
  before_create :set_data_voto
  after_create :atualizar_historico_julgador
  after_create :verificar_quorum_processo

  # Scopes
  scope :por_processo, ->(processo) { where(processo: processo) }
  scope :por_julgador, ->(julgador) { where(julgador: julgador) }
  scope :favoraveis, -> { where(decisao: 'concordo') }
  scope :contrarios, -> { where(decisao: 'discordo') }
  scope :por_periodo, ->(inicio, fim) { where(data_voto: inicio..fim) }

  # Métodos de instância
  def favoravel?
    concordo?
  end

  def contrario?
    discordo?
  end

  def tempo_analise_formatado
    return 'N/A' unless tempo_analise

    if tempo_analise < 60
      "#{tempo_analise} min"
    else
      horas = tempo_analise / 60
      minutos = tempo_analise % 60
      "#{horas}h #{minutos}min"
    end
  end

  def resumo_voto
    {
      julgador_nome: julgador.nome,
      decisao: decisao,
      data_voto: data_voto,
      tempo_analise: tempo_analise_formatado,
      tem_justificativa: justificativa.present?
    }
  end

  def impacto_no_resultado
    resultado_votacao = processo.calcular_resultado_votacao
    total_votos = resultado_votacao[:total_votos]

    if total_votos < 3
      'aguardando_quorum'
    elsif resultado_votacao[:quorum_atingido]
      favoraveis = resultado_votacao[:votos_favoraveis]
      contrarios = resultado_votacao[:votos_contrarios]

      if favoraveis > contrarios
        favoravel? ? 'contribuiu_para_deferimento' : 'voto_vencido'
      else
        contrario? ? 'contribuiu_para_indeferimento' : 'voto_vencido'
      end
    else
      'sem_impacto'
    end
  end

  def pode_ser_editado?
    # Votos só podem ser editados se o processo ainda estiver em votação
    # e não tiver sido finalizado
    processo.em_votacao? && !processo.decidido?
  end

  def estatisticas_comparativas
    # Comparar com outros votos do mesmo julgador
    votos_julgador = julgador.votos.joins(:processo)
                            .where(processos: { tipo_infracao: processo.tipo_infracao })

    total_votos_tipo = votos_julgador.count
    votos_favoraveis_tipo = votos_julgador.where(decisao: 'concordo').count
    tempo_medio_tipo = votos_julgador.average(:tempo_analise) || 0

    {
      total_votos_mesmo_tipo: total_votos_tipo,
      taxa_concordancia_tipo: total_votos_tipo > 0 ?
        ((votos_favoraveis_tipo.to_f / total_votos_tipo) * 100).round(2) : 0,
      tempo_medio_tipo: tempo_medio_tipo.round(2),
      mais_rapido_que_media: tempo_analise < tempo_medio_tipo,
      decisao_consistente: decisao_consistente_com_historico?
    }
  end

  private

  def set_data_voto
    self.data_voto ||= Time.current
  end

  def julgador_pode_votar_processo
    return unless julgador && processo

    unless julgador.pode_votar_processo?(processo)
      errors.add(:julgador, 'não tem especialização para votar neste tipo de processo')
    end

    unless julgador.disponivel?
      errors.add(:julgador, 'não está disponível para votação')
    end
  end

  def processo_em_votacao
    return unless processo

    unless processo.em_votacao?
      errors.add(:processo, 'não está em fase de votação')
    end
  end

  def voto_unico_por_julgador
    return unless julgador && processo

    if Voto.exists?(julgador: julgador, processo: processo)
      errors.add(:julgador, 'já votou neste processo')
    end
  end

  def atualizar_historico_julgador
    julgador.atualizar_historico_voto!(self)
  end

  def verificar_quorum_processo
    # Verificar se o quórum foi atingido após este voto
    resultado = processo.calcular_resultado_votacao

    if resultado[:quorum_atingido] && processo.em_votacao?
      # O processo será finalizado automaticamente pelo callback do modelo Processo
      Rails.logger.info "Quórum atingido para processo #{processo.codigo_acompanhamento} com #{resultado[:total_votos]} votos"
    end
  end

  def decisao_consistente_com_historico?
    return true unless julgador

    # Verificar se a decisão é consistente com o histórico do julgador
    # para o mesmo tipo de infração
    votos_anteriores = julgador.votos.joins(:processo)
                              .where(processos: { tipo_infracao: processo.tipo_infracao })
                              .where.not(id: id)

    return true if votos_anteriores.count < 3 # Poucos dados para comparar

    taxa_concordancia_anterior = votos_anteriores.where(decisao: 'concordo').count.to_f / votos_anteriores.count

    # Considerar consistente se a decisão não destoa muito do padrão
    # (mais de 70% de concordância anterior e voto favorável, ou vice-versa)
    if taxa_concordancia_anterior > 0.7
      concordo?
    elsif taxa_concordancia_anterior < 0.3
      discordo?
    else
      true # Padrão indefinido, qualquer decisão é aceitável
    end
  end
end
