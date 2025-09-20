# frozen_string_literal: true

# Serviço responsável pelo sistema de notificações por email
# Gerencia templates, envios, reenvios e monitoramento de entrega
class NotificationService
  include ActiveModel::Model
  include ActiveModel::Attributes

  attr_accessor :processo, :tipo_notificacao, :destinatario_email, :parametros_customizacao

  # Configurações do serviço
  MAX_TENTATIVAS_ENVIO = 3
  TEMPO_BACKOFF_BASE = 1.hour
  TEMPO_LIMITE_ENVIO = 24.hours

  # Tipos de notificação por prioridade
  PRIORIDADES = {
    alta: %w[decisao],
    media: %w[votacao distribuicao analise],
    baixa: %w[triagem criacao]
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

  def initialize(processo: nil, tipo_notificacao: nil, destinatario_email: nil, parametros_customizacao: {})
    @processo = processo
    @tipo_notificacao = tipo_notificacao
    @destinatario_email = destinatario_email
    @parametros_customizacao = parametros_customizacao || {}
    @errors = []
    @warnings = []
  end

  # Criar e enviar notificação
  def enviar_notificacao
    return falha('Processo é obrigatório') unless processo.present?
    return falha('Tipo de notificação é obrigatório') unless tipo_notificacao.present?

    # Definir destinatário se não especificado
    email_destinatario = destinatario_email || processo.cidadao.email

    return falha('Email do destinatário é obrigatório') unless email_destinatario.present?

    # Gerar conteúdo personalizado
    conteudo_notificacao = gerar_conteudo_personalizado

    # Criar registro de notificação
    notificacao = criar_notificacao(email_destinatario, conteudo_notificacao)

    if notificacao.persisted?
      # Enviar notificação
      resultado_envio = processar_envio(notificacao)

      Rails.logger.info "[NotificationService] Notificação #{tipo_notificacao} criada para processo #{processo.codigo_acompanhamento}"

      sucesso({
        notificacao: notificacao,
        enviado: resultado_envio,
        conteudo: conteudo_notificacao
      })
    else
      falha(notificacao.errors.full_messages.join(', '))
    end

  rescue StandardError => e
    Rails.logger.error "[NotificationService] Erro ao enviar notificação: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    falha("Erro interno: #{e.message}")
  end

  # Reenviar notificação falhada
  def reenviar_notificacao(notificacao_id)
    notificacao = Notificacao.find_by(id: notificacao_id)

    return falha('Notificação não encontrada') unless notificacao
    return falha('Notificação não pode ser reenviada') unless notificacao.pode_tentar_envio?

    resultado_reenvio = processar_envio(notificacao)

    if resultado_reenvio
      Rails.logger.info "[NotificationService] Notificação #{notificacao.id} reenviada com sucesso"
      sucesso({ notificacao: notificacao, reenviado: true })
    else
      falha('Falha no reenvio da notificação')
    end

  rescue StandardError => e
    Rails.logger.error "[NotificationService] Erro no reenvio: #{e.message}"
    falha("Erro no reenvio: #{e.message}")
  end

  # Processar notificações em lote
  def self.processar_lote_notificacoes(dados_notificacoes)
    resultados = []
    enviadas = 0
    falhadas = 0

    dados_notificacoes.each do |dados|
      resultado = new(
        processo: dados[:processo],
        tipo_notificacao: dados[:tipo],
        destinatario_email: dados[:email],
        parametros_customizacao: dados[:parametros] || {}
      ).enviar_notificacao

      resultados << { dados: dados, resultado: resultado }

      if resultado.success? && resultado.data[:enviado]
        enviadas += 1
      else
        falhadas += 1
      end
    end

    Rails.logger.info "[NotificationService] Lote processado: #{enviadas} enviadas, #{falhadas} falhadas"

    {
      total: dados_notificacoes.count,
      enviadas: enviadas,
      falhadas: falhadas,
      resultados: resultados
    }
  end

  # Reprocessar notificações falhadas
  def self.reprocessar_falhadas
    notificacoes_para_reenvio = Notificacao.para_reenvio
                                          .where('data_criacao > ?', TEMPO_LIMITE_ENVIO.ago)

    Rails.logger.info "[NotificationService] Reprocessando #{notificacoes_para_reenvio.count} notificações falhadas"

    reenviadas = 0
    falhadas_definitivamente = 0

    notificacoes_para_reenvio.find_each do |notificacao|
      if deve_reenviar_notificacao?(notificacao)
        if notificacao.reenviar!
          reenviadas += 1
        else
          falhadas_definitivamente += 1
        end
      end
    end

    Rails.logger.info "[NotificationService] Reprocessamento concluído: #{reenviadas} reenviadas, #{falhadas_definitivamente} falhadas"

    {
      processadas: notificacoes_para_reenvio.count,
      reenviadas: reenviadas,
      falhadas_definitivamente: falhadas_definitivamente
    }
  end

  # Estatísticas de notificações
  def self.estatisticas_notificacoes(periodo = 30.days)
    data_inicio = periodo.ago

    notificacoes_periodo = Notificacao.where(data_criacao: data_inicio..)

    estatisticas = {
      total_notificacoes: notificacoes_periodo.count,
      enviadas: notificacoes_periodo.enviadas.count,
      pendentes: notificacoes_periodo.pendentes.count,
      falhadas: notificacoes_periodo.falhadas.count,
      taxa_sucesso: calcular_taxa_sucesso(notificacoes_periodo),
      tempo_medio_envio: calcular_tempo_medio_envio(notificacoes_periodo),
      distribuicao_por_tipo: notificacoes_periodo.group(:tipo).count,
      picos_de_volume: detectar_picos_volume(notificacoes_periodo)
    }

    estatisticas
  end

  # Verificar saúde do sistema de notificações
  def self.verificar_saude_sistema
    notificacoes_recentes = Notificacao.where('data_criacao > ?', 1.hour.ago)
    pendentes_criticas = Notificacao.pendentes
                                   .joins(:processo)
                                   .where('notificacoes.data_criacao < ?', 30.minutes.ago)

    {
      status: calcular_status_sistema(notificacoes_recentes, pendentes_criticas),
      notificacoes_ultima_hora: notificacoes_recentes.count,
      pendentes_criticas: pendentes_criticas.count,
      taxa_sucesso_recente: calcular_taxa_sucesso(notificacoes_recentes),
      alertas: gerar_alertas_sistema(notificacoes_recentes, pendentes_criticas)
    }
  end

  private

  # Gerar conteúdo personalizado da notificação
  def gerar_conteudo_personalizado
    template_base = obter_template_notificacao

    # Mesclar parâmetros padrão com customizações
    parametros_completos = gerar_parametros_padrao.merge(parametros_customizacao)

    # Personalizar assunto e conteúdo
    {
      assunto: personalizar_texto(template_base[:assunto], parametros_completos),
      conteudo: personalizar_texto(template_base[:conteudo], parametros_completos),
      parametros: parametros_completos
    }
  end

  # Obter template da notificação
  def obter_template_notificacao
    templates = Notificacao.obter_template(tipo_notificacao)

    # Adicionar personalizações específicas por tipo
    case tipo_notificacao.to_sym
    when :decisao
      if processo.decidido?
        resultado = processo.decisao_final_deferido? ? 'DEFERIDO' : 'INDEFERIDO'
        templates[:assunto] += " - #{resultado}"
        templates[:conteudo] += "\n\nResultado: #{resultado}"
      end
    when :votacao
      quorum_info = processo.calcular_resultado_votacao
      templates[:conteudo] += "\n\nVotos até agora: #{quorum_info[:total_votos]} (mínimo necessário: 3)"
    end

    templates
  end

  # Gerar parâmetros padrão para personalização
  def gerar_parametros_padrao
    {
      nome_cidadao: processo.cidadao.nome_completo || processo.cidadao.nome || 'Cidadão',
      codigo_processo: processo.codigo_acompanhamento_formatado,
      tipo_infracao: processo.tipo_infracao.humanize,
      status_processo: processo.status.humanize,
      data_limite: processo.data_limite ? I18n.l(processo.data_limite, format: :long) : 'Não definida',
      dias_limite: processo.dias_para_vencimento.to_s,
      link_acompanhamento: gerar_link_acompanhamento,
      data_atual: I18n.l(Time.current, format: :long),
      progresso: "#{processo.progresso_percentual}%"
    }
  end

  # Personalizar texto com parâmetros
  def personalizar_texto(texto, parametros)
    texto_personalizado = texto.dup

    parametros.each do |chave, valor|
      placeholder = "{{#{chave}}}"
      texto_personalizado.gsub!(placeholder, valor.to_s)
    end

    texto_personalizado
  end

  # Gerar link de acompanhamento
  def gerar_link_acompanhamento
    base_url = Rails.application.config.application_url || 'https://tramiteja.gov.br'
    "#{base_url}/acompanhar/#{processo.codigo_acompanhamento}"
  end

  # Criar registro de notificação
  def criar_notificacao(email_destinatario, conteudo)
    Notificacao.create!(
      processo: processo,
      destinatario_email: email_destinatario,
      tipo: tipo_notificacao,
      assunto: conteudo[:assunto],
      conteudo: conteudo[:conteudo],
      status_envio: 'pendente'
    )
  end

  # Processar envio da notificação
  def processar_envio(notificacao)
    # Verificar se deve enviar baseado na prioridade e horário
    return false unless deve_enviar_agora?(notificacao)

    # Enviar notificação
    resultado = notificacao.enviar!

    if resultado
      Rails.logger.info "[NotificationService] Notificação #{notificacao.id} enviada com sucesso"
    else
      @warnings << "Falha no envio da notificação (tentativa #{notificacao.tentativas})"
      Rails.logger.warn "[NotificationService] Falha no envio da notificação #{notificacao.id}"
    end

    resultado
  end

  # Verificar se deve enviar notificação agora
  def deve_enviar_agora?(notificacao)
    # Verificar horário comercial para notificações não críticas
    unless notificacao.prioridade == 'alta'
      hora_atual = Time.current.hour
      return false if hora_atual < 8 || hora_atual > 18 # Fora do horário comercial
    end

    # Verificar rate limiting para evitar spam
    notificacoes_recentes = Notificacao.where(
      destinatario_email: notificacao.destinatario_email,
      data_envio: 1.hour.ago..Time.current
    ).count

    return false if notificacoes_recentes > 5 # Máximo 5 emails por hora

    true
  end

  # Verificar se deve reenviar notificação falhada
  def self.deve_reenviar_notificacao?(notificacao)
    return false unless notificacao.pode_tentar_envio?

    # Backoff exponencial
    tempo_espera = TEMPO_BACKOFF_BASE * (2**(notificacao.tentativas - 1))
    tempo_desde_ultima_tentativa = Time.current - notificacao.updated_at

    tempo_desde_ultima_tentativa >= tempo_espera
  end

  # Métodos de estatísticas
  def self.calcular_taxa_sucesso(notificacoes)
    total = notificacoes.count
    return 0 if total.zero?

    enviadas = notificacoes.enviadas.count
    ((enviadas.to_f / total) * 100).round(2)
  end

  def self.calcular_tempo_medio_envio(notificacoes)
    notificacoes_enviadas = notificacoes.enviadas
                                      .where.not(data_envio: nil)

    return 0 if notificacoes_enviadas.empty?

    tempos = notificacoes_enviadas.map do |n|
      (n.data_envio - n.data_criacao) / 1.minute
    end

    (tempos.sum / tempos.size).round(2)
  end

  def self.detectar_picos_volume(notificacoes)
    # Agrupar por hora e detectar picos
    volume_por_hora = notificacoes.group_by_hour(:data_criacao).count
    return {} if volume_por_hora.empty?

    media = volume_por_hora.values.sum.to_f / volume_por_hora.size
    desvio_padrao = Math.sqrt(volume_por_hora.values.map { |v| (v - media)**2 }.sum / volume_por_hora.size)

    # Picos são horas com volume > média + 2 * desvio padrão
    limite_pico = media + (2 * desvio_padrao)

    volume_por_hora.select { |_, volume| volume > limite_pico }
  end

  def self.calcular_status_sistema(notificacoes_recentes, pendentes_criticas)
    taxa_sucesso = calcular_taxa_sucesso(notificacoes_recentes)
    total_pendentes_criticas = pendentes_criticas.count

    if taxa_sucesso > 95 && total_pendentes_criticas < 5
      'saudavel'
    elsif taxa_sucesso > 80 && total_pendentes_criticas < 20
      'atencao'
    else
      'critico'
    end
  end

  def self.gerar_alertas_sistema(notificacoes_recentes, pendentes_criticas)
    alertas = []

    taxa_sucesso = calcular_taxa_sucesso(notificacoes_recentes)
    if taxa_sucesso < 80
      alertas << "Taxa de sucesso baixa: #{taxa_sucesso}%"
    end

    if pendentes_criticas.count > 10
      alertas << "Muitas notificações pendentes críticas: #{pendentes_criticas.count}"
    end

    volume_ultima_hora = notificacoes_recentes.count
    if volume_ultima_hora > 100
      alertas << "Alto volume de notificações: #{volume_ultima_hora} na última hora"
    end

    alertas
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