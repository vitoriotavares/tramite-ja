# frozen_string_literal: true

# Serviço responsável pelo gerenciamento de votações em processos
# Inclui detecção de quórum, decisões automáticas e controle de qualidade
class VotacaoService
  include ActiveModel::Model
  include ActiveModel::Attributes

  attr_accessor :processo, :julgador, :decisao, :justificativa, :tempo_analise

  # Configurações de votação
  QUORUM_MINIMO = 3
  LIMITE_TEMPO_VOTACAO = 7.days
  PESO_VOTO_ESPECIALISTA = 1.0
  PESO_VOTO_GERAL = 0.8

  # Resultado padronizado do serviço
  Result = Struct.new(:success?, :data, :errors, :warnings, keyword_init: true) do
    def success?
      success?
    end

    def failure?
      !success?
    end
  end

  def initialize(processo:, julgador: nil, decisao: nil, justificativa: nil, tempo_analise: nil)
    @processo = processo
    @julgador = julgador
    @decisao = decisao
    @justificativa = justificativa
    @tempo_analise = tempo_analise
    @errors = []
    @warnings = []
  end

  # Registrar voto de um julgador
  def registrar_voto
    return falha('Processo é obrigatório') unless processo.present?
    return falha('Julgador é obrigatório') unless julgador.present?
    return falha('Decisão é obrigatória') unless decisao.present?
    return falha('Processo deve estar em votação') unless processo.em_votacao?

    # Validar se julgador pode votar
    validacao_result = validar_julgador_pode_votar

    return validacao_result unless validacao_result.success?

    # Criar o voto
    voto = criar_voto

    if voto.persisted?
      # Verificar quórum e finalizar se necessário
      resultado_votacao = verificar_e_finalizar_votacao

      Rails.logger.info "[VotacaoService] Voto registrado: #{julgador.nome} - #{decisao} (Processo: #{processo.codigo_acompanhamento})"

      sucesso({
        voto: voto,
        resultado_votacao: resultado_votacao,
        processo_finalizado: resultado_votacao[:quorum_atingido]
      })
    else
      falha(voto.errors.full_messages.join(', '))
    end

  rescue StandardError => e
    Rails.logger.error "[VotacaoService] Erro ao registrar voto: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    falha("Erro interno: #{e.message}")
  end

  # Iniciar votação para um processo
  def iniciar_votacao
    return falha('Processo é obrigatório') unless processo.present?
    return falha('Processo deve estar em análise') unless processo.em_analise?
    return falha('Parecer do relator é obrigatório') unless processo.parecer_relator.present?

    ActiveRecord::Base.transaction do
      # Transicionar para votação
      processo.transicionar_para!(:em_votacao)

      # Buscar julgadores disponíveis
      julgadores_disponiveis = selecionar_julgadores_para_votacao

      Rails.logger.info "[VotacaoService] Votação iniciada para processo #{processo.codigo_acompanhamento}"
      Rails.logger.info "[VotacaoService] Julgadores disponíveis: #{julgadores_disponiveis.count}"

      sucesso({
        julgadores_disponiveis: julgadores_disponiveis,
        prazo_votacao: LIMITE_TEMPO_VOTACAO.from_now,
        quorum_necessario: QUORUM_MINIMO
      })
    end

  rescue StandardError => e
    Rails.logger.error "[VotacaoService] Erro ao iniciar votação: #{e.message}"
    falha("Erro ao iniciar votação: #{e.message}")
  end

  # Verificar status atual da votação
  def status_votacao
    return falha('Processo é obrigatório') unless processo.present?

    resultado = calcular_resultado_votacao_detalhado

    sucesso({
      status: processo.status,
      resultado_atual: resultado,
      julgadores_pendentes: obter_julgadores_pendentes,
      tempo_restante: calcular_tempo_restante_votacao,
      pode_finalizar: pode_finalizar_votacao?(resultado)
    })
  end

  # Finalizar votação manualmente (para casos excepcionais)
  def finalizar_votacao_manual(motivo: nil)
    return falha('Processo é obrigatório') unless processo.present?
    return falha('Processo deve estar em votação') unless processo.em_votacao?

    resultado = calcular_resultado_votacao_detalhado

    unless pode_finalizar_votacao?(resultado)
      return falha('Votação não pode ser finalizada - critérios não atendidos')
    end

    ActiveRecord::Base.transaction do
      finalizar_processo_com_resultado(resultado, manual: true, motivo: motivo)

      Rails.logger.warn "[VotacaoService] Votação finalizada manualmente para processo #{processo.codigo_acompanhamento}. Motivo: #{motivo}"

      sucesso({
        resultado_final: resultado,
        finalizado_manualmente: true,
        motivo: motivo
      })
    end

  rescue StandardError => e
    Rails.logger.error "[VotacaoService] Erro na finalização manual: #{e.message}"
    falha("Erro na finalização manual: #{e.message}")
  end

  # Processar votações em lote
  def self.processar_votacoes_lote(votos_data)
    resultados = []
    votos_registrados = 0
    processos_finalizados = 0
    falhas = 0

    votos_data.each do |voto_data|
      resultado = new(
        processo: voto_data[:processo],
        julgador: voto_data[:julgador],
        decisao: voto_data[:decisao],
        justificativa: voto_data[:justificativa],
        tempo_analise: voto_data[:tempo_analise]
      ).registrar_voto

      resultados << { voto_data: voto_data, resultado: resultado }

      if resultado.success?
        votos_registrados += 1
        processos_finalizados += 1 if resultado.data[:processo_finalizado]
      else
        falhas += 1
      end
    end

    Rails.logger.info "[VotacaoService] Lote processado: #{votos_registrados} votos, #{processos_finalizados} processos finalizados, #{falhas} falhas"

    {
      total: votos_data.count,
      votos_registrados: votos_registrados,
      processos_finalizados: processos_finalizados,
      falhas: falhas,
      resultados: resultados
    }
  end

  # Estatísticas de votação
  def self.estatisticas_votacao(periodo = 30.days)
    data_inicio = periodo.ago

    votos_periodo = Voto.where(created_at: data_inicio..)
    processos_votacao = Processo.where(status: [:em_votacao, :decidido])
                               .where(created_at: data_inicio..)

    {
      total_votos: votos_periodo.count,
      processos_em_votacao: Processo.where(status: :em_votacao).count,
      processos_decididos: processos_votacao.where(status: :decidido).count,
      tempo_medio_decisao: calcular_tempo_medio_decisao(processos_votacao),
      taxa_quorum: calcular_taxa_quorum(processos_votacao),
      distribuicao_decisoes: calcular_distribuicao_decisoes(processos_votacao)
    }
  end

  private

  # Validar se julgador pode votar no processo
  def validar_julgador_pode_votar
    unless julgador.disponivel?
      return falha('Julgador não está disponível')
    end

    unless julgador.pode_votar_processo?(processo)
      return falha('Julgador não tem especialização para este tipo de processo')
    end

    if julgador.ja_votou_processo?(processo)
      return falha('Julgador já votou neste processo')
    end

    sucesso(nil)
  end

  # Criar voto no banco de dados
  def criar_voto
    voto_params = {
      processo: processo,
      julgador: julgador,
      decisao: decisao,
      tempo_analise: tempo_analise || calcular_tempo_analise_padrao
    }

    # Adicionar justificativa se for voto contrário
    if decisao == 'discordo' || decisao == :discordo
      voto_params[:justificativa] = justificativa || 'Justificativa não informada'
    end

    Voto.create!(voto_params)
  end

  # Verificar quórum e finalizar votação se necessário
  def verificar_e_finalizar_votacao
    resultado = calcular_resultado_votacao_detalhado

    if resultado[:quorum_atingido]
      finalizar_processo_com_resultado(resultado)
    end

    resultado
  end

  # Calcular resultado detalhado da votação
  def calcular_resultado_votacao_detalhado
    votos = processo.votos.includes(:julgador)

    total_votos = votos.count
    votos_favoraveis = votos.where(decisao: 'concordo').count
    votos_contrarios = votos.where(decisao: 'discordo').count

    quorum_atingido = total_votos >= QUORUM_MINIMO

    # Calcular decisão considerando peso dos votos
    decisao_final = nil
    if quorum_atingido
      peso_favoraveis = calcular_peso_votos(votos.where(decisao: 'concordo'))
      peso_contrarios = calcular_peso_votos(votos.where(decisao: 'discordo'))

      decisao_final = peso_favoraveis > peso_contrarios ? 'deferido' : 'indeferido'
    end

    {
      total_votos: total_votos,
      votos_favoraveis: votos_favoraveis,
      votos_contrarios: votos_contrarios,
      quorum_atingido: quorum_atingido,
      quorum_necessario: QUORUM_MINIMO,
      decisao_final: decisao_final,
      peso_favoraveis: peso_favoraveis || 0,
      peso_contrarios: peso_contrarios || 0,
      unanimidade: quorum_atingido && (votos_favoraveis == total_votos || votos_contrarios == total_votos),
      votos_detalhes: votos.map(&:resumo_voto)
    }
  end

  # Calcular peso dos votos baseado na especialização
  def calcular_peso_votos(votos)
    votos.sum do |voto|
      if voto.julgador.especializacoes.include?(processo.tipo_infracao)
        PESO_VOTO_ESPECIALISTA
      else
        PESO_VOTO_GERAL
      end
    end
  end

  # Finalizar processo com resultado da votação
  def finalizar_processo_com_resultado(resultado, manual: false, motivo: nil)
    ActiveRecord::Base.transaction do
      processo.decisao_final = resultado[:decisao_final]
      processo.data_decisao = Time.current
      processo.status = :decidido

      if manual && motivo
        # Adicionar observação sobre finalização manual
        processo.observacoes = "#{processo.observacoes}\n\nFinalização manual: #{motivo}".strip
      end

      processo.save!

      # Atualizar métricas do relator
      if processo.relator
        processo.relator.finalizar_processo!
        processo.relator.atualizar_metricas(processo.tempo_total_analise, resultado[:decisao_final])
      end

      # Criar notificação
      processo.criar_notificacao!(:decisao)

      Rails.logger.info "[VotacaoService] Processo #{processo.codigo_acompanhamento} finalizado: #{resultado[:decisao_final]} (#{resultado[:total_votos]} votos)"
    end
  end

  # Selecionar julgadores para votação baseado na especialização
  def selecionar_julgadores_para_votacao
    # Priorizar especialistas no tipo de infração
    especialistas = Julgador.disponivel
                           .por_especializacao(processo.tipo_infracao)

    # Se não há especialistas suficientes, incluir generalistas
    if especialistas.count < QUORUM_MINIMO
      generalistas = Julgador.disponivel
                            .por_especializacao('geral')
                            .where.not(id: especialistas.pluck(:id))

      especialistas.to_a + generalistas.to_a
    else
      especialistas
    end
  end

  # Obter julgadores que ainda não votaram
  def obter_julgadores_pendentes
    julgadores_que_votaram = processo.votos.pluck(:julgador_id)

    Julgador.disponivel
            .where.not(id: julgadores_que_votaram)
            .select { |j| j.pode_votar_processo?(processo) }
  end

  # Calcular tempo restante para votação
  def calcular_tempo_restante_votacao
    return nil unless processo.em_votacao?

    # Assumir que a votação começou quando o status mudou para em_votacao
    inicio_votacao = processo.updated_at
    prazo_final = inicio_votacao + LIMITE_TEMPO_VOTACAO

    tempo_restante = prazo_final - Time.current

    tempo_restante > 0 ? tempo_restante : 0
  end

  # Verificar se votação pode ser finalizada
  def pode_finalizar_votacao?(resultado)
    # Pode finalizar se:
    # 1. Quórum foi atingido
    # 2. OU tempo da votação expirou e há pelo menos 1 voto
    return true if resultado[:quorum_atingido]

    tempo_restante = calcular_tempo_restante_votacao
    tempo_restante&.zero? && resultado[:total_votos] > 0
  end

  # Calcular tempo de análise padrão se não informado
  def calcular_tempo_analise_padrao
    # Tempo médio baseado no histórico do julgador
    tempo_medio = julgador.tempo_medio_analise

    if tempo_medio > 0
      tempo_medio
    else
      30 # 30 minutos como padrão
    end
  end

  # Métodos de classe para estatísticas
  def self.calcular_tempo_medio_decisao(processos)
    processos_decididos = processos.where(status: :decidido)
                                  .where.not(data_decisao: nil)

    return 0 if processos_decididos.empty?

    tempos = processos_decididos.map do |p|
      # Tempo desde que entrou em votação até decisão
      inicio_votacao = p.updated_at # Aproximação
      (p.data_decisao - inicio_votacao) / 1.hour
    end

    (tempos.sum / tempos.size).round(2)
  end

  def self.calcular_taxa_quorum(processos)
    total = processos.count
    return 0 if total.zero?

    com_quorum = processos.joins(:votos)
                         .group('processos.id')
                         .having('COUNT(votos.id) >= ?', QUORUM_MINIMO)
                         .count
                         .keys
                         .count

    ((com_quorum.to_f / total) * 100).round(2)
  end

  def self.calcular_distribuicao_decisoes(processos)
    decisoes = processos.where(status: :decidido)
                       .group(:decisao_final)
                       .count

    total = decisoes.values.sum
    return {} if total.zero?

    decisoes.transform_values { |count| ((count.to_f / total) * 100).round(2) }
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