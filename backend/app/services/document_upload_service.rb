# frozen_string_literal: true

# Serviço responsável pelo upload de documentos para R2 Cloudflare
# Inclui validação, processamento, armazenamento seguro e otimização
class DocumentUploadService
  include ActiveModel::Model
  include ActiveModel::Attributes

  attr_accessor :processo, :arquivo, :tipo_documento, :nome_customizado

  # Configurações do R2 Cloudflare
  R2_BUCKET = ENV.fetch('R2_BUCKET_NAME', 'tramiteja-documents').freeze
  R2_ENDPOINT = ENV.fetch('R2_ENDPOINT', 'https://your-account-id.r2.cloudflarestorage.com').freeze
  R2_ACCESS_KEY = ENV.fetch('R2_ACCESS_KEY', nil).freeze
  R2_SECRET_KEY = ENV.fetch('R2_SECRET_KEY', nil).freeze
  R2_PUBLIC_URL = ENV.fetch('R2_PUBLIC_URL', 'https://documents.tramiteja.gov.br').freeze

  # Limites e validações
  MAX_FILE_SIZE = 10.megabytes
  MIN_FILE_SIZE = 1.kilobyte
  ALLOWED_MIME_TYPES = %w[
    application/pdf
    image/jpeg
    image/jpg
    image/png
  ].freeze
  ALLOWED_EXTENSIONS = %w[.pdf .jpg .jpeg .png].freeze

  # Configurações de segurança
  VIRUS_SCAN_ENABLED = ENV.fetch('VIRUS_SCAN_ENABLED', 'false') == 'true'
  CONTENT_VALIDATION_ENABLED = ENV.fetch('CONTENT_VALIDATION_ENABLED', 'true') == 'true'

  # Resultado padronizado do serviço
  Result = Struct.new(:success?, :data, :errors, :warnings, keyword_init: true) do
    def success?
      success?
    end

    def failure?
      !success?
    end
  end

  def initialize(processo:, arquivo:, tipo_documento:, nome_customizado: nil)
    @processo = processo
    @arquivo = arquivo
    @tipo_documento = tipo_documento
    @nome_customizado = nome_customizado
    @errors = []
    @warnings = []
  end

  # Upload principal do documento
  def upload
    return falha('Processo é obrigatório') unless processo.present?
    return falha('Arquivo é obrigatório') unless arquivo.present?
    return falha('Tipo de documento é obrigatório') unless tipo_documento.present?

    # Validações de segurança e formato
    validacao_result = validar_arquivo

    return validacao_result unless validacao_result.success?

    # Processar upload
    resultado_upload = processar_upload_seguro

    if resultado_upload[:sucesso]
      # Criar registro no banco
      documento = criar_documento_no_banco(resultado_upload)

      if documento.persisted?
        Rails.logger.info "[DocumentUploadService] Documento #{tipo_documento} uploaded para processo #{processo.codigo_acompanhamento}"

        sucesso({
          documento: documento,
          url_arquivo: resultado_upload[:url_publica],
          tamanho_bytes: resultado_upload[:tamanho],
          checksum: resultado_upload[:checksum]
        })
      else
        # Falha ao salvar - limpar arquivo do R2
        limpar_arquivo_r2(resultado_upload[:chave_r2])
        falha(documento.errors.full_messages.join(', '))
      end
    else
      falha(resultado_upload[:erro])
    end

  rescue StandardError => e
    Rails.logger.error "[DocumentUploadService] Erro no upload: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    falha("Erro interno no upload: #{e.message}")
  end

  # Upload de múltiplos documentos
  def self.upload_multiplos(dados_uploads)
    resultados = []
    uploads_sucesso = 0
    uploads_falha = 0

    dados_uploads.each do |dados|
      resultado = new(
        processo: dados[:processo],
        arquivo: dados[:arquivo],
        tipo_documento: dados[:tipo_documento],
        nome_customizado: dados[:nome_customizado]
      ).upload

      resultados << { dados: dados, resultado: resultado }

      if resultado.success?
        uploads_sucesso += 1
      else
        uploads_falha += 1
      end
    end

    Rails.logger.info "[DocumentUploadService] Lote processado: #{uploads_sucesso} sucessos, #{uploads_falha} falhas"

    {
      total: dados_uploads.count,
      sucessos: uploads_sucesso,
      falhas: uploads_falha,
      resultados: resultados
    }
  end

  # Gerar URL assinada para download seguro
  def self.gerar_url_download(documento, tempo_expiracao = 1.hour)
    return nil unless documento&.url_armazenamento

    chave_arquivo = extrair_chave_do_url(documento.url_armazenamento)

    begin
      s3_client = configurar_cliente_s3
      presigned_url = s3_client.presigned_url(
        :get_object,
        bucket: R2_BUCKET,
        key: chave_arquivo,
        expires_in: tempo_expiracao.to_i
      )

      Rails.logger.info "[DocumentUploadService] URL de download gerada para documento #{documento.id}"
      presigned_url
    rescue StandardError => e
      Rails.logger.error "[DocumentUploadService] Erro ao gerar URL de download: #{e.message}"
      nil
    end
  end

  # Deletar documento do R2
  def self.deletar_documento(documento)
    return false unless documento&.url_armazenamento

    chave_arquivo = extrair_chave_do_url(documento.url_armazenamento)

    begin
      s3_client = configurar_cliente_s3
      s3_client.delete_object(bucket: R2_BUCKET, key: chave_arquivo)

      Rails.logger.info "[DocumentUploadService] Documento #{documento.id} deletado do R2"
      true
    rescue StandardError => e
      Rails.logger.error "[DocumentUploadService] Erro ao deletar documento: #{e.message}"
      false
    end
  end

  # Verificar integridade dos documentos
  def self.verificar_integridade(documentos)
    resultados = {}

    documentos.each do |documento|
      chave_arquivo = extrair_chave_do_url(documento.url_armazenamento)

      begin
        s3_client = configurar_cliente_s3
        objeto = s3_client.head_object(bucket: R2_BUCKET, key: chave_arquivo)

        resultados[documento.id] = {
          existe: true,
          tamanho_r2: objeto.content_length,
          tamanho_banco: documento.tamanho_bytes,
          integridade_ok: objeto.content_length == documento.tamanho_bytes,
          ultima_modificacao: objeto.last_modified
        }
      rescue Aws::S3::Errors::NotFound
        resultados[documento.id] = {
          existe: false,
          integridade_ok: false,
          erro: 'Arquivo não encontrado no R2'
        }
      rescue StandardError => e
        resultados[documento.id] = {
          existe: nil,
          integridade_ok: false,
          erro: e.message
        }
      end
    end

    resultados
  end

  # Estatísticas de armazenamento
  def self.estatisticas_armazenamento
    documentos = Documento.all

    total_arquivos = documentos.count
    tamanho_total = documentos.sum(:tamanho_bytes)
    documentos_por_tipo = documentos.group(:tipo).count
    documentos_por_status = documentos.group(:status_validacao).count

    {
      total_arquivos: total_arquivos,
      tamanho_total: formatar_tamanho_bytes(tamanho_total),
      tamanho_total_bytes: tamanho_total,
      arquivos_por_tipo: documentos_por_tipo,
      arquivos_por_status: documentos_por_status,
      tamanho_medio: total_arquivos > 0 ? formatar_tamanho_bytes(tamanho_total / total_arquivos) : '0 B',
      maior_arquivo: documentos.maximum(:tamanho_bytes),
      menor_arquivo: documentos.minimum(:tamanho_bytes)
    }
  end

  private

  # Validar arquivo antes do upload
  def validar_arquivo
    validacoes = []

    # Validar tamanho
    unless arquivo_tamanho_valido?
      validacoes << "Tamanho do arquivo deve estar entre #{formatar_tamanho(MIN_FILE_SIZE)} e #{formatar_tamanho(MAX_FILE_SIZE)}"
    end

    # Validar tipo MIME
    unless tipo_mime_valido?
      validacoes << "Tipo de arquivo não permitido. Use: #{ALLOWED_MIME_TYPES.join(', ')}"
    end

    # Validar extensão
    unless extensao_valida?
      validacoes << "Extensão não permitida. Use: #{ALLOWED_EXTENSIONS.join(', ')}"
    end

    # Validar consistência MIME/extensão
    unless mime_extensao_consistentes?
      validacoes << 'Tipo de arquivo não corresponde à extensão'
    end

    # Validar limite por tipo de documento
    unless limite_documentos_respeitado?
      validacoes << "Limite de documentos do tipo #{tipo_documento} excedido"
    end

    # Verificação de vírus (se habilitado)
    if VIRUS_SCAN_ENABLED && arquivo_infectado?
      validacoes << 'Arquivo contém vírus ou conteúdo malicioso'
    end

    # Validação de conteúdo (se habilitado)
    if CONTENT_VALIDATION_ENABLED && !conteudo_valido?
      @warnings << 'Conteúdo do arquivo pode não estar relacionado ao tipo de documento'
    end

    if validacoes.any?
      falha(validacoes.join(', '))
    else
      sucesso(nil, @warnings)
    end
  end

  # Processar upload de forma segura
  def processar_upload_seguro
    chave_arquivo = gerar_chave_arquivo_unica
    nome_arquivo_sanitizado = sanitizar_nome_arquivo

    begin
      # Configurar cliente S3/R2
      s3_client = self.class.configurar_cliente_s3

      # Calcular checksum
      checksum = calcular_checksum_arquivo

      # Upload para R2
      response = s3_client.put_object(
        bucket: R2_BUCKET,
        key: chave_arquivo,
        body: arquivo.read,
        content_type: arquivo.content_type,
        content_length: arquivo.size,
        metadata: {
          'processo-id' => processo.id.to_s,
          'tipo-documento' => tipo_documento,
          'nome-original' => nome_arquivo_sanitizado,
          'checksum-md5' => checksum,
          'upload-timestamp' => Time.current.iso8601
        },
        server_side_encryption: 'AES256'
      )

      # Construir URL pública
      url_publica = "#{R2_PUBLIC_URL}/#{chave_arquivo}"

      Rails.logger.info "[DocumentUploadService] Arquivo uploaded para R2: #{chave_arquivo}"

      {
        sucesso: true,
        chave_r2: chave_arquivo,
        url_publica: url_publica,
        tamanho: arquivo.size,
        checksum: checksum,
        etag: response.etag
      }

    rescue StandardError => e
      Rails.logger.error "[DocumentUploadService] Erro no upload para R2: #{e.message}"
      {
        sucesso: false,
        erro: "Falha no upload: #{e.message}"
      }
    ensure
      # Resetar posição do arquivo
      arquivo.rewind if arquivo.respond_to?(:rewind)
    end
  end

  # Criar registro do documento no banco
  def criar_documento_no_banco(resultado_upload)
    Documento.create!(
      processo: processo,
      tipo: tipo_documento,
      nome_arquivo: nome_customizado || arquivo.original_filename,
      url_armazenamento: resultado_upload[:url_publica],
      tamanho_bytes: resultado_upload[:tamanho],
      tipo_mime: arquivo.content_type,
      status_validacao: 'pendente'
    )
  end

  # Validações de arquivo
  def arquivo_tamanho_valido?
    arquivo.size >= MIN_FILE_SIZE && arquivo.size <= MAX_FILE_SIZE
  end

  def tipo_mime_valido?
    ALLOWED_MIME_TYPES.include?(arquivo.content_type)
  end

  def extensao_valida?
    extensao = File.extname(arquivo.original_filename).downcase
    ALLOWED_EXTENSIONS.include?(extensao)
  end

  def mime_extensao_consistentes?
    extensao = File.extname(arquivo.original_filename).downcase
    mime = arquivo.content_type

    case mime
    when 'application/pdf'
      extensao == '.pdf'
    when 'image/jpeg', 'image/jpg'
      %w[.jpg .jpeg].include?(extensao)
    when 'image/png'
      extensao == '.png'
    else
      false
    end
  end

  def limite_documentos_respeitado?
    # Verificar se já existe documento do mesmo tipo obrigatório
    if %w[cnh crlv].include?(tipo_documento)
      !processo.documentos.where(tipo: tipo_documento).exists?
    else
      true # Documentos de apoio não têm limite
    end
  end

  def arquivo_infectado?
    # Implementar verificação de vírus se necessário
    # Por enquanto, simulação baseada no nome do arquivo
    nome_arquivo = arquivo.original_filename.downcase
    palavras_suspeitas = %w[virus malware trojan]

    palavras_suspeitas.any? { |palavra| nome_arquivo.include?(palavra) }
  end

  def conteudo_valido?
    # Validação básica de conteúdo
    # Para PDF: verificar se é realmente um PDF
    # Para imagens: verificar headers básicos
    case arquivo.content_type
    when 'application/pdf'
      arquivo.read(4) == '%PDF'
    when 'image/jpeg', 'image/jpg'
      headers = arquivo.read(3)
      headers == "\xFF\xD8\xFF".force_encoding('ASCII-8BIT')
    when 'image/png'
      headers = arquivo.read(8)
      headers == "\x89PNG\r\n\x1A\n".force_encoding('ASCII-8BIT')
    else
      true
    end
  ensure
    arquivo.rewind if arquivo.respond_to?(:rewind)
  end

  # Utilitários
  def gerar_chave_arquivo_unica
    timestamp = Time.current.strftime('%Y/%m/%d')
    uuid = SecureRandom.uuid
    extensao = File.extname(arquivo.original_filename)

    "processos/#{processo.id}/#{timestamp}/#{uuid}#{extensao}"
  end

  def sanitizar_nome_arquivo
    nome = nome_customizado || arquivo.original_filename
    # Remover caracteres perigosos
    nome.gsub(/[^a-zA-Z0-9.\-_]/, '_')
  end

  def calcular_checksum_arquivo
    arquivo.rewind if arquivo.respond_to?(:rewind)
    checksum = Digest::MD5.hexdigest(arquivo.read)
    arquivo.rewind if arquivo.respond_to?(:rewind)
    checksum
  end

  def limpar_arquivo_r2(chave_arquivo)
    begin
      s3_client = self.class.configurar_cliente_s3
      s3_client.delete_object(bucket: R2_BUCKET, key: chave_arquivo)
    rescue StandardError => e
      Rails.logger.error "[DocumentUploadService] Erro ao limpar arquivo: #{e.message}"
    end
  end

  # Métodos de classe
  def self.configurar_cliente_s3
    require 'aws-sdk-s3'

    Aws::S3::Client.new(
      access_key_id: R2_ACCESS_KEY,
      secret_access_key: R2_SECRET_KEY,
      endpoint: R2_ENDPOINT,
      region: 'auto', # R2 usa 'auto'
      force_path_style: true
    )
  end

  def self.extrair_chave_do_url(url)
    # Extrair chave do arquivo da URL pública
    uri = URI.parse(url)
    uri.path[1..] # Remove a barra inicial
  end

  def self.formatar_tamanho_bytes(bytes)
    return '0 B' if bytes.zero?

    unidades = %w[B KB MB GB TB]
    exp = (Math.log(bytes) / Math.log(1024)).to_i
    exp = [exp, unidades.length - 1].min

    tamanho_formatado = (bytes.to_f / (1024**exp)).round(2)
    "#{tamanho_formatado} #{unidades[exp]}"
  end

  def formatar_tamanho(bytes)
    self.class.formatar_tamanho_bytes(bytes)
  end

  # Métodos auxiliares para resultados
  def sucesso(data, warnings = [])
    @warnings.concat(warnings) if warnings.any?
    Result.new(success?: true, data: data, errors: [], warnings: @warnings)
  end

  def falha(mensagem)
    @errors << mensagem
    Result.new(success?: false, data: nil, errors: @errors, warnings: @warnings)
  end
end