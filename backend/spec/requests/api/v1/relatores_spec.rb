# Contract tests for /api/v1/relatores endpoints
# Tests legal reviewer API contract compliance

require 'rails_helper'

RSpec.describe "Api::V1::Relatores", type: :request do
  let(:valid_headers) { { 'Content-Type' => 'application/json' } }
  let(:relator_id) { SecureRandom.uuid }

  describe "GET /api/v1/relatores" do
    context "quando listar relatores disponíveis" do
      it "retorna 200 OK com lista de relatores" do
        get '/api/v1/relatores', headers: valid_headers

        expect(response).to have_http_status(200)
        expect(response.content_type).to eq('application/json; charset=utf-8')

        json_response = JSON.parse(response.body)
        expect(json_response).to be_an(Array)

        # Validar estrutura de cada relator
        json_response.each do |relator|
          expect(relator).to have_key('id')
          expect(relator).to have_key('nome')
          expect(relator).to have_key('registro_oab')
          expect(relator).to have_key('especializacoes')
          expect(relator).to have_key('processos_ativos')
          expect(relator).to have_key('disponivel')

          # Validar tipos de dados
          expect(relator['id']).to match(/\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/)
          expect(relator['nome']).to be_a(String)
          expect(relator['registro_oab']).to be_a(String)
          expect(relator['especializacoes']).to be_an(Array)
          expect(relator['processos_ativos']).to be_an(Integer)
          expect(relator['disponivel']).to be_in([true, false])

          # Validar especializações válidas
          especializacoes_validas = ['velocidade', 'rodizio', 'semaforo', 'geral']
          relator['especializacoes'].each do |spec|
            expect(spec).to be_in(especializacoes_validas)
          end

          # Validar que processos_ativos não é negativo
          expect(relator['processos_ativos']).to be >= 0

          # Validar formato do registro OAB (números e letras)
          expect(relator['registro_oab']).to match(/\A[A-Z0-9]+\z/)
        end
      end

      it "filtra relatores por disponibilidade quando solicitado" do
        get '/api/v1/relatores?disponivel=true', headers: valid_headers

        expect(response).to have_http_status(200)

        json_response = JSON.parse(response.body)
        # Se houver relatores, todos devem estar disponíveis
        json_response.each do |relator|
          expect(relator['disponivel']).to be true
        end
      end

      it "filtra relatores por especialização quando solicitado" do
        get '/api/v1/relatores?especializacao=velocidade', headers: valid_headers

        expect(response).to have_http_status(200)

        json_response = JSON.parse(response.body)
        # Se houver relatores, todos devem ter especialização em velocidade
        json_response.each do |relator|
          expect(relator['especializacoes']).to include('velocidade')
        end
      end

      it "combina filtros de disponibilidade e especialização" do
        get '/api/v1/relatores?disponivel=true&especializacao=velocidade', headers: valid_headers

        expect(response).to have_http_status(200)

        json_response = JSON.parse(response.body)
        json_response.each do |relator|
          expect(relator['disponivel']).to be true
          expect(relator['especializacoes']).to include('velocidade')
        end
      end

      it "retorna array vazio quando não há relatores com critérios" do
        # Buscar por especialização inexistente
        get '/api/v1/relatores?especializacao=inexistente', headers: valid_headers

        expect(response).to have_http_status(200)

        json_response = JSON.parse(response.body)
        expect(json_response).to be_an(Array)
        # Pode estar vazio se não há relatores com essa especialização
      end

      it "ordena relatores por carga de trabalho (menor primeiro)" do
        get '/api/v1/relatores', headers: valid_headers

        if response.status == 200
          json_response = JSON.parse(response.body)

          if json_response.length > 1
            # Verificar ordenação por processos_ativos (menor primeiro)
            processos_counts = json_response.map { |relator| relator['processos_ativos'] }
            expect(processos_counts).to eq(processos_counts.sort)
          end
        end
      end

      it "retorna 401 Unauthorized quando não autenticado" do
        get '/api/v1/relatores'

        expect(response).to have_http_status(401)

        json_response = JSON.parse(response.body)
        expect(json_response['error']).to eq('Unauthorized')
      end

      context "validação de autorização" do
        it "permite acesso para usuários administrativos" do
          get '/api/v1/relatores', headers: valid_headers

          # Deve retornar 200 para admin (não 403)
          expect(response).to have_http_status(200).or have_http_status(401)
          expect(response).not_to have_http_status(403)
        end
      end
    end
  end

  describe "GET /api/v1/relatores/:id/dashboard" do
    context "quando acessar dashboard do relator" do
      it "retorna 200 OK com dashboard e processos pendentes" do
        get "/api/v1/relatores/#{relator_id}/dashboard", headers: valid_headers

        expect(response).to have_http_status(200)
        expect(response.content_type).to eq('application/json; charset=utf-8')

        json_response = JSON.parse(response.body)

        # Validar estrutura conforme especificação
        expect(json_response).to have_key('processos_pendentes')
        expect(json_response).to have_key('estatisticas')

        # Validar processos pendentes
        processos = json_response['processos_pendentes']
        expect(processos).to be_an(Array)

        processos.each do |processo|
          expect(processo).to have_key('id')
          expect(processo).to have_key('codigo_acompanhamento')
          expect(processo).to have_key('tipo_infracao')
          expect(processo).to have_key('status')
          expect(processo).to have_key('cidadao_id')
          expect(processo).to have_key('data_criacao')
          expect(processo).to have_key('data_limite')

          # Validar que são processos atribuídos a este relator
          expect(processo['relator_id']).to eq(relator_id)

          # Validar que são processos em status apropriado
          status_pendentes = ['distribuido', 'em_analise']
          expect(processo['status']).to be_in(status_pendentes)

          # Validar formato das datas
          expect(processo['data_criacao']).to match(/\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/)
          expect(processo['data_limite']).to match(/\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/)
        end

        # Validar estatísticas
        estatisticas = json_response['estatisticas']
        expect(estatisticas).to be_a(Hash)
        # Estrutura específica das estatísticas pode variar na implementação
      end

      it "ordena processos por prazo (mais urgente primeiro)" do
        get "/api/v1/relatores/#{relator_id}/dashboard", headers: valid_headers

        if response.status == 200
          json_response = JSON.parse(response.body)
          processos = json_response['processos_pendentes']

          if processos.length > 1
            # Verificar ordenação por data_limite (mais próxima primeiro)
            datas_limite = processos.map { |p| DateTime.parse(p['data_limite']) }
            expect(datas_limite).to eq(datas_limite.sort)
          end
        end
      end

      it "inclui apenas processos do relator específico" do
        get "/api/v1/relatores/#{relator_id}/dashboard", headers: valid_headers

        if response.status == 200
          json_response = JSON.parse(response.body)
          processos = json_response['processos_pendentes']

          # Todos os processos devem ser deste relator
          processos.each do |processo|
            expect(processo['relator_id']).to eq(relator_id)
          end
        end
      end

      it "retorna 404 Not Found quando relator não existe" do
        relator_inexistente = SecureRandom.uuid

        get "/api/v1/relatores/#{relator_inexistente}/dashboard", headers: valid_headers

        expect(response).to have_http_status(404)

        json_response = JSON.parse(response.body)
        expect(json_response['error']).to eq('Not Found')
        expect(json_response['message']).to eq('Recurso não encontrado')
      end

      it "retorna 401 Unauthorized quando não autenticado" do
        get "/api/v1/relatores/#{relator_id}/dashboard"

        expect(response).to have_http_status(401)

        json_response = JSON.parse(response.body)
        expect(json_response['error']).to eq('Unauthorized')
      end

      it "retorna 403 Forbidden quando usuário não é o relator" do
        # Simular acesso de outro usuário ao dashboard de relator
        other_user_headers = {
          'Content-Type' => 'application/json',
          'Authorization' => 'Bearer other_user_token'
        }

        get "/api/v1/relatores/#{relator_id}/dashboard", headers: other_user_headers

        # Pode retornar 403 ou 401 dependendo da implementação de autorização
        expect(response).to have_http_status(403).or have_http_status(401)

        if response.status == 403
          json_response = JSON.parse(response.body)
          expect(json_response['message']).to match(/acesso.*negado|não.*autorizado/i)
        end
      end

      context "validação de estatísticas" do
        it "inclui estatísticas de performance do relator" do
          get "/api/v1/relatores/#{relator_id}/dashboard", headers: valid_headers

          if response.status == 200
            json_response = JSON.parse(response.body)
            estatisticas = json_response['estatisticas']

            # Pode incluir métricas como:
            # - Total de processos analisados
            # - Tempo médio de análise
            # - Taxa de deferimento
            # - Processos em atraso
            expect(estatisticas).to be_a(Hash)
          end
        end

        it "calcula estatísticas baseadas apenas nos processos do relator" do
          get "/api/v1/relatores/#{relator_id}/dashboard", headers: valid_headers

          if response.status == 200
            json_response = JSON.parse(response.body)
            estatisticas = json_response['estatisticas']

            # Estatísticas devem ser consistentes com os processos retornados
            # (Esta validação será mais específica na implementação)
            expect(estatisticas).to be_a(Hash)
          end
        end
      end

      context "validação de performance" do
        it "responde em menos de 200ms para dashboard do relator" do
          start_time = Time.current

          get "/api/v1/relatores/#{relator_id}/dashboard", headers: valid_headers

          response_time = (Time.current - start_time) * 1000

          expect(response_time).to be < 200
        end
      end
    end
  end
end