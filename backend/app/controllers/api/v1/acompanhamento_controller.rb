class Api::V1::AcompanhamentoController < ApplicationController
  # Este endpoint é público (sem autenticação)
  skip_before_action :authenticate_user!, only: [:show] if respond_to?(:authenticate_user!)

  # GET /api/v1/acompanhamento/:codigo
  def show
    validate_codigo_format
    return if performed?

    @processo = find_processo_by_codigo
    return if performed?

    render json: {
      processo: processo_public_json(@processo),
      timeline: generate_timeline(@processo)
    }
  rescue StandardError => e
    Rails.logger.error "[AcompanhamentoController#show] Erro: #{e.message}"
    render_internal_error(e.message)
  end

  private

  def validate_codigo_format
    codigo = params[:codigo]

    # Código deve ter exatamente 12 caracteres alfanuméricos maiúsculos
    unless codigo.present? && codigo.match?(/\A[A-Z0-9]{12}\z/)
      render json: {
        error: "Bad Request",
        message: "Código de acompanhamento tem formato inválido. Deve conter exatamente 12 caracteres alfanuméricos."
      }, status: :bad_request
    end
  end

  def find_processo_by_codigo
    processo = Processo.find_by(codigo_acompanhamento: params[:codigo])

    unless processo
      render json: {
        error: "Not Found",
        message: "Recurso não encontrado"
      }, status: :not_found
      return nil
    end

    processo
  end

  def processo_public_json(processo)
    result = {
      id: processo.id,
      codigo_acompanhamento: processo.codigo_acompanhamento,
      tipo_infracao: processo.tipo_infracao,
      status: processo.status,
      data_criacao: processo.data_criacao&.iso8601,
      data_limite: processo.data_limite&.iso8601
    }

    # Adicionar campos específicos para status final
    if processo.decidido?
      result[:data_decisao] = processo.data_decisao&.iso8601
      result[:decisao_final] = processo.decisao_final
    elsif processo.rejeitado?
      result[:data_decisao] = processo.data_decisao&.iso8601
      result[:justificativa_rejeicao] = processo.justificativa_rejeicao
    end

    result
  end

  def generate_timeline(processo)
    timeline = []

    # Etapa 1: Criação (sempre presente)
    timeline << {
      etapa: 'criacao',
      data: processo.data_criacao&.iso8601,
      descricao: 'Processo de defesa criado',
      concluida: true
    }

    # Etapa 2: Triagem
    if processo.triagem? || processo.status_progressed_from?(:triagem)
      timeline << {
        etapa: 'triagem',
        data: find_notification_date(processo, :triagem) || processo.data_criacao&.iso8601,
        descricao: 'Processo em análise técnica inicial',
        concluida: !processo.triagem?
      }
    else
      timeline << {
        etapa: 'triagem',
        data: nil,
        descricao: 'Processo em análise técnica inicial',
        concluida: false
      }
    end

    # Etapa 3: Distribuição
    if processo.distribuido? || processo.status_progressed_from?(:distribuido)
      timeline << {
        etapa: 'distribuicao',
        data: find_notification_date(processo, :distribuicao),
        descricao: 'Processo distribuído para relator especializado',
        concluida: !processo.distribuido?
      }
    else
      timeline << {
        etapa: 'distribuicao',
        data: nil,
        descricao: 'Processo distribuído para relator especializado',
        concluida: false
      }
    end

    # Etapa 4: Análise
    if processo.em_analise? || processo.status_progressed_from?(:em_analise)
      timeline << {
        etapa: 'analise',
        data: find_notification_date(processo, :analise),
        descricao: 'Processo em análise jurídica pelo relator',
        concluida: !processo.em_analise?
      }
    else
      timeline << {
        etapa: 'analise',
        data: nil,
        descricao: 'Processo em análise jurídica pelo relator',
        concluida: false
      }
    end

    # Etapa 5: Votação
    if processo.em_votacao? || processo.status_progressed_from?(:em_votacao)
      timeline << {
        etapa: 'votacao',
        data: find_notification_date(processo, :votacao),
        descricao: 'Processo em votação pelo colegiado',
        concluida: !processo.em_votacao?
      }
    else
      timeline << {
        etapa: 'votacao',
        data: nil,
        descricao: 'Processo em votação pelo colegiado',
        concluida: false
      }
    end

    # Etapa 6: Decisão Final
    if processo.decidido? || processo.rejeitado?
      descricao = if processo.decidido?
                    resultado = processo.decisao_final_deferido? ? 'DEFERIDO' : 'INDEFERIDO'
                    "Processo finalizado - #{resultado}"
                  else
                    "Processo rejeitado"
                  end

      timeline << {
        etapa: 'decisao',
        data: processo.data_decisao&.iso8601,
        descricao: descricao,
        concluida: true
      }
    else
      timeline << {
        etapa: 'decisao',
        data: nil,
        descricao: 'Decisão final',
        concluida: false
      }
    end

    timeline
  end

  def find_notification_date(processo, tipo)
    notificacao = processo.notificacoes.find_by(tipo: tipo)
    notificacao&.created_at&.iso8601
  end

  def render_internal_error(message)
    render json: {
      error: "Internal Server Error",
      message: "Erro interno do servidor",
      details: Rails.env.development? ? message : "Entre em contato com o suporte"
    }, status: :internal_server_error
  end
end
