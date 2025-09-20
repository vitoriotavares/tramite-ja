class Api::V1::ProcessosController < ApplicationController
  before_action :set_processo, only: [:show, :update]
  before_action :validate_pagination_params, only: [:index]

  # POST /api/v1/processos
  def create
    @processo = Processo.new(processo_params)

    if @processo.save
      # Enviar para triagem automaticamente
      @processo.transicionar_para!(:triagem)

      render json: processo_json(@processo), status: :created
    else
      render_validation_errors(@processo.errors)
    end
  rescue StandardError => e
    Rails.logger.error "[ProcessosController#create] Erro: #{e.message}"
    render_internal_error(e.message)
  end

  # GET /api/v1/processos
  def index
    @processos = Processo.includes(:cidadao, :relator, :votos, :documentos)
                        .order(created_at: :desc)

    # Aplicar filtros
    @processos = @processos.por_status(params[:status]) if params[:status].present?
    @processos = @processos.por_tipo_infracao(params[:tipo_infracao]) if params[:tipo_infracao].present?
    @processos = @processos.por_cidadao(params[:cidadao_id]) if params[:cidadao_id].present?
    @processos = @processos.por_relator(params[:relator_id]) if params[:relator_id].present?

    # Paginação
    total = @processos.count
    @processos = @processos.limit(pagination_limit).offset(pagination_offset)

    render json: {
      data: @processos.map { |p| processo_json(p) },
      total: total,
      limit: pagination_limit,
      offset: pagination_offset
    }
  rescue StandardError => e
    Rails.logger.error "[ProcessosController#index] Erro: #{e.message}"
    render_internal_error(e.message)
  end

  # GET /api/v1/processos/:id
  def show
    render json: processo_json(@processo, include_details: true)
  rescue StandardError => e
    Rails.logger.error "[ProcessosController#show] Erro: #{e.message}"
    render_internal_error(e.message)
  end

  # PATCH /api/v1/processos/:id
  def update
    if @processo.update(processo_update_params)
      # Verificar transições de status se necessário
      handle_status_transition if params[:status].present?

      render json: processo_json(@processo, include_details: true)
    else
      render_validation_errors(@processo.errors)
    end
  rescue StandardError => e
    Rails.logger.error "[ProcessosController#update] Erro: #{e.message}"
    render_internal_error(e.message)
  end

  private

  def set_processo
    @processo = Processo.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render_not_found
  end

  def processo_params
    params.require(:processo).permit(:tipo_infracao, :cidadao_id)
  rescue ActionController::ParameterMissing => e
    render_bad_request("Parâmetros obrigatórios ausentes: #{e.param}")
  end

  def processo_update_params
    params.permit(:status, :parecer_relator, :justificativa_rejeicao, :decisao_final)
  end

  def validate_pagination_params
    if params[:limit].present? && (params[:limit].to_i < 1 || params[:limit].to_i > 100)
      render_bad_request("Limit deve estar entre 1 e 100")
      return
    end

    if params[:offset].present? && params[:offset].to_i < 0
      render_bad_request("Offset deve ser maior ou igual a 0")
      return
    end
  end

  def pagination_limit
    (params[:limit] || 20).to_i
  end

  def pagination_offset
    (params[:offset] || 0).to_i
  end

  def handle_status_transition
    return unless params[:status] != @processo.status

    if @processo.pode_transicionar_para?(params[:status])
      @processo.transicionar_para!(params[:status])
    else
      @processo.errors.add(:status, "Transição inválida de #{@processo.status} para #{params[:status]}")
      render_validation_errors(@processo.errors)
    end
  end

  def processo_json(processo, include_details: false)
    result = {
      id: processo.id,
      codigo_acompanhamento: processo.codigo_acompanhamento,
      tipo_infracao: processo.tipo_infracao,
      status: processo.status,
      cidadao_id: processo.cidadao_id,
      data_criacao: processo.data_criacao&.iso8601,
      data_limite: processo.data_limite&.iso8601
    }

    if include_details
      result.merge!(
        parecer_relator: processo.parecer_relator,
        data_decisao: processo.data_decisao&.iso8601,
        decisao_final: processo.decisao_final,
        justificativa_rejeicao: processo.justificativa_rejeicao,
        relator_id: processo.relator_id,
        documentos: processo.documentos.map { |d| documento_json(d) },
        votos: processo.votos.map { |v| voto_json(v) }
      )
    end

    result
  end

  def documento_json(documento)
    {
      id: documento.id,
      tipo: documento.tipo,
      nome_arquivo: documento.nome_arquivo,
      status_validacao: documento.status_validacao,
      data_upload: documento.created_at&.iso8601
    }
  end

  def voto_json(voto)
    {
      id: voto.id,
      julgador_id: voto.julgador_id,
      decisao: voto.decisao,
      justificativa: voto.justificativa,
      data_voto: voto.created_at&.iso8601
    }
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

  def render_bad_request(message)
    render json: {
      error: "Bad Request",
      message: message
    }, status: :bad_request
  end

  def render_internal_error(message)
    render json: {
      error: "Internal Server Error",
      message: "Erro interno do servidor",
      details: Rails.env.development? ? message : "Entre em contato com o suporte"
    }, status: :internal_server_error
  end
end
