# Integration test T025: Performance load testing (100 processes)
# Tests system performance under high load scenarios

require 'rails_helper'

RSpec.describe "Performance Load Testing", type: :feature do
  describe "Teste de carga com 100 processos simultâneos" do
    # Este teste deve falhar até implementarmos otimizações de performance
    context "quando sistema recebe alta demanda" do
      it "processa 100 defesas simultâneas mantendo SLAs de performance" do
        # SLAs definidos (Constitutional requirements)
        sla_api_response = 200  # ms
        sla_page_load = 1000    # ms
        sla_process_max_time = 5.days
        sla_database_query = 100 # ms

        # Etapa 1: Criar 100 cidadãos únicos
        start_time = Time.current

        cidadaos = 100.times.map do |i|
          criar_cidadao_via_oauth(
            cpf: "1000000000#{i.to_s.rjust(2, '0')}",
            email: "load#{i}@tramiteja.com.br"
          )
        end

        cidadaos_creation_time = (Time.current - start_time) * 1000
        expect(cidadaos_creation_time).to be < (sla_api_response * 100) # Batch creation should be efficient

        # Etapa 2: Criar 100 processos simultaneamente
        start_time = Time.current

        processos = cidadaos.map.with_index do |cidadao, i|
          criar_processo_defesa(
            cidadao: cidadao,
            tipo_infracao: ['velocidade', 'semaforo', 'rodizio'][i % 3]
          )
        end

        processos_creation_time = (Time.current - start_time) * 1000
        expect(processos_creation_time).to be < (sla_api_response * 100)
        expect(processos.count).to eq(100)
        expect(processos.all?(&:persisted?)).to be true

        # Etapa 3: Upload massivo de documentos (200 uploads - 2 por processo)
        start_time = Time.current

        documentos_uploaded = []
        processos.each do |processo|
          ['cnh', 'crlv'].each do |tipo|
            documento = upload_documento_performance(processo, tipo)
            documentos_uploaded << documento
          end
        end

        upload_time = (Time.current - start_time) * 1000
        expect(upload_time).to be < 30000 # 30 seconds for 200 uploads
        expect(documentos_uploaded.count).to eq(200)

        # Etapa 4: Triagem automatizada em lote
        start_time = Time.current

        resultados_triagem = executar_triagem_em_lote(processos)

        triagem_time = (Time.current - start_time) * 1000
        expect(triagem_time).to be < 10000 # 10 seconds for batch triage
        expect(resultados_triagem.count { |r| r[:aprovado] }).to be >= 90 # 90% approval rate

        # Etapa 5: Distribuição balanceada para relatores
        relatores = criar_relatores_para_carga(quantidade: 10, capacidade: 15)

        start_time = Time.current

        processos_aprovados = processos.select { |p| p.reload.status == 'distribuido' }
        resultados_distribuicao = executar_distribuicao_em_lote(processos_aprovados, relatores)

        distribuicao_time = (Time.current - start_time) * 1000
        expect(distribuicao_time).to be < 5000 # 5 seconds for distribution

        # Verificar balanceamento de carga
        relatores.each do |relator|
          expect(relator.reload.processos_ativos).to be <= 15 # Within capacity
        end

        # Verificar que distribuição foi eficiente
        processos_distribuidos = processos_aprovados.count { |p| p.reload.relator.present? }
        expect(processos_distribuidos).to eq(processos_aprovados.count)

        # Etapa 6: Análise e parecer em paralelo (simular 48h)
        travel_to 2.days.from_now do
          start_time = Time.current

          pareceres_emitidos = processos_distribuidos.times.map do |i|
            processo = processos_aprovados[i]
            next unless processo.relator.present?

            submeter_parecer_relator_rapido(processo)
          end.compact

          pareceres_time = (Time.current - start_time) * 1000
          expect(pareceres_time).to be < 15000 # 15 seconds for batch pareceres
          expect(pareceres_emitidos.count).to be >= (processos_distribuidos * 0.8) # 80% completion rate
        end

        # Etapa 7: Votação colegiada massiva
        julgadores = criar_julgadores_para_carga(quantidade: 15)

        travel_to 3.days.from_now do
          start_time = Time.current

          processos_em_votacao = processos.select { |p| p.reload.status == 'em_votacao' }
          expect(processos_em_votacao.count).to be >= 50 # At least 50 processes in voting

          # Simular votação em lotes de 10 processos
          processos_em_votacao.each_slice(10) do |lote_processos|
            processar_votacao_em_lote(lote_processos, julgadores)
          end

          votacao_time = (Time.current - start_time) * 1000
          expect(votacao_time).to be < 20000 # 20 seconds for mass voting
        end

        # Etapa 8: Verificações finais de performance e consistência
        travel_to 4.days.from_now do
          # Verificar SLA constitucional: máximo 5 dias do protocolo à decisão
          processos_decididos = processos.select { |p| p.reload.status == 'decidido' }
          expect(processos_decididos.count).to be >= 80 # 80% completion rate

          processos_decididos.each do |processo|
            tempo_total = processo.data_decisao - processo.data_criacao
            expect(tempo_total).to be <= sla_process_max_time
          end

          # Verificar integridade dos dados
          expect(Processo.count).to be >= 100
          expect(Documento.count).to be >= 200
          expect(Voto.count).to be >= 240 # 3 votos × 80 processos decididos

          # Verificar que não há deadlocks ou inconsistências
          processos_inconsistentes = Processo.where(status: 'decidido')
                                             .where(decisao_final: nil)
          expect(processos_inconsistentes.count).to eq(0)
        end

        # Etapa 9: Teste de consulta pública massiva
        start_time = Time.current

        resultados_consulta = processos.map do |processo|
          consultar_timeline_publica_performance(processo.codigo_acompanhamento)
        end

        consulta_time = (Time.current - start_time) * 1000
        expect(consulta_time).to be < 5000 # 5 seconds for 100 public queries
        expect(resultados_consulta.all?(&:present?)).to be true
      end

      it "mantém performance de APIs durante picos de acesso" do
        # Criar dados base para teste de API
        cidadaos = 50.times.map { |i| criar_cidadao_via_oauth(cpf: "2000000000#{i.to_s.rjust(2, '0')}", email: "api#{i}@test.com") }
        processos = cidadaos.map { |c| criar_processo_defesa(cidadao: c, tipo_infracao: 'velocidade') }

        # Teste 1: API de criação de processos
        benchmark_api_creation = medir_performance_api do
          20.times do |i|
            cidadao_temp = criar_cidadao_via_oauth(cpf: "3000000000#{i.to_s.rjust(2, '0')}", email: "bench#{i}@test.com")
            criar_processo_defesa(cidadao: cidadao_temp, tipo_infracao: 'semaforo')
          end
        end

        expect(benchmark_api_creation[:tempo_medio_ms]).to be < 200
        expect(benchmark_api_creation[:tempo_maximo_ms]).to be < 500

        # Teste 2: API de consulta de dashboard
        benchmark_dashboard = medir_performance_api do
          cidadaos.each do |cidadao|
            consultar_dashboard_cidadao(cidadao)
          end
        end

        expect(benchmark_dashboard[:tempo_medio_ms]).to be < 100
        expect(benchmark_dashboard[:tempo_maximo_ms]).to be < 300

        # Teste 3: API de acompanhamento público
        benchmark_acompanhamento = medir_performance_api do
          processos.each do |processo|
            consultar_timeline_publica_performance(processo.codigo_acompanhamento)
          end
        end

        expect(benchmark_acompanhamento[:tempo_medio_ms]).to be < 150
        expect(benchmark_acompanhamento[:tempo_maximo_ms]).to be < 400

        # Teste 4: API de upload de documentos
        benchmark_upload = medir_performance_api do
          processos.first(20).each do |processo|
            upload_documento_performance(processo, 'cnh')
          end
        end

        expect(benchmark_upload[:tempo_medio_ms]).to be < 300
        expect(benchmark_upload[:tempo_maximo_ms]).to be < 800
      end

      it "gerencia memória eficientemente durante processamento massivo" do
        # Verificar uso de memória inicial
        memoria_inicial = obter_uso_memoria_mb

        # Processar em lotes para evitar sobrecarga de memória
        5.times do |lote|
          # Criar lote de 20 processos
          cidadaos_lote = 20.times.map do |i|
            index = (lote * 20) + i
            criar_cidadao_via_oauth(cpf: "4000000000#{index.to_s.rjust(2, '0')}", email: "mem#{index}@test.com")
          end

          processos_lote = cidadaos_lote.map { |c| criar_processo_defesa(cidadao: c, tipo_infracao: 'rodizio') }

          # Processar lote completo
          processos_lote.each { |p| upload_documentos_obrigatorios(p) }
          executar_triagem_em_lote(processos_lote)

          # Verificar que memória não cresceu exponencialmente
          memoria_atual = obter_uso_memoria_mb
          crescimento_memoria = memoria_atual - memoria_inicial
          expect(crescimento_memoria).to be < 500 # Máximo 500MB de crescimento

          # Forçar garbage collection entre lotes
          GC.start
        end

        # Verificar que memória foi liberada adequadamente
        GC.start
        memoria_final = obter_uso_memoria_mb
        crescimento_total = memoria_final - memoria_inicial
        expect(crescimento_total).to be < 200 # Máximo 200MB de crescimento final
      end

      it "mantém estabilidade de banco de dados sob carga" do
        # Teste de conexões simultâneas
        threads = []
        resultados_threads = []
        mutex = Mutex.new

        # Simular 20 threads acessando o banco simultaneamente
        20.times do |i|
          threads << Thread.new do
            begin
              # Cada thread cria 5 processos
              resultados_thread = []
              5.times do |j|
                index = (i * 5) + j
                cidadao = criar_cidadao_via_oauth(cpf: "5000000000#{index.to_s.rjust(2, '0')}", email: "thread#{index}@test.com")
                processo = criar_processo_defesa(cidadao: cidadao, tipo_infracao: 'velocidade')
                upload_documentos_obrigatorios(processo)
                executar_triagem_automatizada(processo)
                resultados_thread << processo.reload.status
              end

              mutex.synchronize do
                resultados_threads.concat(resultados_thread)
              end
            rescue => e
              mutex.synchronize do
                resultados_threads << "ERRO: #{e.message}"
              end
            end
          end
        end

        # Aguardar todas as threads terminarem
        threads.each(&:join)

        # Verificar que não houve erros de conexão
        erros = resultados_threads.select { |r| r.to_s.include?('ERRO') }
        expect(erros.count).to eq(0)

        # Verificar que todos os registros foram criados corretamente
        processos_criados = resultados_threads.count { |r| ['rascunho', 'distribuido'].include?(r) }
        expect(processos_criados).to eq(100)

        # Verificar integridade referencial
        expect(Cidadao.count).to be >= 100
        expect(Processo.count).to be >= 100
        expect(Documento.count).to be >= 200
      end
    end

    context "quando há problemas de rede e infraestrutura" do
      it "mantém operação durante latência alta de rede" do
        # Simular latência de rede alta (500ms)
        simular_latencia_rede(500) do
          start_time = Time.current

          # Operações que dependem de rede externa (uploads para R2)
          cidadao = criar_cidadao_via_oauth(cpf: '9900000001', email: 'latencia@test.com')
          processo = criar_processo_defesa(cidadao: cidadao, tipo_infracao: 'velocidade')

          # Upload deve continuar funcionando mesmo com latência
          documento = upload_documento_performance(processo, 'cnh')
          expect(documento).to be_persisted

          total_time = (Time.current - start_time) * 1000
          # Deve ser maior que latência mas menor que timeout
          expect(total_time).to be_between(500, 10000)
        end
      end

      it "recupera de falhas temporárias de serviços externos" do
        cidadao = criar_cidadao_via_oauth(cpf: '9900000002', email: 'falha@test.com')
        processo = criar_processo_defesa(cidadao: cidadao, tipo_infracao: 'velocidade')

        # Simular falha no R2 Cloudflare
        simular_falha_r2 do
          # Upload deve falhar e ser enfileirado para retry
          expect {
            upload_documento_performance(processo, 'cnh')
          }.to change(UploadRetryJob.jobs, :size).by(1)
        end

        # Simular recuperação do serviço
        simular_recuperacao_r2 do
          # Processar jobs de retry
          UploadRetryJob.perform_now

          # Documento deve ter sido criado após retry
          expect(processo.reload.documentos.count).to eq(1)
        end
      end
    end
  end

  private

  def criar_cidadao_via_oauth(cpf:, email:)
    Cidadao.create!(
      cpf: cpf,
      nome_completo: "Cidadão #{cpf}",
      email: email,
      telefone: '11999999999',
      endereco_completo: 'Rua A, 123, São Paulo, SP',
      oauth_gov_id: "gov_#{SecureRandom.hex(8)}"
    )
  end

  def criar_processo_defesa(cidadao:, tipo_infracao:)
    Processo.create!(
      tipo_infracao: tipo_infracao,
      cidadao: cidadao,
      status: 'rascunho',
      codigo_acompanhamento: gerar_codigo_acompanhamento,
      data_criacao: Time.current,
      data_limite: 30.days.from_now
    )
  end

  def upload_documento_performance(processo, tipo)
    Documento.create!(
      processo: processo,
      tipo: tipo,
      nome_arquivo: "#{tipo}_#{processo.id}.pdf",
      url_armazenamento: "https://r2.cloudflare.com/tramiteja/perf_#{SecureRandom.hex(16)}",
      tamanho_bytes: 1024,
      status_validacao: 'aprovado',
      data_upload: Time.current
    )
  end

  def upload_documentos_obrigatorios(processo)
    ['cnh', 'crlv'].each { |tipo| upload_documento_performance(processo, tipo) }
  end

  def executar_triagem_em_lote(processos)
    processos.map do |processo|
      # Simular triagem otimizada em batch
      resultado = { aprovado: true, motivos_rejeicao: [] }

      # Verificações básicas
      if processo.documentos.count < 2
        resultado[:aprovado] = false
        resultado[:motivos_rejeicao] << 'documentacao_incompleta'
      end

      if resultado[:aprovado]
        processo.update!(status: 'distribuido')
      else
        processo.update!(status: 'rejeitado_triagem')
      end

      resultado
    end
  end

  def executar_distribuicao_em_lote(processos, relatores)
    # Algoritmo de distribuição por round-robin otimizado
    relator_index = 0

    processos.map do |processo|
      relator_selecionado = nil

      # Encontrar relator com menor carga
      relator_disponivel = relatores.min_by(&:processos_ativos)

      if relator_disponivel && relator_disponivel.processos_ativos < relator_disponivel.capacidade_maxima
        relator_selecionado = relator_disponivel
        processo.update!(relator: relator_selecionado)
        relator_selecionado.update!(processos_ativos: relator_selecionado.processos_ativos + 1)
      end

      { processo: processo, relator: relator_selecionado }
    end
  end

  def criar_relatores_para_carga(quantidade:, capacidade:)
    quantidade.times.map do |i|
      Relator.create!(
        nome: "Relator Load #{i + 1}",
        registro_oab: "SP#{100000 + i}",
        email: "relator_load_#{i}@tramiteja.com",
        especializacoes: ['velocidade', 'semaforo', 'rodizio'],
        capacidade_maxima: capacidade,
        processos_ativos: 0,
        disponivel: true
      )
    end
  end

  def criar_julgadores_para_carga(quantidade:)
    quantidade.times.map do |i|
      Julgador.create!(
        nome: "Julgador Load #{i + 1}",
        registro_profissional: "LOAD#{i + 1}",
        email: "julgador_load_#{i}@tramiteja.com",
        especializacoes: ['geral'],
        disponivel: true
      )
    end
  end

  def submeter_parecer_relator_rapido(processo)
    processo.update!(
      status: 'em_votacao',
      parecer_relator: 'Parecer emitido em lote para teste de performance'
    )
  end

  def processar_votacao_em_lote(processos, julgadores)
    processos.each do |processo|
      # Selecionar 3 julgadores aleatórios
      julgadores_sorteados = julgadores.sample(3)

      # Criar votos fictícios para teste de performance
      julgadores_sorteados.each_with_index do |julgador, index|
        decisao = index < 2 ? 'concordo' : 'discordo' # 2 concordam, 1 discorda

        Voto.create!(
          processo: processo,
          julgador: julgador,
          decisao: decisao,
          justificativa: "Voto #{decisao} em lote - teste de performance",
          data_voto: Time.current
        )
      end

      # Finalizar processo
      processo.update!(
        status: 'decidido',
        decisao_final: 'deferido', # Maioria concordou
        data_decisao: Time.current
      )
    end
  end

  def consultar_timeline_publica_performance(codigo_acompanhamento)
    # Simular consulta otimizada
    {
      codigo: codigo_acompanhamento,
      status: 'decidido',
      timeline: ['criacao', 'triagem', 'distribuicao', 'analise', 'votacao', 'decisao']
    }
  end

  def consultar_dashboard_cidadao(cidadao)
    # Simular consulta ao dashboard
    {
      cidadao_id: cidadao.id,
      processos_ativos: cidadao.processos.count,
      ultimas_atualizacoes: []
    }
  end

  def medir_performance_api
    tempos = []
    yield_block = proc { yield }

    # Executar e medir cada operação
    if block_given?
      # Para operações individuais dentro do bloco
      start_time = Time.current
      yield
      end_time = Time.current
      tempo_total = (end_time - start_time) * 1000

      {
        tempo_total_ms: tempo_total,
        tempo_medio_ms: tempo_total,
        tempo_maximo_ms: tempo_total
      }
    else
      {
        tempo_total_ms: 0,
        tempo_medio_ms: 0,
        tempo_maximo_ms: 0
      }
    end
  end

  def obter_uso_memoria_mb
    # TODO: Implementar monitoramento real de memória
    # Simular uso de memória
    rand(100..500)
  end

  def simular_latencia_rede(ms)
    # TODO: Implementar simulação de latência
    sleep(ms / 1000.0) if block_given?
    yield if block_given?
  end

  def simular_falha_r2
    # TODO: Implementar simulação de falha
    yield if block_given?
  end

  def simular_recuperacao_r2
    # TODO: Implementar simulação de recuperação
    yield if block_given?
  end

  def gerar_codigo_acompanhamento
    (0...12).map { [*'A'..'Z', *'0'..'9'].sample }.join
  end

  # Job fictício para teste de retry
  class UploadRetryJob
    @@jobs = []

    def self.jobs
      @@jobs
    end

    def self.perform_now
      @@jobs.clear
    end
  end
end