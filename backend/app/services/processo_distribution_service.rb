# frozen_string_literal: true

# Serviço responsável pela distribuição inteligente de processos para relatores
# baseada em especialização, carga de trabalho e disponibilidade
class ProcessoDistributionService
  include ActiveModel::Model
  include ActiveModel::Attributes

  attr_accessor :processo

  # Configurações de distribuição
  PESO_ESPECIALIZACAO = 0.6
  PESO_CARGA_TRABALHO = 0.4
  LIMITE_REDISTRIBUICAO = 3

  # Resultado padronizado do serviço
  Result = Struct.new(:success?, :data, :errors, keyword_init: true) do
    def success?
      success?
    end

    def failure?
      !success?
    end
  end

  def initialize(processo:)
    @processo = processo
    @errors = []
  end

  # Método principal para distribuir um processo
  def call
    return falha('Processo é obrigatório') unless processo.present?
    return falha('Processo deve estar em status de triagem') unless processo.triagem?

    relator_selecionado = encontrar_melhor_relator

    if relator_selecionado
      atribuir_processo_a_relator(relator_selecionado)
      sucesso(relator_selecionado)
    else
      falha('Nenhum relator disponível encontrado')
    end
  rescue StandardError => e
    Rails.logger.error "[ProcessoDistributionService] Erro na distribuição: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    falha("Erro interno: #{e.message}")
  end

  # Redistribuir processo para outro relator
  def redistribuir_para_relator(novo_relator)
    return falha('Novo relator é obrigatório') unless novo_relator.present?
    return falha('Processo deve ter um relator atual') unless processo.relator.present?
    return falha('Novo relator deve estar disponível') unless novo_relator.disponivel_para_processo?

    ActiveRecord::Base.transaction do
      # Liberar o relator atual
      relator_anterior = processo.relator
      relator_anterior.finalizar_processo!

      # Atribuir ao novo relator
      atribuir_processo_a_relator(novo_relator)

      Rails.logger.info "[ProcessoDistributionService] Processo #{processo.codigo_acompanhamento} redistribuído de #{relator_anterior.nome} para #{novo_relator.nome}"
    end

    sucesso(novo_relator)
  rescue StandardError => e
    Rails.logger.error "[ProcessoDistributionService] Erro na redistribuição: #{e.message}"
    falha("Erro na redistribuição: #{e.message}")
  end

  # Distribuir múltiplos processos em lote
  def self.distribuir_em_lote(processos)
    resultados = []
    processos_distribuidos = 0
    processos_falhados = 0

    processos.each do |processo|
      resultado = new(processo: processo).call
      resultados << { processo: processo, resultado: resultado }

      if resultado.success?
        processos_distribuidos += 1
      else
        processos_falhados += 1
        Rails.logger.warn "[ProcessoDistributionService] Falha na distribuição do processo #{processo.id}: #{resultado.errors.join(', ')}"
      end
    end

    Rails.logger.info "[ProcessoDistributionService] Distribuição em lote finalizada: #{processos_distribuidos} sucessos, #{processos_falhados} falhas"

    {
      total: processos.count,
      distribuidos: processos_distribuidos,
      falhados: processos_falhados,
      resultados: resultados
    }
  end

  # Obter estatísticas de distribuição
  def self.estatisticas_distribuicao
    relatores = Relator.all.includes(:processos)

    {
      total_relatores: relatores.count,
      relatores_disponiveis: relatores.count(&:disponivel_para_processo?),
      carga_total: relatores.sum(&:processos_ativos),
      carga_media: relatores.average(:processos_ativos)&.round(2) || 0,
      capacidade_total: relatores.sum(:capacidade_maxima),
      utilizacao_percentual: calcular_utilizacao_sistema(relatores)
    }
  end

  private

  # Encontra o melhor relator disponível usando algoritmo de pontuação
  def encontrar_melhor_relator
    relatores_candidatos = Relator.disponivel
                                  .com_capacidade
                                  .includes(:processos)

    return nil if relatores_candidatos.empty?

    # Filtrar por especialização se necessário
    relatores_especializados = filtrar_por_especializacao(relatores_candidatos)
    candidatos_finais = relatores_especializados.any? ? relatores_especializados : relatores_candidatos

    # Calcular pontuação para cada candidato
    melhor_relator = nil
    melhor_pontuacao = -1

    candidatos_finais.each do |relator|
      pontuacao = calcular_pontuacao_relator(relator)

      if pontuacao > melhor_pontuacao
        melhor_pontuacao = pontuacao
        melhor_relator = relator
      end
    end

    Rails.logger.info "[ProcessoDistributionService] Relator selecionado: #{melhor_relator&.nome} (pontuação: #{melhor_pontuacao})"
    melhor_relator
  end

  # Filtrar relatores por especialização
  def filtrar_por_especializacao(relatores)
    tipo_infracao = processo.tipo_infracao

    relatores.select do |relator|
      relator.pode_receber_processo?(tipo_infracao)
    end
  end

  # Calcular pontuação do relator baseada em múltiplos fatores
  def calcular_pontuacao_relator(relator)
    # Pontuação por especialização (0-1)
    pontuacao_especializacao = calcular_pontuacao_especializacao(relator)

    # Pontuação por carga de trabalho (0-1, invertida - menos carga = maior pontuação)
    pontuacao_carga = calcular_pontuacao_carga_trabalho(relator)

    # Pontuação por performance histórica (0-1)
    pontuacao_performance = calcular_pontuacao_performance(relator)

    # Pontuação final ponderada
    pontuacao_final = (
      pontuacao_especializacao * PESO_ESPECIALIZACAO +
      pontuacao_carga * PESO_CARGA_TRABALHO +
      pontuacao_performance * 0.2
    )

    Rails.logger.debug "[ProcessoDistributionService] Pontuação #{relator.nome}: esp=#{pontuacao_especializacao}, carga=#{pontuacao_carga}, perf=#{pontuacao_performance}, final=#{pontuacao_final}"

    pontuacao_final
  end

  # Calcular pontuação baseada na especialização
  def calcular_pontuacao_especializacao(relator)
    tipo_infracao = processo.tipo_infracao

    # Especialista direto tem pontuação máxima
    return 1.0 if relator.especializacoes.include?(tipo_infracao)

    # Generalista tem pontuação média
    return 0.7 if relator.especializacoes.include?('geral')

    # Não especializado tem pontuação baixa
    0.3
  end

  # Calcular pontuação baseada na carga de trabalho atual
  def calcular_pontuacao_carga_trabalho(relator)
    return 1.0 if relator.processos_ativos.zero?

    utilizacao = relator.processos_ativos.to_f / relator.capacidade_maxima

    # Invertida: menor utilização = maior pontuação
    1.0 - utilizacao
  end

  # Calcular pontuação baseada na performance histórica
  def calcular_pontuacao_performance(relator)
    metricas = relator.metricas_performance || {}

    # Se não há histórico, dar pontuação neutra
    return 0.5 unless metricas['total_processos']&.positive?

    # Considerar tempo médio de análise (menor tempo = maior pontuação)
    tempo_medio = metricas['tempo_medio_analise'] || 48.0
    pontuacao_tempo = [1.0 - (tempo_medio / 72.0), 0.1].max # Normalizar para 72 horas máximo

    pontuacao_tempo.clamp(0.1, 1.0)
  end

  # Atribuir processo ao relator selecionado
  def atribuir_processo_a_relator(relator)
    ActiveRecord::Base.transaction do
      processo.relator = relator
      processo.status = :distribuido
      processo.save!

      relator.atribuir_processo!

      # Criar notificação para o cidadão
      processo.criar_notificacao!(:distribuicao)

      Rails.logger.info "[ProcessoDistributionService] Processo #{processo.codigo_acompanhamento} distribuído para #{relator.nome}"
    end
  end

  # Calcular utilização do sistema
  def self.calcular_utilizacao_sistema(relatores)
    return 0 if relatores.empty?

    capacidade_total = relatores.sum(:capacidade_maxima)
    return 0 if capacidade_total.zero?

    carga_atual = relatores.sum(:processos_ativos)
    ((carga_atual.to_f / capacidade_total) * 100).round(2)
  end

  # Métodos auxiliares para resultados
  def sucesso(data)
    Result.new(success?: true, data: data, errors: [])
  end

  def falha(mensagem)
    @errors << mensagem
    Result.new(success?: false, data: nil, errors: @errors)
  end
end