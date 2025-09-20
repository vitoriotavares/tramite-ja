class Api::V1::DashboardController < ApplicationController
  # Requer autenticação administrativa
  before_action :authenticate_admin!, if: :respond_to?

  # GET /api/v1/dashboard/metricas
  def metricas
    start_time = Time.current

    metricas = {
      processos_hoje: calcular_processos_hoje,
      processos_pendentes: calcular_processos_pendentes,
      tempo_medio_processamento: calcular_tempo_medio_processamento,
      taxa_deferimento: calcular_taxa_deferimento,
      alertas_prazo: calcular_alertas_prazo
    }

    # Adicionar métricas extras
    metricas.merge!(
      estatisticas_adicionais: calcular_estatisticas_adicionais,
      tempo_resposta: ((Time.current - start_time) * 1000).round(2)
    )

    render json: metricas
  rescue StandardError => e
    Rails.logger.error "[DashboardController#metricas] Erro: #{e.message}"
    render_internal_error(e.message)
  end

  # GET /api/v1/dashboard/overview
  def overview
    overview_data = {
      resumo_geral: calcular_resumo_geral,
      distribuicao_status: calcular_distribuicao_status,
      tendencias: calcular_tendencias,
      performance_relatores: calcular_performance_relatores,
      alertas_sistema: calcular_alertas_sistema
    }

    render json: overview_data
  rescue StandardError => e
    Rails.logger.error "[DashboardController#overview] Erro: #{e.message}"
    render_internal_error(e.message)
  end

  # GET /api/v1/dashboard/relatorios
  def relatorios
    periodo = params[:periodo] || '30'
    data_inicio = periodo.to_i.days.ago

    relatorios = {
      periodo: "#{periodo} dias",
      data_inicio: data_inicio.iso8601,
      data_fim: Time.current.iso8601,
      metricas_periodo: calcular_metricas_periodo(data_inicio),
      graficos: gerar_dados_graficos(data_inicio),
      rankings: calcular_rankings(data_inicio)
    }

    render json: relatorios
  rescue StandardError => e
    Rails.logger.error "[DashboardController#relatorios] Erro: #{e.message}"
    render_internal_error(e.message)
  end

  private

  def calcular_processos_hoje
    hoje = Date.current
    Processo.where(data_criacao: hoje.beginning_of_day..hoje.end_of_day).count
  end

  def calcular_processos_pendentes
    # Status pendentes: rascunho, triagem, distribuido, em_analise, em_votacao
    Processo.where(status: [:rascunho, :triagem, :distribuido, :em_analise, :em_votacao]).count
  end

  def calcular_tempo_medio_processamento
    # Calcular tempo médio dos processos finalizados nos últimos 30 dias
    processos_finalizados = Processo.where(status: [:decidido, :rejeitado])
                                   .where(data_decisao: 30.days.ago..)
                                   .where.not(data_decisao: nil)

    return 0.0 if processos_finalizados.empty?

    tempos = processos_finalizados.map do |processo|
      (processo.data_decisao - processo.data_criacao) / 1.day
    end

    (tempos.sum / tempos.size).round(2)
  end

  def calcular_taxa_deferimento
    # Taxa de deferimento dos processos decididos nos últimos 30 dias
    processos_decididos = Processo.where(status: :decidido)
                                 .where(data_decisao: 30.days.ago..)

    return 0.0 if processos_decididos.empty?

    deferidos = processos_decididos.where(decisao_final: :deferido).count
    taxa = (deferidos.to_f / processos_decididos.count) * 100

    taxa.round(2)
  end

  def calcular_alertas_prazo
    # Processos com mais de 80% do prazo consumido (24 dias de 30)
    limite_alerta = 24.days.ago

    Processo.where(status: [:triagem, :distribuido, :em_analise, :em_votacao])
            .where('data_criacao <= ?', limite_alerta)
            .count
  end

  def calcular_estatisticas_adicionais
    {
      total_processos: Processo.count,
      relatores_ativos: Relator.where(disponivel: true).count,
      julgadores_ativos: Julgador.where(disponivel: true).count,
      documentos_pendentes: Documento.where(status_validacao: :pendente).count,
      processos_em_votacao: Processo.where(status: :em_votacao).count,
      quorum_medio: calcular_quorum_medio,
      distribuicao_tipos: calcular_distribuicao_tipos_infracao
    }
  end

  def calcular_resumo_geral
    {
      total_processos_mes: Processo.where(data_criacao: 1.month.ago..).count,
      crescimento_mensal: calcular_crescimento_mensal,
      eficiencia_sistema: calcular_eficiencia_sistema,
      satisfacao_prazo: calcular_satisfacao_prazo
    }
  end

  def calcular_distribuicao_status
    Processo.group(:status).count.transform_keys { |status| status.humanize }
  end

  def calcular_tendencias
    # Calcular tendências dos últimos 7 dias
    dias = (0..6).map { |i| i.days.ago.to_date }

    {
      processos_por_dia: dias.map do |dia|
        {
          data: dia.iso8601,
          count: Processo.where(data_criacao: dia.beginning_of_day..dia.end_of_day).count
        }
      end,
      finalizacoes_por_dia: dias.map do |dia|
        {
          data: dia.iso8601,
          count: Processo.where(data_decisao: dia.beginning_of_day..dia.end_of_day).count
        }
      end
    }
  end

  def calcular_performance_relatores
    Relator.includes(:processos)
           .where(disponivel: true)
           .limit(10)
           .map do |relator|
      {
        nome: relator.nome,
        processos_ativos: relator.processos_ativos,
        capacidade_maxima: relator.capacidade_maxima,
        utilizacao: calcular_utilizacao_relator(relator),
        tempo_medio_analise: relator.tempo_medio_analise || 0,
        taxa_deferimento_relator: calcular_taxa_deferimento_relator(relator)
      }
    end
  end

  def calcular_alertas_sistema
    alertas = []

    # Processos em atraso crítico
    atraso_critico = Processo.where(status: [:triagem, :distribuido, :em_analise, :em_votacao])
                            .where('data_limite < ?', Time.current)
                            .count

    if atraso_critico > 0
      alertas << {
        tipo: 'critico',
        titulo: 'Processos em atraso',
        descricao: "#{atraso_critico} processos ultrapassaram o prazo legal",
        count: atraso_critico
      }
    end

    # Relatores sobrecarregados
    relatores_sobrecarregados = Relator.where('processos_ativos > capacidade_maxima').count

    if relatores_sobrecarregados > 0
      alertas << {
        tipo: 'aviso',
        titulo: 'Relatores sobrecarregados',
        descricao: "#{relatores_sobrecarregados} relatores acima da capacidade",
        count: relatores_sobrecarregados
      }
    end

    # Documentos pendentes há muito tempo
    docs_pendentes_antigos = Documento.where(status_validacao: :pendente)
                                     .where('created_at < ?', 7.days.ago)
                                     .count

    if docs_pendentes_antigos > 0
      alertas << {
        tipo: 'aviso',
        titulo: 'Documentos pendentes',
        descricao: "#{docs_pendentes_antigos} documentos aguardam validação há mais de 7 dias",
        count: docs_pendentes_antigos
      }
    end

    alertas
  end

  def calcular_metricas_periodo(data_inicio)
    processos_periodo = Processo.where(data_criacao: data_inicio..)

    {
      total_criados: processos_periodo.count,
      total_finalizados: processos_periodo.where(status: [:decidido, :rejeitado]).count,
      taxa_finalizacao: calcular_taxa_finalizacao(processos_periodo),
      tempo_medio_periodo: calcular_tempo_medio_periodo(data_inicio),
      distribuicao_decisoes: calcular_distribuicao_decisoes_periodo(data_inicio)
    }
  end

  def gerar_dados_graficos(data_inicio)
    # Dados para gráficos do dashboard
    {
      evolucao_processos: gerar_evolucao_processos(data_inicio),
      distribuicao_tipos: calcular_distribuicao_tipos_infracao,
      performance_relatores: gerar_performance_relatores_grafico,
      tempos_processamento: gerar_tempos_processamento_grafico(data_inicio)
    }
  end

  def calcular_rankings(data_inicio)
    {
      relatores_mais_eficientes: ranking_relatores_eficientes(data_inicio),
      tipos_infracao_mais_comuns: ranking_tipos_infracao(data_inicio),
      julgadores_mais_ativos: ranking_julgadores_ativos(data_inicio)
    }
  end

  # Métodos auxiliares
  def calcular_quorum_medio
    votacoes_com_quorum = Processo.joins(:votos)
                                 .where(status: :decidido)
                                 .group('processos.id')
                                 .having('COUNT(votos.id) >= 3')

    return 0.0 if votacoes_com_quorum.empty?

    total_votos = votacoes_com_quorum.joins(:votos).count
    (total_votos.to_f / votacoes_com_quorum.count).round(2)
  end

  def calcular_distribuicao_tipos_infracao
    Processo.group(:tipo_infracao).count
  end

  def calcular_crescimento_mensal
    mes_atual = Processo.where(data_criacao: 1.month.ago..).count
    mes_anterior = Processo.where(data_criacao: 2.months.ago..1.month.ago).count

    return 0.0 if mes_anterior.zero?

    crescimento = ((mes_atual - mes_anterior).to_f / mes_anterior) * 100
    crescimento.round(2)
  end

  def calcular_eficiencia_sistema
    # Percentual de processos finalizados dentro do prazo
    processos_no_prazo = Processo.where(status: [:decidido, :rejeitado])
                                .where('data_decisao <= data_limite')
                                .where(data_decisao: 30.days.ago..)
                                .count

    total_finalizados = Processo.where(status: [:decidido, :rejeitado])
                               .where(data_decisao: 30.days.ago..)
                               .count

    return 100.0 if total_finalizados.zero?

    eficiencia = (processos_no_prazo.to_f / total_finalizados) * 100
    eficiencia.round(2)
  end

  def calcular_satisfacao_prazo
    # Meta: 95% dos processos finalizados em até 5 dias
    meta_dias = 5.days

    processos_meta = Processo.where(status: [:decidido, :rejeitado])
                            .where(data_decisao: 30.days.ago..)
                            .where('data_decisao <= data_criacao + INTERVAL ? DAY', meta_dias.to_i / 1.day)
                            .count

    total_finalizados = Processo.where(status: [:decidido, :rejeitado])
                               .where(data_decisao: 30.days.ago..)
                               .count

    return 100.0 if total_finalizados.zero?

    satisfacao = (processos_meta.to_f / total_finalizados) * 100
    satisfacao.round(2)
  end

  def calcular_utilizacao_relator(relator)
    return 0.0 if relator.capacidade_maxima.zero?

    utilizacao = (relator.processos_ativos.to_f / relator.capacidade_maxima) * 100
    utilizacao.round(2)
  end

  def calcular_taxa_deferimento_relator(relator)
    processos_decididos = relator.processos.where(status: :decidido)
    return 0.0 if processos_decididos.empty?

    deferidos = processos_decididos.where(decisao_final: :deferido).count
    taxa = (deferidos.to_f / processos_decididos.count) * 100
    taxa.round(2)
  end

  def calcular_taxa_finalizacao(processos_periodo)
    return 0.0 if processos_periodo.empty?

    finalizados = processos_periodo.where(status: [:decidido, :rejeitado]).count
    taxa = (finalizados.to_f / processos_periodo.count) * 100
    taxa.round(2)
  end

  def calcular_tempo_medio_periodo(data_inicio)
    processos_finalizados = Processo.where(status: [:decidido, :rejeitado])
                                   .where(data_criacao: data_inicio..)
                                   .where.not(data_decisao: nil)

    return 0.0 if processos_finalizados.empty?

    tempos = processos_finalizados.map do |processo|
      (processo.data_decisao - processo.data_criacao) / 1.day
    end

    (tempos.sum / tempos.size).round(2)
  end

  def calcular_distribuicao_decisoes_periodo(data_inicio)
    Processo.where(status: :decidido)
            .where(data_decisao: data_inicio..)
            .group(:decisao_final)
            .count
  end

  def gerar_evolucao_processos(data_inicio)
    # Implementar dados para gráfico de evolução
    # Por simplicidade, retornar estrutura básica
    []
  end

  def gerar_performance_relatores_grafico
    # Implementar dados para gráfico de performance
    []
  end

  def gerar_tempos_processamento_grafico(data_inicio)
    # Implementar dados para gráfico de tempos
    []
  end

  def ranking_relatores_eficientes(data_inicio)
    # Implementar ranking de relatores
    []
  end

  def ranking_tipos_infracao(data_inicio)
    # Implementar ranking de tipos de infração
    []
  end

  def ranking_julgadores_ativos(data_inicio)
    # Implementar ranking de julgadores
    []
  end

  def authenticate_admin!
    # Implementar autenticação administrativa
    # Por enquanto, assumir que está autenticado
    true
  end

  def render_internal_error(message)
    render json: {
      error: "Internal Server Error",
      message: "Erro interno do servidor",
      details: Rails.env.development? ? message : "Entre em contato com o suporte"
    }, status: :internal_server_error
  end
end
