class Api::V1::VotosController < ApplicationController
  before_action :set_processo
  before_action :validate_voto_params, only: [:create]

  # POST /api/v1/processos/:processo_id/votos
  def create
    votacao_service = VotacaoService.new(
      processo: @processo,
      julgador: find_julgador,
      decisao: params[:decisao],
      justificativa: params[:justificativa],
      tempo_analise: params[:tempo_analise]
    )

    resultado = votacao_service.registrar_voto

    if resultado.success?
      voto = resultado.data[:voto]
      resultado_votacao = resultado.data[:resultado_votacao]

      render json: {
        **voto_json(voto),
        resultado_votacao: formato_resultado_votacao(resultado_votacao),
        processo_finalizado: resultado.data[:processo_finalizado]
      }, status: :created
    else
      render json: {
        error: "Vote Error",
        message: "Falha ao registrar voto",
        details: resultado.errors
      }, status: determine_error_status(resultado.errors)
    end
  rescue StandardError => e
    Rails.logger.error "[VotosController#create] Erro: #{e.message}"
    render_internal_error(e.message)
  end

  # GET /api/v1/processos/:processo_id/votos
  def index
    @votos = @processo.votos
                     .includes(:julgador)
                     .order(:created_at)

    resultado_votacao = @processo.calcular_resultado_votacao

    render json: {
      votos: @votos.map { |v| voto_json(v) },
      quorum_atingido: resultado_votacao[:quorum_atingido],
      resultado: determine_resultado_status(resultado_votacao),
      estatisticas: {
        total_votos: resultado_votacao[:total_votos],
        votos_favoraveis: resultado_votacao[:votos_favoraveis],
        votos_contrarios: resultado_votacao[:votos_contrarios],
        quorum_necessario: VotacaoService::QUORUM_MINIMO
      }
    }
  rescue StandardError => e
    Rails.logger.error "[VotosController#index] Erro: #{e.message}"
    render_internal_error(e.message)
  end

  # GET /api/v1/processos/:processo_id/votos/:id
  def show
    @voto = @processo.votos.find(params[:id])
    render json: voto_json(@voto, include_details: true)
  rescue ActiveRecord::RecordNotFound
    render_not_found
  rescue StandardError => e
    Rails.logger.error "[VotosController#show] Erro: #{e.message}"
    render_internal_error(e.message)
  end

  # PATCH /api/v1/processos/:processo_id/votos/:id
  def update
    @voto = @processo.votos.find(params[:id])

    unless @voto.pode_ser_editado?
      return render json: {
        error: "Forbidden",
        message: "Voto não pode ser editado após finalização do processo"
      }, status: :forbidden
    end

    if @voto.update(voto_update_params)
      # Recalcular resultado da votação após edição
      resultado_votacao = @processo.calcular_resultado_votacao

      render json: {
        **voto_json(@voto, include_details: true),
        resultado_votacao: formato_resultado_votacao(resultado_votacao)
      }
    else
      render_validation_errors(@voto.errors)
    end
  rescue ActiveRecord::RecordNotFound
    render_not_found
  rescue StandardError => e
    Rails.logger.error "[VotosController#update] Erro: #{e.message}"
    render_internal_error(e.message)
  end

  # DELETE /api/v1/processos/:processo_id/votos/:id
  def destroy
    @voto = @processo.votos.find(params[:id])

    unless @voto.pode_ser_editado?
      return render json: {
        error: "Forbidden",
        message: "Voto não pode ser removido após finalização do processo"
      }, status: :forbidden
    end

    if @voto.destroy
      # Verificar se processo deve voltar para status anterior
      handle_voto_removal

      render json: { message: "Voto removido com sucesso" }, status: :ok
    else
      render json: {
        error: "Delete Error",
        message: "Falha ao remover voto"
      }, status: :unprocessable_entity
    end
  rescue ActiveRecord::RecordNotFound
    render_not_found
  rescue StandardError => e
    Rails.logger.error "[VotosController#destroy] Erro: #{e.message}"
    render_internal_error(e.message)
  end

  # GET /api/v1/processos/:processo_id/votos/status
  def status
    votacao_service = VotacaoService.new(processo: @processo)
    resultado = votacao_service.status_votacao

    if resultado.success?
      render json: resultado.data
    else
      render json: {
        error: "Status Error",
        message: "Erro ao obter status da votação",
        details: resultado.errors
      }, status: :unprocessable_entity
    end
  rescue StandardError => e
    Rails.logger.error "[VotosController#status] Erro: #{e.message}"
    render_internal_error(e.message)
  end

  private

  def set_processo
    @processo = Processo.find(params[:processo_id])
  rescue ActiveRecord::RecordNotFound
    render_not_found
  end

  def validate_voto_params
    errors = []

    errors << "Decisão é obrigatória" unless params[:decisao].present?
    errors << "Julgador ID é obrigatório" unless params[:julgador_id].present?

    if params[:decisao].present?
      decisoes_validas = %w[concordo discordo]
      errors << "Decisão deve ser 'concordo' ou 'discordo'" unless decisoes_validas.include?(params[:decisao])
    end

    # Validar que votos "discordo" tenham justificativa (implementação flexível)
    if params[:decisao] == 'discordo' && params[:justificativa].blank?
      @warnings ||= []
      @warnings << "Recomenda-se adicionar justificativa para votos contrários"
    end

    if errors.any?
      render json: {
        error: "Validation Error",
        message: "Parâmetros de voto inválidos",
        details: errors
      }, status: :bad_request
    end
  end

  def find_julgador
    julgador = Julgador.find(params[:julgador_id])
    julgador
  rescue ActiveRecord::RecordNotFound
    render json: {
      error: "Not Found",
      message: "Julgador não encontrado"
    }, status: :not_found
    nil
  end

  def voto_update_params
    params.permit(:decisao, :justificativa, :tempo_analise)
  end

  def handle_voto_removal
    # Se não há mais votos suficientes, o processo continua em votação
    resultado_atual = @processo.calcular_resultado_votacao

    unless resultado_atual[:quorum_atingido]
      # Se processo foi decidido mas agora não tem mais quórum,
      # pode precisar voltar para em_votacao (depende da regra de negócio)
      if @processo.decidido?
        Rails.logger.info "[VotosController] Processo #{@processo.codigo_acompanhamento} pode precisar reabrir votação após remoção de voto"
      end
    end
  end

  def determine_error_status(errors)
    # Determinar status HTTP baseado no tipo de erro
    error_text = errors.join(' ').downcase

    if error_text.include?('não está em votação') || error_text.include?('não em votação')
      :unprocessable_entity
    elsif error_text.include?('já votou')
      :conflict
    else
      :bad_request
    end
  end

  def determine_resultado_status(resultado_votacao)
    if resultado_votacao[:quorum_atingido]
      resultado_votacao[:votos_favoraveis] > resultado_votacao[:votos_contrarios] ? 'deferido' : 'indeferido'
    else
      'pendente'
    end
  end

  def formato_resultado_votacao(resultado)
    {
      total_votos: resultado[:total_votos],
      votos_favoraveis: resultado[:votos_favoraveis],
      votos_contrarios: resultado[:votos_contrarios],
      quorum_atingido: resultado[:quorum_atingido],
      quorum_necessario: resultado[:quorum_necessario],
      decisao_final: resultado[:decisao_final],
      unanimidade: resultado[:unanimidade]
    }
  end

  def voto_json(voto, include_details: false)
    result = {
      id: voto.id,
      processo_id: voto.processo_id,
      julgador_id: voto.julgador_id,
      decisao: voto.decisao,
      data_voto: voto.data_voto&.iso8601
    }

    # Incluir justificativa apenas se presente (não mostrar nil)
    result[:justificativa] = voto.justificativa if voto.justificativa.present?

    if include_details
      result.merge!(
        tempo_analise: voto.tempo_analise,
        tempo_analise_formatado: voto.tempo_analise_formatado,
        julgador_nome: voto.julgador&.nome,
        favoravel: voto.favoravel?,
        contrario: voto.contrario?,
        pode_ser_editado: voto.pode_ser_editado?,
        impacto_no_resultado: voto.impacto_no_resultado,
        estatisticas_comparativas: voto.estatisticas_comparativas,
        resumo_voto: voto.resumo_voto
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
