class Relator < ApplicationRecord
  # Relacionamentos
  has_many :processos, dependent: :nullify

  # Enums para especializações
  ESPECIALIZACOES = %w[velocidade rodizio semaforo geral].freeze

  # Serializers para arrays e JSON
  serialize :especializacoes, type: Array, coder: JSON
  serialize :metricas_performance, type: Hash, coder: JSON

  # Validações
  validates :nome, presence: true, length: { maximum: 255 }
  validates :registro_oab, presence: true, uniqueness: true, length: { maximum: 20 }
  validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :capacidade_maxima, presence: true, numericality: { greater_than: 0 }
  validates :processos_ativos, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :disponivel, inclusion: { in: [true, false] }

  # Validação customizada para especializações
  validate :especializacoes_validas
  validate :processos_dentro_da_capacidade

  # Callbacks
  before_create :set_defaults
  before_create :set_data_cadastro

  # Scopes
  scope :disponivel, -> { where(disponivel: true) }
  scope :com_capacidade, -> { where('processos_ativos < capacidade_maxima') }
  scope :por_especializacao, ->(tipo) { where("especializacoes @> ?", [tipo].to_json) }

  # Métodos de instância
  def disponivel_para_processo?
    disponivel? && processos_ativos < capacidade_maxima
  end

  def pode_receber_processo?(tipo_infracao = nil)
    return false unless disponivel_para_processo?
    return true if tipo_infracao.nil? || especializacoes.include?('geral')

    especializacoes.include?(tipo_infracao.to_s)
  end

  def atribuir_processo!
    increment!(:processos_ativos)
    update!(disponivel: false) if processos_ativos >= capacidade_maxima
  end

  def finalizar_processo!
    decrement!(:processos_ativos)
    update!(disponivel: true) if processos_ativos < capacidade_maxima
  end

  def carga_trabalho_percentual
    return 0 if capacidade_maxima.zero?
    (processos_ativos.to_f / capacidade_maxima * 100).round(2)
  end

  def atualizar_metricas(tempo_analise, decisao_tipo)
    metricas = metricas_performance || {}

    # Atualizar tempo médio
    if metricas['tempo_medio_analise']
      total_processos = metricas['total_processos'] || 1
      tempo_total = metricas['tempo_medio_analise'] * total_processos + tempo_analise
      metricas['tempo_medio_analise'] = (tempo_total / (total_processos + 1)).round(2)
      metricas['total_processos'] = total_processos + 1
    else
      metricas['tempo_medio_analise'] = tempo_analise.to_f
      metricas['total_processos'] = 1
    end

    # Atualizar taxa de deferimento
    decisoes_favoraveis = metricas['decisoes_favoraveis'] || 0
    if decisao_tipo == 'deferido'
      metricas['decisoes_favoraveis'] = decisoes_favoraveis + 1
    end

    total = metricas['total_processos']
    metricas['taxa_deferimento'] = ((metricas['decisoes_favoraveis'].to_f / total) * 100).round(2)

    update!(metricas_performance: metricas)
  end

  def registro_oab_formatado
    return registro_oab if registro_oab.blank?
    # Formato básico: SP-123456 ou similares
    registro_oab
  end

  private

  def set_defaults
    self.capacidade_maxima ||= 10
    self.processos_ativos ||= 0
    self.disponivel = true if disponivel.nil?
    self.especializacoes ||= ['geral']
    self.metricas_performance ||= {}
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

  def processos_dentro_da_capacidade
    return unless processos_ativos && capacidade_maxima

    if processos_ativos > capacidade_maxima
      errors.add(:processos_ativos, 'não pode ser maior que a capacidade máxima')
    end
  end
end
