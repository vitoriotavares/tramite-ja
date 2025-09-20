# Seeds para desenvolvimento do TrâmiteJá
# Cria dados de exemplo para desenvolvimento e testes

puts "🌱 Criando dados de exemplo para TrâmiteJá..."

# Limpeza (apenas em desenvolvimento)
if Rails.env.development?
  puts "🧹 Limpando dados existentes..."
  Notificacao.destroy_all
  Documento.destroy_all
  Voto.destroy_all
  Processo.destroy_all
  Julgador.destroy_all
  Relator.destroy_all
  Cidadao.destroy_all
end

# 1. Criar Relatores
puts "👨‍⚖️ Criando relatores..."

relators_data = [
  {
    nome: "Dr. Ana Paula Silva",
    registro_oab: "SP123456",
    email: "ana.silva@tramiteja.com.br",
    especializacoes: ["velocidade", "geral"],
    capacidade_maxima: 15,
    processos_ativos: 3,
    disponivel: true
  },
  {
    nome: "Dr. Carlos Eduardo Santos",
    registro_oab: "RJ234567",
    email: "carlos.santos@tramiteja.com.br",
    especializacoes: ["rodizio", "semaforo"],
    capacidade_maxima: 12,
    processos_ativos: 1,
    disponivel: true
  },
  {
    nome: "Dra. Marina Costa",
    registro_oab: "MG345678",
    email: "marina.costa@tramiteja.com.br",
    especializacoes: ["geral"],
    capacidade_maxima: 20,
    processos_ativos: 5,
    disponivel: false
  }
]

relatores = relators_data.map do |data|
  Relator.create!(data)
end

puts "✅ #{relatores.count} relatores criados"

# 2. Criar Julgadores
puts "👥 Criando julgadores..."

julgadores_data = [
  {
    nome: "Juiz Roberto Almeida",
    registro_profissional: "MAG001234",
    email: "roberto.almeida@tribunal.br",
    especializacoes: ["velocidade", "rodizio"],
    disponivel: true
  },
  {
    nome: "Juíza Patricia Fernandes",
    registro_profissional: "MAG002345",
    email: "patricia.fernandes@tribunal.br",
    especializacoes: ["semaforo", "geral"],
    disponivel: true
  },
  {
    nome: "Juiz Antonio Ribeiro",
    registro_profissional: "MAG003456",
    email: "antonio.ribeiro@tribunal.br",
    especializacoes: ["geral"],
    disponivel: true
  },
  {
    nome: "Juíza Claudia Moreira",
    registro_profissional: "MAG004567",
    email: "claudia.moreira@tribunal.br",
    especializacoes: ["velocidade", "semaforo"],
    disponivel: true
  },
  {
    nome: "Juiz Fernando Lima",
    registro_profissional: "MAG005678",
    email: "fernando.lima@tribunal.br",
    especializacoes: ["rodizio", "geral"],
    disponivel: true
  }
]

julgadores = julgadores_data.map do |data|
  Julgador.create!(data)
end

puts "✅ #{julgadores.count} julgadores criados"

# 3. Criar Cidadãos
puts "👤 Criando cidadãos..."

cidadaos_data = [
  {
    cpf: "12345678901",
    nome_completo: "João da Silva Santos",
    email: "joao.santos@email.com",
    telefone: "11987654321",
    endereco_completo: "Rua das Flores, 123 - São Paulo/SP",
    oauth_gov_id: "govbr_001"
  },
  {
    cpf: "23456789012",
    nome_completo: "Maria Oliveira Costa",
    email: "maria.costa@email.com",
    telefone: "21976543210",
    endereco_completo: "Av. Atlântica, 456 - Rio de Janeiro/RJ",
    oauth_gov_id: "govbr_002"
  },
  {
    cpf: "34567890123",
    nome_completo: "Pedro Henrique Lima",
    email: "pedro.lima@email.com",
    telefone: "11965432109",
    endereco_completo: "Rua dos Pinheiros, 789 - São Paulo/SP",
    oauth_gov_id: "govbr_003"
  },
  {
    cpf: "45678901234",
    nome_completo: "Ana Carolina Ferreira",
    email: "ana.ferreira@email.com",
    telefone: "31954321098",
    endereco_completo: "Rua Bahia, 321 - Belo Horizonte/MG",
    oauth_gov_id: "govbr_004"
  },
  {
    cpf: "56789012345",
    nome_completo: "Carlos Roberto Souza",
    email: "carlos.souza@email.com",
    telefone: "85943210987",
    endereco_completo: "Av. Beira Mar, 654 - Fortaleza/CE",
    oauth_gov_id: "govbr_005"
  }
]

cidadaos = cidadaos_data.map do |data|
  Cidadao.create!(data)
end

puts "✅ #{cidadaos.count} cidadãos criados"

# 4. Criar Processos em diferentes status
puts "📋 Criando processos..."

processos_criados = []

# Processo 1: Em triagem (velocidade)
processo1 = Processo.create!(
  tipo_infracao: :velocidade,
  status: :rascunho,
  cidadao: cidadaos[0]
)
processos_criados << processo1

# Processo 2: Distribuído para relator (rodizio)
processo2 = Processo.create!(
  tipo_infracao: :rodizio,
  status: :rascunho,
  cidadao: cidadaos[1]
)
processos_criados << processo2

# Processo 3: Em análise (semáforo)
processo3 = Processo.create!(
  tipo_infracao: :semaforo,
  status: :rascunho,
  cidadao: cidadaos[2]
)
processos_criados << processo3

# Processo 4: Em votação (velocidade)
processo4 = Processo.create!(
  tipo_infracao: :velocidade,
  status: :rascunho,
  cidadao: cidadaos[3]
)
processos_criados << processo4

# Processo 5: Decidido (deferido)
processo5 = Processo.create!(
  tipo_infracao: :rodizio,
  status: :rascunho,
  cidadao: cidadaos[4]
)
processos_criados << processo5

puts "✅ #{processos_criados.count} processos criados"

# 5. Criar Documentos para alguns processos
puts "📄 Criando documentos..."

documentos_criados = 0

processos_criados.each do |processo|
  # CNH (obrigatório para todos)
  Documento.create!(
    processo: processo,
    tipo: :cnh,
    nome_arquivo: "cnh_#{processo.cidadao.cpf}.pdf",
    url_armazenamento: "storage/documentos/cnh_#{processo.cidadao.cpf}.pdf",
    tamanho_bytes: rand(500000..2000000),
    tipo_mime: "application/pdf",
    status_validacao: :aprovado,
    data_upload: Time.current
  )
  documentos_criados += 1

  # CRLV (obrigatório para velocidade e rodízio)
  if [:velocidade, :rodizio].include?(processo.tipo_infracao.to_sym)
    Documento.create!(
      processo: processo,
      tipo: :crlv,
      nome_arquivo: "crlv_#{processo.cidadao.cpf}.pdf",
      url_armazenamento: "storage/documentos/crlv_#{processo.cidadao.cpf}.pdf",
      tamanho_bytes: rand(300000..1500000),
      tipo_mime: "application/pdf",
      status_validacao: :aprovado,
      data_upload: Time.current + 1.hour
    )
    documentos_criados += 1
  end

  # Documento de apoio (opcional)
  if rand < 0.7 # 70% dos processos têm documento adicional
    Documento.create!(
      processo: processo,
      tipo: :comprovante,
      nome_arquivo: "comprovante_#{processo.cidadao.cpf}.pdf",
      url_armazenamento: "storage/documentos/comprovante_#{processo.cidadao.cpf}.pdf",
      tamanho_bytes: rand(200000..1000000),
      tipo_mime: "application/pdf",
      status_validacao: :aprovado,
      data_upload: Time.current + 2.hours
    )
    documentos_criados += 1
  end
end

puts "✅ #{documentos_criados} documentos criados"

# 6. Atualizar status dos processos diretamente para seed
puts "⚡ Atualizando status dos processos..."

# Processo 1: Triagem
processo1.update_columns(status: 1) # triagem

# Processo 2: Distribuído - precisa de relator
relator_disponivel = relatores.find { |r| r.pode_receber_processo?(processo2.tipo_infracao) }
processo2.update_columns(status: 2, relator_id: relator_disponivel.id) # distribuido

# Processo 3: Em análise
relator_disponivel = relatores.find { |r| r.pode_receber_processo?(processo3.tipo_infracao) }
processo3.update_columns(
  status: 3, # em_analise
  relator_id: relator_disponivel.id,
  parecer_relator: "Após análise dos documentos e das alegações apresentadas, verifico que a defesa apresenta argumentos válidos sobre a sinalização inadequada no local da infração."
)

# Processo 4: Em votação
relator_disponivel = relatores.find { |r| r.pode_receber_processo?(processo4.tipo_infracao) }
processo4.update_columns(
  status: 4, # em_votacao
  relator_id: relator_disponivel.id,
  parecer_relator: "A defesa alega problemas na calibração do radar. Documentos técnicos apresentados sustentam a alegação de defeito no equipamento."
)

# Processo 5: Em votação (será decidido depois dos votos)
relator_disponivel = relatores.find { |r| r.pode_receber_processo?(processo5.tipo_infracao) }
processo5.update_columns(
  status: 4, # em_votacao
  relator_id: relator_disponivel.id,
  parecer_relator: "Defesa procedente. Cidadão comprovou estar em situação de emergência médica no momento da infração."
)

puts "✅ Status dos processos atualizados"

# 7. Criar Votos para processo em votação
puts "🗳️ Criando votos..."

# Processo4 é velocidade - usar julgadores com especialização em velocidade
# Voto 1: Concordo
  Voto.create!(
    processo: processo4,
    julgador: julgadores[0],
    decisao: :concordo,
    justificativa: "Concordo com o parecer do relator. Os documentos técnicos apresentados demonstram falha no equipamento de medição.",
    data_voto: 1.hour.ago,
    tempo_analise: 1800 # 30 minutos
  )

# Voto 2: Concordo
Voto.create!(
  processo: processo4,
  julgador: julgadores[3], # Claudia Moreira - velocidade, semaforo
    decisao: :concordo,
    justificativa: "Defesa bem fundamentada. Evidências técnicas sustentam a alegação de defeito no radar.",
    data_voto: 2.hours.ago,
    tempo_analise: 2100 # 35 minutos
  )

  # Voto 3: Discordo
  Voto.create!(
    processo: processo4,
    julgador: julgadores[2],
    decisao: :discordo,
    justificativa: "Apesar das alegações, não há prova conclusiva de que o equipamento estava defeituoso no momento específico da infração.",
    data_voto: 3.hours.ago,
    tempo_analise: 2700 # 45 minutos
  )

puts "✅ 3 votos criados para processo em votação"

# 7. Criar Votos para processo5 (rodizio) que será decidido
# Criar votos que levarão à decisão
  Voto.create!(
    processo: processo5,
    julgador: julgadores[0],
    decisao: :concordo,
    justificativa: "Situação de emergência médica devidamente comprovada. Defesa procedente.",
    data_voto: 4.hours.ago,
    tempo_analise: 1500
  )

Voto.create!(
  processo: processo5,
  julgador: julgadores[4], # Fernando Lima - rodizio, geral
    decisao: :concordo,
    justificativa: "Documentos médicos são conclusivos. Estado de necessidade configurado.",
    data_voto: 5.hours.ago,
    tempo_analise: 1800
  )

Voto.create!(
  processo: processo5,
  julgador: julgadores[2], # Antonio Ribeiro - geral
    decisao: :concordo,
    justificativa: "Concordo com os demais. Situação excepcional justifica o descumprimento da norma.",
    data_voto: 6.hours.ago,
    tempo_analise: 1200
  )

puts "✅ 3 votos criados para processo que será decidido automaticamente"

# 8. Criar algumas notificações
puts "📧 Criando notificações..."

notificacoes_criadas = 0

processos_criados.each do |processo|
  # Notificação de criação
  Notificacao.create!(
    processo: processo,
    destinatario_email: processo.cidadao.email,
    tipo: :criacao,
    assunto: "Processo #{processo.codigo_acompanhamento_formatado} - Recebido",
    conteudo: "Seu processo de defesa de trânsito foi recebido com sucesso e está sendo processado.",
    status_envio: :enviado,
    data_criacao: Time.current,
    data_envio: Time.current + 5.minutes,
    tentativas: 1
  )
  notificacoes_criadas += 1

  # Notificação adicional para processos mais avançados
  unless processo.rascunho? || processo.triagem?
    Notificacao.create!(
      processo: processo,
      destinatario_email: processo.cidadao.email,
      tipo: :analise,
      assunto: "Processo #{processo.codigo_acompanhamento_formatado} - Atualização",
      conteudo: "Seu processo foi atualizado. Status atual: #{processo.status.humanize}",
      status_envio: :enviado,
      data_criacao: Time.current + 1.hour,
      data_envio: Time.current + 1.hour + 5.minutes,
      tentativas: 1
    )
    notificacoes_criadas += 1
  end
end

puts "✅ #{notificacoes_criadas} notificações criadas"

# 9. Atualizar métricas dos relatores
puts "📊 Atualizando métricas dos relatores..."

relatores.each do |relator|
  # Simular algumas métricas de performance
  relator.update!(
    metricas_performance: {
      tempo_medio_analise: rand(24..72).to_f,
      total_processos: rand(50..200),
      decisoes_favoraveis: rand(20..80),
      taxa_deferimento: rand(30..70).round(2)
    }
  )
end

puts "✅ Métricas atualizadas para #{relatores.count} relatores"

# 10. Resumo final
puts "\n🎉 Dados de exemplo criados com sucesso!"
puts "=" * 50

total_counts = {
  'Cidadãos': Cidadao.count,
  'Relatores': Relator.count,
  'Julgadores': Julgador.count,
  'Processos': Processo.count,
  'Documentos': Documento.count,
  'Votos': Voto.count,
  'Notificações': Notificacao.count
}

total_counts.each do |model, count|
  puts "#{model}: #{count}"
end

puts "=" * 50
puts "🚀 TrâmiteJá pronto para desenvolvimento!"
puts "💡 Use 'rails console' para explorar os dados"
puts "🌐 Inicie o servidor com 'rails server'"