class Notificacao < ApplicationRecord
  self.table_name = 'notificacaos'

  # Relacionamentos
  belongs_to :processo

  # Enums
  enum :tipo, {
    criacao: 0,
    triagem: 1,
    distribuicao: 2,
    analise: 3,
    votacao: 4,
    decisao: 5
  }

  enum :status_envio, {
    pendente: 0,
    enviado: 1,
    falhado: 2
  }

  # Constantes
  MAX_TENTATIVAS = 3

  # Validações
  validates :processo, presence: true
  validates :destinatario_email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :tipo, presence: true
  validates :assunto, presence: true, length: { maximum: 255 }
  validates :conteudo, presence: true
  validates :status_envio, presence: true
  validates :data_criacao, presence: true
  validates :tentativas, presence: true, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: MAX_TENTATIVAS }

  # Validações condicionais
  validates :data_envio, presence: true, if: :enviado?

  # Callbacks
  before_create :set_data_criacao
  before_create :set_tentativas_default
  after_create :enviar_notificacao_async, if: :pendente?

  # Scopes
  scope :por_processo, ->(processo) { where(processo: processo) }
  scope :por_tipo, ->(tipo) { where(tipo: tipo) }
  scope :por_status, ->(status) { where(status_envio: status) }
  scope :pendentes, -> { where(status_envio: 'pendente') }
  scope :enviadas, -> { where(status_envio: 'enviado') }
  scope :falhadas, -> { where(status_envio: 'falhado') }
  scope :para_reenvio, -> { where(status_envio: 'falhado', tentativas: 0...MAX_TENTATIVAS) }
  scope :por_periodo, ->(inicio, fim) { where(data_criacao: inicio..fim) }

  # Métodos de instância
  def pode_tentar_envio?
    (pendente? || falhado?) && tentativas < MAX_TENTATIVAS
  end

  def tentativas_restantes
    MAX_TENTATIVAS - tentativas
  end

  def enviar!
    return false unless pode_tentar_envio?

    increment!(:tentativas)

    begin
      # Simulação de envio de email
      # Na implementação real, usar ActionMailer ou serviço de email
      resultado_envio = simular_envio_email

      if resultado_envio[:sucesso]
        update!(
          status_envio: 'enviado',
          data_envio: Time.current
        )
        Rails.logger.info "Notificação #{id} enviada com sucesso para #{destinatario_email}"
        true
      else
        atualizar_falha_envio(resultado_envio[:erro])
        false
      end
    rescue StandardError => e
      atualizar_falha_envio(e.message)
      false
    end
  end

  def reenviar!
    return false unless falhado? && tentativas < MAX_TENTATIVAS

    enviar!
  end

  def marcar_como_enviado!(data_envio_param = nil)
    update!(
      status_envio: 'enviado',
      data_envio: data_envio_param || Time.current
    )
  end

  def tempo_desde_criacao
    return 0 unless data_criacao
    ((Time.current - data_criacao) / 1.hour).round(2)
  end

  def tempo_para_envio
    return 0 unless data_criacao && data_envio
    ((data_envio - data_criacao) / 1.minute).round(2)
  end

  def resumo_envio
    {
      id: id,
      tipo: tipo,
      destinatario: destinatario_email,
      status: status_envio,
      tentativas: tentativas,
      tentativas_restantes: tentativas_restantes,
      data_criacao: data_criacao,
      data_envio: data_envio,
      tempo_processamento: tempo_para_envio,
      pode_reenviar: pode_tentar_envio?
    }
  end

  def tipo_formatado
    case tipo.to_sym
    when :criacao then 'Criação do Processo'
    when :triagem then 'Processo em Triagem'
    when :distribuicao then 'Processo Distribuído'
    when :analise then 'Análise Jurídica'
    when :votacao then 'Votação em Andamento'
    when :decisao then 'Decisão Final'
    else tipo.humanize
    end
  end

  def prioridade
    case tipo.to_sym
    when :decisao then 'alta'
    when :votacao then 'media'
    when :distribuicao, :analise then 'media'
    when :triagem, :criacao then 'baixa'
    else 'baixa'
    end
  end

  def deve_ser_reenviado?
    return false if enviado?
    return false if tentativas >= MAX_TENTATIVAS

    # Reenviar se:
    # 1. Está pendente há mais de 30 minutos
    # 2. Falhou há mais de 1 hora (backoff exponencial)
    if pendente?
      tempo_desde_criacao > 0.5 # 30 minutos
    elsif falhado?
      tempo_desde_ultima_tentativa > backoff_time
    else
      false
    end
  end

  def gerar_link_acompanhamento
    # Link para o cidadão acompanhar o processo
    processo_codigo = processo.codigo_acompanhamento_formatado
    "#{Rails.application.routes.url_helpers.root_url}acompanhar/#{processo_codigo}"
  end

  def personalizar_conteudo
    # Personalizar conteúdo com dados do processo e cidadão
    conteudo_personalizado = conteudo.dup

    # Substituir placeholders
    conteudo_personalizado.gsub!('{{nome_cidadao}}', processo.cidadao.nome_completo)
    conteudo_personalizado.gsub!('{{codigo_processo}}', processo.codigo_acompanhamento_formatado)
    conteudo_personalizado.gsub!('{{tipo_infracao}}', processo.tipo_infracao.humanize)
    conteudo_personalizado.gsub!('{{link_acompanhamento}}', gerar_link_acompanhamento)

    if processo.data_limite
      conteudo_personalizado.gsub!('{{data_limite}}', I18n.l(processo.data_limite, format: :long))
      conteudo_personalizado.gsub!('{{dias_limite}}', processo.dias_para_vencimento.to_s)
    end

    conteudo_personalizado
  end

  # Métodos de classe
  def self.criar_para_processo!(processo, tipo_notificacao, destinatario = nil)
    destinatario_email = destinatario || processo.cidadao.email

    template = obter_template(tipo_notificacao)

    create!(
      processo: processo,
      destinatario_email: destinatario_email,
      tipo: tipo_notificacao,
      assunto: template[:assunto],
      conteudo: template[:conteudo],
      status_envio: 'pendente'
    )
  end

  def self.reenviar_falhadas!
    para_reenvio.find_each do |notificacao|
      next unless notificacao.deve_ser_reenviado?

      notificacao.reenviar!
    end
  end

  def self.limpar_antigas(dias = 90)
    # Remover notificações enviadas antigas para economizar espaço
    where('data_envio < ? AND status_envio = ?', dias.days.ago, 'enviado').delete_all
  end

  def self.obter_template(tipo_notificacao)
    templates = {
      criacao: {
        assunto: 'Processo {{codigo_processo}} - Recebido com sucesso',
        conteudo: 'Olá {{nome_cidadao}},\n\nSeu processo de defesa de trânsito foi recebido e está sendo processado.\n\nCódigo de acompanhamento: {{codigo_processo}}\nTipo de infração: {{tipo_infracao}}\n\nAcompanhe o andamento em: {{link_acompanhamento}}\n\nEquipe TrâmiteJá'
      },
      triagem: {
        assunto: 'Processo {{codigo_processo}} - Em análise inicial',
        conteudo: 'Olá {{nome_cidadao}},\n\nSeu processo está sendo analisado pela equipe técnica para verificação da documentação.\n\nCódigo: {{codigo_processo}}\n\nAcompanhe em: {{link_acompanhamento}}\n\nEquipe TrâmiteJá'
      },
      distribuicao: {
        assunto: 'Processo {{codigo_processo}} - Distribuído para análise',
        conteudo: 'Olá {{nome_cidadao}},\n\nSeu processo foi distribuído para um relator especializado.\n\nCódigo: {{codigo_processo}}\n\nAcompanhe em: {{link_acompanhamento}}\n\nEquipe TrâmiteJá'
      },
      analise: {
        assunto: 'Processo {{codigo_processo}} - Em análise jurídica',
        conteudo: 'Olá {{nome_cidadao}},\n\nSeu processo está sendo analisado juridicamente pelo relator especializado.\n\nCódigo: {{codigo_processo}}\n\nAcompanhe em: {{link_acompanhamento}}\n\nEquipe TrâmiteJá'
      },
      votacao: {
        assunto: 'Processo {{codigo_processo}} - Em votação',
        conteudo: 'Olá {{nome_cidadao}},\n\nSeu processo está em votação pelo colegiado de julgadores.\n\nCódigo: {{codigo_processo}}\n\nAcompanhe em: {{link_acompanhamento}}\n\nEquipe TrâmiteJá'
      },
      decisao: {
        assunto: 'Processo {{codigo_processo}} - Decisão final',
        conteudo: 'Olá {{nome_cidadao}},\n\nSeu processo foi finalizado. Consulte o resultado completo em nosso portal.\n\nCódigo: {{codigo_processo}}\n\nAcompanhe em: {{link_acompanhamento}}\n\nEquipe TrâmiteJá'
      }
    }

    templates[tipo_notificacao.to_sym] || templates[:criacao]
  end

  private

  def set_data_criacao
    self.data_criacao ||= Time.current
  end

  def set_tentativas_default
    self.tentativas ||= 0
  end

  def enviar_notificacao_async
    # Em produção, usar background job (Sidekiq, etc.)
    # NotificacaoMailerJob.perform_later(self)

    # Por enquanto, enviar sincrono para desenvolvimento
    enviar!
  end

  def simular_envio_email
    # Simulação de envio de email
    # 90% de chance de sucesso
    if rand < 0.9
      {
        sucesso: true,
        id_envio: SecureRandom.uuid
      }
    else
      {
        sucesso: false,
        erro: 'Falha temporária no servidor de email'
      }
    end
  end

  def atualizar_falha_envio(erro)
    if tentativas >= MAX_TENTATIVAS
      update!(status_envio: 'falhado')
      Rails.logger.error "Notificação #{id} falhou definitivamente após #{tentativas} tentativas: #{erro}"
    else
      Rails.logger.warn "Notificação #{id} falhou (tentativa #{tentativas}/#{MAX_TENTATIVAS}): #{erro}"
    end
  end

  def tempo_desde_ultima_tentativa
    # Implementar lógica de última tentativa baseada em logs ou timestamps
    # Por simplicidade, usar tempo desde criação
    tempo_desde_criacao
  end

  def backoff_time
    # Backoff exponencial: 1h, 2h, 4h
    2**(tentativas - 1)
  end
end
