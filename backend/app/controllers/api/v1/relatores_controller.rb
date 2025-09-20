class Api::V1::RelatoresController < ApplicationController
  before_action :set_relator, only: [:show, :dashboard]
  before_action :validate_filters, only: [:index]

  # GET /api/v1/relatores
  def index
    @relatores = Relator.all

    # Aplicar filtros se presentes
    @relatores = @relatores.where(disponivel: true) if params[:disponivel] == 'true'

    if params[:especializacao].present?
      @relatores = @relatores.por_especializacao(params[:especializacao])
    end

    # Ordenar por carga de trabalho (menor primeiro) e depois por nome
    @relatores = @relatores.order(:processos_ativos, :nome)

    render json: @relatores.map { |r| relator_json(r) }
  rescue StandardError => e
    Rails.logger.error "[RelatoresController#index] Erro: #{e.message}"
    render_internal_error(e.message)
  end

  # GET /api/v1/relatores/:id
  def show
    render json: relator_json(@relator, include_details: true)
  rescue StandardError => e
    Rails.logger.error "[RelatoresController#show] Erro: #{e.message}"
    render_internal_error(e.message)
  end

  # GET /api/v1/relatores/:id/dashboard
  def dashboard
    # Buscar processos pendentes do relator ordenados por urgência
    @processos_pendentes = @relator.processos
                                  .where(status: [:distribuido, :em_analise])
                                  .includes(:cidadao, :documentos)
                                  .order(:data_limite)

    # Calcular estatísticas do relator
    estatisticas = calcular_estatisticas_relator(@relator)

    render json: {
      processos_pendentes: @processos_pendentes.map { |p| processo_dashboard_json(p) },
      estatisticas: estatisticas,
      relator: relator_json(@relator, include_details: true)
    }
  rescue StandardError => e
    Rails.logger.error "[RelatoresController#dashboard] Erro: #{e.message}"
    render_internal_error(e.message)
  end

  # POST /api/v1/relatores
  def create
    @relator = Relator.new(relator_params)

    if @relator.save
      render json: relator_json(@relator, include_details: true), status: :created
    else
      render_validation_errors(@relator.errors)
    end
  rescue StandardError => e
    Rails.logger.error "[RelatoresController#create] Erro: #{e.message}"
    render_internal_error(e.message)
  end

  # PATCH /api/v1/relatores/:id
  def update
    if @relator.update(relator_update_params)
      render json: relator_json(@relator, include_details: true)
    else
      render_validation_errors(@relator.errors)
    end
  rescue StandardError => e
    Rails.logger.error "[RelatoresController#update] Erro: #{e.message}"
    render_internal_error(e.message)
  end

  # GET /api/v1/relatores/disponibilidade
  def disponibilidade
    # Endpoint para verificar disponibilidade geral de relatores
    disponibilidade_data = {
      total_relatores: Relator.count,
      relatores_disponiveis: Relator.disponivel.count,
      relatores_com_capacidade: Relator.com_capacidade.count,
      carga_total_sistema: calcular_carga_total_sistema,
      distribuicao_especializacoes: calcular_distribuicao_especializacoes,
      relatores_sobrecarregados: Relator.where('processos_ativos > capacidade_maxima').count
    }

    render json: disponibilidade_data
  rescue StandardError => e
    Rails.logger.error "[RelatoresController#disponibilidade] Erro: #{e.message}"
    render_internal_error(e.message)
  end

  # POST /api/v1/relatores/:id/redistribuir
  def redistribuir
    processo_id = params[:processo_id]
    novo_relator_id = params[:novo_relator_id]

    return render_bad_request("Processo ID é obrigatório") unless processo_id.present?
    return render_bad_request("Novo relator ID é obrigatório") unless novo_relator_id.present?

    processo = Processo.find(processo_id)
    novo_relator = Relator.find(novo_relator_id)

    # Usar serviço de distribuição para redistribuir
    resultado = ProcessoDistributionService.new(processo: processo).redistribuir_para_relator(novo_relator)

    if resultado.success?
      render json: {
        message: "Processo redistribuído com sucesso",
        processo: processo_dashboard_json(processo.reload),
        novo_relator: relator_json(novo_relator.reload)
      }
    else
      render json: {
        error: "Redistribution Error",
        message: "Falha na redistribuição",
        details: resultado.errors
      }, status: :unprocessable_entity
    end
  rescue ActiveRecord::RecordNotFound => e
    render_not_found
  rescue StandardError => e
    Rails.logger.error "[RelatoresController#redistribuir] Erro: #{e.message}"
    render_internal_error(e.message)
  end

  private

  def set_relator
    @relator = Relator.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render_not_found
  end

  def validate_filters
    if params[:especializacao].present?
      unless Relator::ESPECIALIZACOES.include?(params[:especializacao])
        return render_bad_request("Especialização inválida. Opções válidas: #{Relator::ESPECIALIZACOES.join(', ')}")
      end
    end

    if params[:disponivel].present?
      unless %w[true false].include?(params[:disponivel])
        return render_bad_request("Parâmetro 'disponivel' deve ser 'true' ou 'false'")
      end
    end
  end

  def relator_params
    params.require(:relator).permit(:nome, :registro_oab, :email, :capacidade_maxima, especializacoes: [])
  end

  def relator_update_params
    params.permit(:nome, :email, :capacidade_maxima, :disponivel, especializacoes: [])
  end

  def calcular_estatisticas_relator(relator)
    processos_finalizados = relator.processos.where(status: [:decidido, :rejeitado])
    processos_pendentes = relator.processos.where(status: [:distribuido, :em_analise, :em_votacao])

    # Calcular tempo médio de análise
    tempo_medio = 0
    if processos_finalizados.any?
      tempos = processos_finalizados.map(&:tempo_total_analise).compact
      tempo_medio = tempos.any? ? (tempos.sum / tempos.size).round(2) : 0
    end

    # Calcular taxa de deferimento
    taxa_deferimento = 0
    processos_decididos = processos_finalizados.where(status: :decidido)
    if processos_decididos.any?
      deferidos = processos_decididos.where(decisao_final: :deferido).count
      taxa_deferimento = ((deferidos.to_f / processos_decididos.count) * 100).round(2)
    end

    # Processos em atraso
    processos_em_atraso = processos_pendentes.where('data_limite < ?', Time.current).count

    # Processos urgentes (próximos ao vencimento)
    processos_urgentes = processos_pendentes.where(
      data_limite: Time.current..2.days.from_now
    ).count

    {
      total_processos_atribuidos: relator.processos.count,
      processos_finalizados: processos_finalizados.count,
      processos_pendentes: processos_pendentes.count,
      processos_em_atraso: processos_em_atraso,
      processos_urgentes: processos_urgentes,
      tempo_medio_analise: tempo_medio,
      taxa_deferimento: taxa_deferimento,
      carga_trabalho_percentual: relator.carga_trabalho_percentual,
      disponivel_para_novos: relator.disponivel_para_processo?,
      metricas_performance: relator.metricas_performance || {},
      periodo_analise: {
        data_inicio: 30.days.ago.iso8601,
        data_fim: Time.current.iso8601
      }
    }
  end

  def calcular_carga_total_sistema
    total_capacidade = Relator.sum(:capacidade_maxima)
    total_processos_ativos = Relator.sum(:processos_ativos)

    return 0.0 if total_capacidade.zero?

    utilizacao = (total_processos_ativos.to_f / total_capacidade) * 100
    utilizacao.round(2)
  end

  def calcular_distribuicao_especializacoes
    # Contar relatores por especialização (cada relator pode ter múltiplas)
    especializacoes_count = {}

    Relator.all.each do |relator|
      relator.especializacoes.each do |esp|
        especializacoes_count[esp] = (especializacoes_count[esp] || 0) + 1
      end
    end

    especializacoes_count
  end

  def relator_json(relator, include_details: false)
    result = {
      id: relator.id,
      nome: relator.nome,
      registro_oab: relator.registro_oab_formatado,
      especializacoes: relator.especializacoes,
      processos_ativos: relator.processos_ativos,
      capacidade_maxima: relator.capacidade_maxima,
      disponivel: relator.disponivel,
      carga_trabalho_percentual: relator.carga_trabalho_percentual
    }

    if include_details
      result.merge!(
        email: relator.email,
        data_cadastro: relator.data_cadastro&.iso8601,
        disponivel_para_processo: relator.disponivel_para_processo?,
        metricas_performance: relator.metricas_performance || {},
        total_processos_historico: relator.processos.count,
        processos_finalizados: relator.processos.where(status: [:decidido, :rejeitado]).count
      )
    end

    result
  end

  def processo_dashboard_json(processo)
    {
      id: processo.id,
      codigo_acompanhamento: processo.codigo_acompanhamento,
      tipo_infracao: processo.tipo_infracao,
      status: processo.status,
      cidadao_id: processo.cidadao_id,
      relator_id: processo.relator_id,
      data_criacao: processo.data_criacao&.iso8601,
      data_limite: processo.data_limite&.iso8601,
      dias_para_vencimento: processo.dias_para_vencimento,
      em_atraso: processo.em_atraso?,
      progresso_percentual: processo.progresso_percentual,
      documentos_count: processo.documentos.count,
      documentos_aprovados: processo.documentos.where(status_validacao: :aprovado).count,
      urgente: processo.dias_para_vencimento <= 2
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
