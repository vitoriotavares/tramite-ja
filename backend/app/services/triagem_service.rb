# frozen_string_literal: true

# Serviço responsável pela triagem automatizada de processos
# Inclui validação de documentos, verificação de requisitos legais e aprovação automática
class TriagemService
  include ActiveModel::Model
  include ActiveModel::Attributes

  attr_accessor :processo

  # Constantes de configuração
  DOCUMENTOS_OBRIGATORIOS_BASE = %w[cnh].freeze
  DOCUMENTOS_OBRIGATORIOS_VEICULO = %w[cnh crlv].freeze
  TIPOS_INFRACAO_VEICULO = %w[velocidade rodizio].freeze

  # Critérios de aprovação automática
  CRITERIOS_APROVACAO_AUTOMATICA = {
    documentos_aprovados: true,
    prazo_dentro_limite: true,
    dados_completos: true,
    sem_irregularidades: true
  }.freeze

  # Resultado padronizado do serviço
  Result = Struct.new(:success?, :data, :errors, :warnings, keyword_init: true) do
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
    @warnings = []
  end

  # Método principal para realizar triagem
  def call
    return falha('Processo é obrigatório') unless processo.present?
    return falha('Processo deve estar em status rascunho para triagem') unless processo.rascunho?

    Rails.logger.info "[TriagemService] Iniciando triagem do processo #{processo.codigo_acompanhamento}"

    resultado_triagem = {
      documentos: validar_documentos,
      requisitos: validar_requisitos_legais,
      dados: validar_completude_dados,
      irregularidades: verificar_irregularidades
    }

    # Determinar se pode ser aprovado automaticamente
    if pode_aprovar_automaticamente?(resultado_triagem)
      aprovar_automaticamente(resultado_triagem)
    else
      requer_analise_manual(resultado_triagem)
    end

  rescue StandardError => e
    Rails.logger.error "[TriagemService] Erro na triagem: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    falha("Erro interno na triagem: #{e.message}")
  end

  # Revalidar documentos após upload
  def revalidar_documentos
    return falha('Processo é obrigatório') unless processo.present?

    resultado_validacao = validar_documentos

    if resultado_validacao[:todos_aprovados]
      processo.update!(status: :triagem) if processo.rascunho?
      sucesso(resultado_validacao, ['Documentos revalidados com sucesso'])
    else
      sucesso(resultado_validacao, ['Ainda há pendências na documentação'])
    end

  rescue StandardError => e
    Rails.logger.error "[TriagemService] Erro na revalidação: #{e.message}"
    falha("Erro na revalidação: #{e.message}")
  end

  # Processar lote de triagens
  def self.processar_lote(processos)
    resultados = []
    aprovados_automaticamente = 0
    requer_analise = 0
    falhados = 0

    processos.each do |processo|
      resultado = new(processo: processo).call
      resultados << { processo: processo, resultado: resultado }

      case resultado.data&.dig(:acao)
      when :aprovado_automaticamente
        aprovados_automaticamente += 1
      when :requer_analise_manual
        requer_analise += 1
      else
        falhados += 1
      end
    end

    Rails.logger.info "[TriagemService] Lote processado: #{aprovados_automaticamente} aprovações automáticas, #{requer_analise} análises manuais, #{falhados} falhas"

    {
      total: processos.count,
      aprovados_automaticamente: aprovados_automaticamente,
      requer_analise: requer_analise,
      falhados: falhados,
      resultados: resultados
    }
  end

  # Estatísticas de triagem
  def self.estatisticas_triagem(periodo = 30.days)
    data_inicio = periodo.ago

    processos_triagem = Processo.where(created_at: data_inicio..)
                               .where(status: [:triagem, :distribuido, :em_analise, :em_votacao, :decidido, :rejeitado])

    {
      total_processos: processos_triagem.count,
      em_triagem: Processo.where(status: :triagem).count,
      tempo_medio_triagem: calcular_tempo_medio_triagem(processos_triagem),
      taxa_aprovacao_automatica: calcular_taxa_aprovacao_automatica(processos_triagem),
      principais_motivos_rejeicao: obter_principais_motivos_rejeicao(data_inicio)
    }
  end

  private

  # Validar todos os documentos do processo
  def validar_documentos
    documentos = processo.documentos.includes(:processo)
    documentos_obrigatorios = obter_documentos_obrigatorios

    resultado = {
      documentos_enviados: documentos.count,
      documentos_aprovados: documentos.aprovados.count,
      documentos_rejeitados: documentos.rejeitados.count,
      documentos_pendentes: documentos.pendentes.count,
      tipos_obrigatorios: documentos_obrigatorios,
      tipos_presentes: documentos.pluck(:tipo),
      detalhes: {}
    }

    # Verificar cada tipo obrigatório
    documentos_obrigatorios.each do |tipo|
      documento = documentos.find { |d| d.tipo == tipo }

      if documento
        resultado[:detalhes][tipo] = analisar_documento(documento)
      else
        resultado[:detalhes][tipo] = {
          presente: false,
          status: 'ausente',
          motivo: "Documento #{tipo.upcase} é obrigatório e não foi enviado"
        }
      end
    end

    # Verificar se todos obrigatórios estão aprovados
    resultado[:todos_obrigatorios_presentes] = documentos_obrigatorios.all? do |tipo|
      resultado[:detalhes][tipo][:presente]
    end

    resultado[:todos_aprovados] = documentos_obrigatorios.all? do |tipo|
      resultado[:detalhes][tipo][:status] == 'aprovado'
    end

    Rails.logger.debug "[TriagemService] Validação documentos: #{resultado[:todos_aprovados] ? 'APROVADA' : 'PENDENTE'}"
    resultado
  end

  # Analisar documento individual
  def analisar_documento(documento)
    {
      presente: true,
      status: documento.status_validacao,
      tamanho: documento.tamanho_formatado,
      tipo_mime: documento.tipo_mime,
      arquivo_valido: documento.arquivo_valido?,
      motivo_rejeicao: documento.motivo_rejeicao,
      dias_desde_upload: documento.dias_desde_upload,
      urgente: documento.urgente_para_validacao?
    }
  end

  # Validar requisitos legais específicos
  def validar_requisitos_legais
    resultado = {
      prazo_legal: validar_prazo_legal,
      tipo_infracao_valido: validar_tipo_infracao,
      dados_obrigatorios: validar_dados_obrigatorios_processo
    }

    resultado[:todos_validos] = resultado.values.all? { |v| v[:valido] }
    resultado
  end

  # Validar prazo legal para defesa
  def validar_prazo_legal
    # Prazo máximo de 30 dias para protocolo
    prazo_limite = 30.days.from_now
    dentro_prazo = processo.data_limite <= prazo_limite

    {
      valido: dentro_prazo,
      data_limite: processo.data_limite,
      dias_restantes: processo.dias_para_vencimento,
      motivo: dentro_prazo ? nil : 'Processo protocolado fora do prazo legal'
    }
  end

  # Validar tipo de infração
  def validar_tipo_infracao
    tipos_validos = Processo.tipo_infraccao.keys
    valido = processo.tipo_infracao.in?(tipos_validos)

    {
      valido: valido,
      tipo: processo.tipo_infracao,
      motivo: valido ? nil : 'Tipo de infração não reconhecido pelo sistema'
    }
  end

  # Validar dados obrigatórios do processo
  def validar_dados_obrigatorios_processo
    campos_obrigatorios = %w[codigo_acompanhamento tipo_infracao data_criacao data_limite]
    campos_faltantes = []

    campos_obrigatorios.each do |campo|
      valor = processo.send(campo)
      campos_faltantes << campo if valor.blank?
    end

    {
      valido: campos_faltantes.empty?,
      campos_faltantes: campos_faltantes,
      motivo: campos_faltantes.any? ? "Campos obrigatórios ausentes: #{campos_faltantes.join(', ')}" : nil
    }
  end

  # Validar completude dos dados
  def validar_completude_dados
    # Verificar se o cidadão tem dados completos
    cidadao = processo.cidadao
    dados_cidadao_completos = cidadao&.nome.present? && cidadao&.email.present?

    resultado = {
      cidadao_completo: dados_cidadao_completos,
      documentos_completos: processo.documentos_obrigatorios_completos?,
      processo_completo: processo.valid?
    }

    resultado[:todos_completos] = resultado.values.all?
    resultado
  end

  # Verificar irregularidades que impedem aprovação
  def verificar_irregularidades
    irregularidades = []

    # Verificar duplicatas por código de acompanhamento
    if Processo.where(codigo_acompanhamento: processo.codigo_acompanhamento)
               .where.not(id: processo.id).exists?
      irregularidades << 'Código de acompanhamento duplicado'
    end

    # Verificar se cidadão tem outros processos pendentes do mesmo tipo
    processos_similares = Processo.joins(:cidadao)
                                  .where(cidadao: processo.cidadao)
                                  .where(tipo_infracao: processo.tipo_infracao)
                                  .where(status: [:triagem, :distribuido, :em_analise, :em_votacao])
                                  .where.not(id: processo.id)

    if processos_similares.exists?
      irregularidades << 'Cidadão possui outro processo do mesmo tipo em andamento'
    end

    # Verificar integridade dos documentos
    documentos_problematicos = processo.documentos.select do |doc|
      !doc.arquivo_valido? || doc.rejeitado?
    end

    if documentos_problematicos.any?
      irregularidades << "Documentos com problemas: #{documentos_problematicos.map(&:tipo).join(', ')}"
    end

    {
      tem_irregularidades: irregularidades.any?,
      lista_irregularidades: irregularidades,
      total: irregularidades.count
    }
  end

  # Verificar se pode ser aprovado automaticamente
  def pode_aprovar_automaticamente?(resultado_triagem)
    return false unless resultado_triagem[:documentos][:todos_aprovados]
    return false unless resultado_triagem[:requisitos][:todos_validos]
    return false unless resultado_triagem[:dados][:todos_completos]
    return false if resultado_triagem[:irregularidades][:tem_irregularidades]

    # Critérios adicionais para aprovação automática
    return false if processo.em_atraso?
    return false if processo.dias_para_vencimento <= 2 # Urgente, requer revisão manual

    true
  end

  # Aprovar automaticamente
  def aprovar_automaticamente(resultado_triagem)
    ActiveRecord::Base.transaction do
      # Transicionar para triagem e depois distribuir
      processo.transicionar_para!(:triagem)

      # Distribuir automaticamente para relator
      distribuicao_result = ProcessoDistributionService.new(processo: processo).call

      if distribuicao_result.success?
        Rails.logger.info "[TriagemService] Processo #{processo.codigo_acompanhamento} aprovado automaticamente e distribuído"

        data = resultado_triagem.merge(
          acao: :aprovado_automaticamente,
          relator_atribuido: distribuicao_result.data,
          motivo: 'Processo aprovado automaticamente - todos os critérios atendidos'
        )

        sucesso(data)
      else
        # Se falhar na distribuição, manter em triagem para análise manual
        @warnings << 'Aprovado na triagem mas falhou na distribuição automática'
        requer_analise_manual(resultado_triagem)
      end
    end
  end

  # Marcar para análise manual
  def requer_analise_manual(resultado_triagem)
    motivos_analise = []

    unless resultado_triagem[:documentos][:todos_aprovados]
      motivos_analise << 'Documentos pendentes de aprovação'
    end

    unless resultado_triagem[:requisitos][:todos_validos]
      motivos_analise << 'Requisitos legais não atendidos'
    end

    unless resultado_triagem[:dados][:todos_completos]
      motivos_analise << 'Dados incompletos'
    end

    if resultado_triagem[:irregularidades][:tem_irregularidades]
      motivos_analise << 'Irregularidades detectadas'
    end

    # Manter em triagem para análise manual
    processo.update!(status: :triagem) unless processo.triagem?

    Rails.logger.info "[TriagemService] Processo #{processo.codigo_acompanhamento} requer análise manual: #{motivos_analise.join(', ')}"

    data = resultado_triagem.merge(
      acao: :requer_analise_manual,
      motivos_analise: motivos_analise,
      prioridade: calcular_prioridade_analise(resultado_triagem)
    )

    sucesso(data, motivos_analise)
  end

  # Calcular prioridade para análise manual
  def calcular_prioridade_analise(resultado_triagem)
    prioridade = :normal

    # Alta prioridade se próximo do vencimento
    if processo.dias_para_vencimento <= 3
      prioridade = :alta
    end

    # Prioridade baixa se há muitas pendências
    if resultado_triagem[:irregularidades][:total] > 2
      prioridade = :baixa
    end

    prioridade
  end

  # Obter lista de documentos obrigatórios baseado no tipo de infração
  def obter_documentos_obrigatorios
    base = DOCUMENTOS_OBRIGATORIOS_BASE.dup

    if TIPOS_INFRACAO_VEICULO.include?(processo.tipo_infracao)
      base.concat(DOCUMENTOS_OBRIGATORIOS_VEICULO - base)
    end

    base
  end

  # Métodos de classe para estatísticas
  def self.calcular_tempo_medio_triagem(processos)
    tempos = processos.select do |p|
      p.status != 'rascunho' && p.created_at && p.updated_at
    end.map do |p|
      (p.updated_at - p.created_at) / 1.hour
    end

    return 0 if tempos.empty?
    tempos.sum / tempos.size
  end

  def self.calcular_taxa_aprovacao_automatica(processos)
    return 0 if processos.empty?

    automaticos = processos.joins(:notificacoes)
                          .where(notificacoes: { tipo: 'distribuicao' })
                          .where('notificacoes.created_at - processos.created_at < ?', 1.hour)
                          .count

    (automaticos.to_f / processos.count * 100).round(2)
  end

  def self.obter_principais_motivos_rejeicao(data_inicio)
    Processo.where(status: :rejeitado)
            .where(created_at: data_inicio..)
            .group(:justificativa_rejeicao)
            .count
            .sort_by { |_, count| -count }
            .first(5)
            .to_h
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