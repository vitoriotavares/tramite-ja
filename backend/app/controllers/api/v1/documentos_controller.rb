class Api::V1::DocumentosController < ApplicationController
  before_action :set_processo
  before_action :validate_upload_params, only: [:create]

  # POST /api/v1/processos/:processo_id/documentos
  def create
    upload_service = DocumentUploadService.new(
      processo: @processo,
      arquivo: params[:arquivo],
      tipo_documento: params[:tipo],
      nome_customizado: params[:nome_customizado]
    )

    resultado = upload_service.upload

    if resultado.success?
      documento = resultado.data[:documento]
      render json: documento_json(documento), status: :created
    else
      render json: {
        error: "Upload Error",
        message: "Falha no upload do documento",
        details: resultado.errors
      }, status: :bad_request
    end
  rescue StandardError => e
    Rails.logger.error "[DocumentosController#create] Erro: #{e.message}"
    render_internal_error(e.message)
  end

  # GET /api/v1/processos/:processo_id/documentos
  def index
    @documentos = @processo.documentos
                          .includes(:processo)
                          .order(created_at: :desc)

    render json: @documentos.map { |d| documento_json(d) }
  rescue StandardError => e
    Rails.logger.error "[DocumentosController#index] Erro: #{e.message}"
    render_internal_error(e.message)
  end

  # GET /api/v1/processos/:processo_id/documentos/:id
  def show
    @documento = @processo.documentos.find(params[:id])
    render json: documento_json(@documento, include_details: true)
  rescue ActiveRecord::RecordNotFound
    render_not_found
  rescue StandardError => e
    Rails.logger.error "[DocumentosController#show] Erro: #{e.message}"
    render_internal_error(e.message)
  end

  # PATCH /api/v1/processos/:processo_id/documentos/:id
  def update
    @documento = @processo.documentos.find(params[:id])

    if params[:status_validacao].present?
      handle_validation_status_change
    elsif @documento.update(documento_update_params)
      render json: documento_json(@documento, include_details: true)
    else
      render_validation_errors(@documento.errors)
    end
  rescue ActiveRecord::RecordNotFound
    render_not_found
  rescue StandardError => e
    Rails.logger.error "[DocumentosController#update] Erro: #{e.message}"
    render_internal_error(e.message)
  end

  # DELETE /api/v1/processos/:processo_id/documentos/:id
  def destroy
    @documento = @processo.documentos.find(params[:id])

    if @documento.pode_ser_removido?
      # Deletar do R2 e do banco
      if DocumentUploadService.deletar_documento(@documento)
        @documento.destroy!
        render json: { message: "Documento removido com sucesso" }, status: :ok
      else
        render json: {
          error: "Delete Error",
          message: "Falha ao remover arquivo do armazenamento"
        }, status: :unprocessable_entity
      end
    else
      render json: {
        error: "Forbidden",
        message: "Documento não pode ser removido no status atual"
      }, status: :forbidden
    end
  rescue ActiveRecord::RecordNotFound
    render_not_found
  rescue StandardError => e
    Rails.logger.error "[DocumentosController#destroy] Erro: #{e.message}"
    render_internal_error(e.message)
  end

  # GET /api/v1/processos/:processo_id/documentos/:id/download
  def download
    @documento = @processo.documentos.find(params[:id])

    if @documento.aprovado? || current_user_can_access_pending_documents?
      url_download = DocumentUploadService.gerar_url_download(@documento)

      if url_download
        render json: {
          url_download: url_download,
          expires_in: 3600,
          nome_arquivo: @documento.nome_arquivo,
          tamanho: @documento.tamanho_formatado
        }
      else
        render json: {
          error: "Download Error",
          message: "Não foi possível gerar URL de download"
        }, status: :unprocessable_entity
      end
    else
      render json: {
        error: "Forbidden",
        message: "Documento não disponível para download"
      }, status: :forbidden
    end
  rescue ActiveRecord::RecordNotFound
    render_not_found
  rescue StandardError => e
    Rails.logger.error "[DocumentosController#download] Erro: #{e.message}"
    render_internal_error(e.message)
  end

  private

  def set_processo
    @processo = Processo.find(params[:processo_id])
  rescue ActiveRecord::RecordNotFound
    render_not_found
  end

  def validate_upload_params
    errors = []

    errors << "Arquivo é obrigatório" unless params[:arquivo].present?
    errors << "Tipo de documento é obrigatório" unless params[:tipo].present?

    if params[:tipo].present?
      tipos_validos = %w[cnh crlv comprovante outros]
      errors << "Tipo de documento inválido" unless tipos_validos.include?(params[:tipo])
    end

    if params[:arquivo].present?
      arquivo = params[:arquivo]

      # Validar tamanho
      if arquivo.size > Documento::MAX_FILE_SIZE
        errors << "Arquivo muito grande. Limite máximo de #{Documento::MAX_FILE_SIZE / 1.megabyte}MB"
      end

      # Validar tipo MIME
      unless Documento::ALLOWED_MIME_TYPES.include?(arquivo.content_type)
        tipos_permitidos = Documento::ALLOWED_MIME_TYPES.join(', ')
        errors << "Tipo de arquivo não permitido. Use: #{tipos_permitidos}"
      end

      # Validar extensão
      extensao = File.extname(arquivo.original_filename).downcase
      unless Documento::ALLOWED_EXTENSIONS.include?(extensao)
        extensoes_permitidas = Documento::ALLOWED_EXTENSIONS.join(', ')
        errors << "Extensão não permitida. Use: #{extensoes_permitidas}"
      end
    end

    if errors.any?
      render json: {
        error: "Validation Error",
        message: "Parâmetros de upload inválidos",
        details: errors
      }, status: :bad_request
    end
  end

  def documento_update_params
    params.permit(:motivo_rejeicao)
  end

  def handle_validation_status_change
    status = params[:status_validacao]
    motivo = params[:motivo_rejeicao]

    case status
    when 'aprovado'
      if @documento.pode_ser_aprovado?
        @documento.aprovar!
        render json: documento_json(@documento, include_details: true)
      else
        render json: {
          error: "Validation Error",
          message: "Documento não pode ser aprovado no status atual"
        }, status: :bad_request
      end
    when 'rejeitado'
      if @documento.pode_ser_rejeitado?
        if motivo.present?
          @documento.rejeitar!(motivo)
          render json: documento_json(@documento, include_details: true)
        else
          render json: {
            error: "Validation Error",
            message: "Motivo de rejeição é obrigatório"
          }, status: :bad_request
        end
      else
        render json: {
          error: "Validation Error",
          message: "Documento não pode ser rejeitado no status atual"
        }, status: :bad_request
      end
    else
      render json: {
        error: "Validation Error",
        message: "Status de validação inválido"
      }, status: :bad_request
    end
  end

  def current_user_can_access_pending_documents?
    # Implementar lógica de autorização conforme necessário
    # Por exemplo: apenas relatores e administradores podem ver documentos pendentes
    true
  end

  def documento_json(documento, include_details: false)
    result = {
      id: documento.id,
      processo_id: documento.processo_id,
      tipo: documento.tipo,
      nome_arquivo: documento.nome_arquivo,
      url_armazenamento: documento.url_armazenamento,
      tamanho_bytes: documento.tamanho_bytes,
      status_validacao: documento.status_validacao,
      data_upload: documento.data_upload&.iso8601
    }

    if include_details
      result.merge!(
        tipo_mime: documento.tipo_mime,
        motivo_rejeicao: documento.motivo_rejeicao,
        tamanho_formatado: documento.tamanho_formatado,
        tipo_documento_formatado: documento.tipo_documento_formatado,
        obrigatorio: documento.obrigatorio_para_processo?,
        pode_ser_aprovado: documento.pode_ser_aprovado?,
        pode_ser_rejeitado: documento.pode_ser_rejeitado?,
        urgente_para_validacao: documento.urgente_para_validacao?,
        dias_desde_upload: documento.dias_desde_upload,
        resumo_validacao: documento.resumo_validacao
      )
    end

    result
  end

  # Error handling methods
  def render_validation_errors(errors)
    render json: {
      error: "Validation Error",
      message: "Dados inválidos fornecidos",
      details: errors.full_messages
    }, status: :bad_request
  end

  def render_not_found
    render json: {
      error: "Not Found",
      message: "Recurso não encontrado"
    }, status: :not_found
  end

  def render_internal_error(message)
    render json: {
      error: "Internal Server Error",
      message: "Erro interno do servidor",
      details: Rails.env.development? ? message : "Entre em contato com o suporte"
    }, status: :internal_server_error
  end
end
