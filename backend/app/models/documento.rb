class Documento < ApplicationRecord
  # Relacionamentos
  belongs_to :processo

  # Enums
  enum tipo: {
    cnh: 0,
    crlv: 1,
    comprovante: 2,
    outros: 3
  }

  enum status_validacao: {
    pendente: 0,
    aprovado: 1,
    rejeitado: 2
  }

  # Constantes
  MAX_FILE_SIZE = 10.megabytes
  ALLOWED_MIME_TYPES = %w[
    application/pdf
    image/jpeg
    image/jpg
    image/png
  ].freeze

  ALLOWED_EXTENSIONS = %w[.pdf .jpg .jpeg .png].freeze

  # Validações
  validates :processo, presence: true
  validates :tipo, presence: true
  validates :nome_arquivo, presence: true, length: { maximum: 255 }
  validates :url_armazenamento, presence: true, length: { maximum: 500 }
  validates :tamanho_bytes, presence: true, numericality: { greater_than: 0, less_than_or_equal_to: MAX_FILE_SIZE }
  validates :tipo_mime, presence: true, inclusion: { in: ALLOWED_MIME_TYPES }
  validates :status_validacao, presence: true
  validates :data_upload, presence: true

  # Validações condicionais
  validates :motivo_rejeicao, presence: true, if: :rejeitado?

  # Validações customizadas
  validate :extensao_arquivo_valida
  validate :documento_obrigatorio_para_tipo_infracao
  validate :limite_documentos_por_tipo

  # Callbacks
  before_create :set_data_upload
  before_validation :extract_file_extension, on: :create
  after_update :notificar_mudanca_status, if: :saved_change_to_status_validacao?

  # Scopes
  scope :por_processo, ->(processo) { where(processo: processo) }
  scope :por_tipo, ->(tipo) { where(tipo: tipo) }
  scope :por_status, ->(status) { where(status_validacao: status) }
  scope :aprovados, -> { where(status_validacao: 'aprovado') }
  scope :rejeitados, -> { where(status_validacao: 'rejeitado') }
  scope :pendentes, -> { where(status_validacao: 'pendente') }
  scope :por_tamanho, ->(min, max) { where(tamanho_bytes: min..max) }

  # Métodos de instância
  def tamanho_formatado
    return 'N/A' unless tamanho_bytes

    if tamanho_bytes < 1.kilobyte
      "#{tamanho_bytes} bytes"
    elsif tamanho_bytes < 1.megabyte
      "#{(tamanho_bytes.to_f / 1.kilobyte).round(1)} KB"
    else
      "#{(tamanho_bytes.to_f / 1.megabyte).round(1)} MB"
    end
  end

  def extensao_arquivo
    return nil if nome_arquivo.blank?
    File.extname(nome_arquivo).downcase
  end

  def obrigatorio_para_processo?
    case tipo.to_sym
    when :cnh
      true # CNH é sempre obrigatória
    when :crlv
      # CRLV é obrigatório para infrações de veículo
      %w[velocidade rodizio].include?(processo.tipo_infracao)
    when :comprovante, :outros
      false # Documentos de apoio são opcionais
    else
      false
    end
  end

  def aprovar!(aprovador = nil)
    update!(
      status_validacao: 'aprovado',
      motivo_rejeicao: nil
    )
  end

  def rejeitar!(motivo, rejeitador = nil)
    raise ArgumentError, 'Motivo de rejeição é obrigatório' if motivo.blank?

    update!(
      status_validacao: 'rejeitado',
      motivo_rejeicao: motivo
    )
  end

  def pode_ser_aprovado?
    pendente? && arquivo_valido?
  end

  def pode_ser_rejeitado?
    pendente? || aprovado?
  end

  def arquivo_valido?
    return false unless tipo_mime.in?(ALLOWED_MIME_TYPES)
    return false unless extensao_arquivo.in?(ALLOWED_EXTENSIONS)
    return false unless tamanho_bytes && tamanho_bytes <= MAX_FILE_SIZE
    true
  end

  def gerar_url_visualizacao
    # Para integração futura com R2 Cloudflare
    # Por enquanto retorna a URL de armazenamento
    url_armazenamento
  end

  def gerar_url_download
    # Para integração futura com R2 Cloudflare
    # Incluir headers de download forçado
    "#{url_armazenamento}?download=true"
  end

  def resumo_validacao
    {
      status: status_validacao,
      obrigatorio: obrigatorio_para_processo?,
      tamanho: tamanho_formatado,
      tipo_arquivo: tipo_mime,
      data_upload: data_upload,
      motivo_rejeicao: motivo_rejeicao,
      pode_aprovar: pode_ser_aprovado?,
      pode_rejeitar: pode_ser_rejeitado?
    }
  end

  def tipo_documento_formatado
    case tipo.to_sym
    when :cnh then 'CNH - Carteira Nacional de Habilitação'
    when :crlv then 'CRLV - Certificado de Registro e Licenciamento de Veículo'
    when :comprovante then 'Comprovante/Documento de Apoio'
    when :outros then 'Outros Documentos'
    else tipo.humanize
    end
  end

  def dias_desde_upload
    return 0 unless data_upload
    ((Time.current - data_upload) / 1.day).ceil
  end

  def urgente_para_validacao?
    # Considerar urgente se:
    # 1. Documento obrigatório pendente há mais de 24h
    # 2. Processo próximo do prazo limite
    return false unless pendente?

    dias_pendente = dias_desde_upload
    processo_vencendo = processo.dias_para_vencimento <= 3

    (obrigatorio_para_processo? && dias_pendente > 1) || processo_vencendo
  end

  private

  def set_data_upload
    self.data_upload ||= Time.current
  end

  def extract_file_extension
    return unless nome_arquivo

    # Garantir que o arquivo tem extensão válida
    ext = extensao_arquivo
    unless ext.in?(ALLOWED_EXTENSIONS)
      errors.add(:nome_arquivo, "deve ter uma das extensões permitidas: #{ALLOWED_EXTENSIONS.join(', ')}")
    end
  end

  def extensao_arquivo_valida
    return unless nome_arquivo

    extensao = extensao_arquivo
    unless extensao.in?(ALLOWED_EXTENSIONS)
      errors.add(:nome_arquivo, "extensão '#{extensao}' não é permitida. Use: #{ALLOWED_EXTENSIONS.join(', ')}")
    end

    # Verificar consistência entre MIME type e extensão
    case tipo_mime
    when 'application/pdf'
      unless extensao == '.pdf'
        errors.add(:tipo_mime, 'não é consistente com a extensão do arquivo')
      end
    when 'image/jpeg', 'image/jpg'
      unless %w[.jpg .jpeg].include?(extensao)
        errors.add(:tipo_mime, 'não é consistente com a extensão do arquivo')
      end
    when 'image/png'
      unless extensao == '.png'
        errors.add(:tipo_mime, 'não é consistente com a extensão do arquivo')
      end
    end
  end

  def documento_obrigatorio_para_tipo_infracao
    return unless processo && tipo

    # Verificar se CNH está presente para todos os tipos
    if tipo == 'cnh'
      return # CNH é sempre obrigatória, validação OK
    end

    # Verificar se CRLV está presente para infrações de veículo
    if tipo == 'crlv' && !%w[velocidade rodizio].include?(processo.tipo_infracao)
      errors.add(:tipo, 'CRLV não é necessário para este tipo de infração')
    end
  end

  def limite_documentos_por_tipo
    return unless processo && tipo

    # Permitir apenas um documento de cada tipo obrigatório
    if %w[cnh crlv].include?(tipo)
      documentos_mesmo_tipo = processo.documentos.where(tipo: tipo).where.not(id: id)
      if documentos_mesmo_tipo.exists?
        errors.add(:tipo, "já existe um documento do tipo #{tipo_documento_formatado} para este processo")
      end
    end
  end

  def notificar_mudanca_status
    return unless processo

    case status_validacao.to_sym
    when :aprovado
      Rails.logger.info "Documento #{tipo} aprovado para processo #{processo.codigo_acompanhamento}"
      verificar_documentos_completos
    when :rejeitado
      Rails.logger.info "Documento #{tipo} rejeitado para processo #{processo.codigo_acompanhamento}: #{motivo_rejeicao}"
      # Poderia enviar notificação para o cidadão sobre a rejeição
    end
  end

  def verificar_documentos_completos
    # Verificar se todos os documentos obrigatórios foram aprovados
    if processo.documentos_obrigatorios_completos? && processo.rascunho?
      # Processo pode avançar para triagem
      Rails.logger.info "Documentos completos para processo #{processo.codigo_acompanhamento}, pronto para triagem"
    end
  end
end
