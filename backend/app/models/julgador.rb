class Julgador < ApplicationRecord
  # Relacionamentos
  has_many :votos, dependent: :destroy
  has_many :processos, through: :votos

  # Enums para especializações
  ESPECIALIZACOES = %w[velocidade rodizio semaforo geral].freeze

  # Serializers para arrays e JSON
  serialize :especializacoes, JSON
  serialize :historico_votos, JSON

  # Validações
  validates :nome, presence: true, length: { maximum: 255 }
  validates :registro_profissional, presence: true, uniqueness: true, length: { maximum: 20 }
  validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :disponivel, inclusion: { in: [true, false] }

  # Validação customizada para especializações
  validate :especializacoes_validas

  # Callbacks
  before_create :set_defaults
  before_create :set_data_cadastro

  # Scopes
  scope :disponivel, -> { where(disponivel: true) }
  scope :por_especializacao, ->(tipo) { where("especializacoes @> ?", [tipo].to_json) }

  # Métodos de instância
  def pode_votar_processo?(processo)
    return false unless disponivel?
    return true if especializacoes.include?('geral')

    especializacoes.include?(processo.tipo_infracao)
  end

  def ja_votou_processo?(processo)
    votos.exists?(processo: processo)
  end

  def total_votos
    historico_votos&.dig('total_votos') || votos.count
  end

  def votos_favoraveis
    historico_votos&.dig('votos_favoraveis') || votos.where(decisao: 'concordo').count
  end

  def taxa_concordancia
    total = total_votos
    return 0 if total.zero?

    ((votos_favoraveis.to_f / total) * 100).round(2)
  end

  def tempo_medio_analise
    historico_votos&.dig('tempo_medio_analise') || 0
  end

  def atualizar_historico_voto!(voto)
    historico = historico_votos || {}

    # Atualizar contadores
    historico['total_votos'] = (historico['total_votos'] || 0) + 1

    if voto.decisao == 'concordo'
      historico['votos_favoraveis'] = (historico['votos_favoraveis'] || 0) + 1
    end

    # Atualizar tempo médio
    if historico['tempo_medio_analise'] && voto.tempo_analise
      total_anterior = historico['total_votos'] - 1
      if total_anterior > 0
        tempo_total = historico['tempo_medio_analise'] * total_anterior + voto.tempo_analise
        historico['tempo_medio_analise'] = (tempo_total / historico['total_votos']).round(2)
      else
        historico['tempo_medio_analise'] = voto.tempo_analise.to_f
      end
    elsif voto.tempo_analise
      historico['tempo_medio_analise'] = voto.tempo_analise.to_f
    end

    # Atualizar especialização mais votada
    processos_por_tipo = votos.joins(:processo).group('processos.tipo_infracao').count
    if processos_por_tipo.any?
      tipo_mais_votado = processos_por_tipo.max_by { |_, count| count }[0]
      historico['especializacao_mais_ativa'] = tipo_mais_votado
    end

    # Atualizar últimas atividades
    historico['ultimo_voto'] = Time.current
    historico['votos_ultimo_mes'] = votos.where('created_at > ?', 1.month.ago).count

    update!(historico_votos: historico)
  end

  def estatisticas_resumo
    {
      total_votos: total_votos,
      taxa_concordancia: taxa_concordancia,
      tempo_medio_analise: tempo_medio_analise,
      especializacao_mais_ativa: historico_votos&.dig('especializacao_mais_ativa'),
      ativo_ultimo_mes: (historico_votos&.dig('votos_ultimo_mes') || 0) > 0
    }
  end

  def registro_formatado
    return registro_profissional if registro_profissional.blank?
    # Formato básico dependendo do tipo de registro
    registro_profissional
  end

  private

  def set_defaults
    self.disponivel = true if disponivel.nil?
    self.especializacoes ||= ['geral']
    self.historico_votos ||= {}
  end

  def set_data_cadastro
    self.data_cadastro ||= Time.current
  end

  def especializacoes_validas
    return if especializacoes.blank?

    unless especializacoes.is_a?(Array)
      errors.add(:especializacoes, 'deve ser uma lista')
      return
    end

    especializacoes_invalidas = especializacoes - ESPECIALIZACOES
    if especializacoes_invalidas.any?
      errors.add(:especializacoes, "contém especializações inválidas: #{especializacoes_invalidas.join(', ')}")
    end

    if especializacoes.empty?
      errors.add(:especializacoes, 'deve ter pelo menos uma especialização')
    end
  end
end
