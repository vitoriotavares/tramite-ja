# Contract tests for /api/v1/processos endpoints
# Tests API contract compliance per OpenAPI specification

require 'rails_helper'

RSpec.describe "Api::V1::Processos", type: :request do
  let(:valid_headers) { { 'Content-Type' => 'application/json' } }

  describe "POST /api/v1/processos" do
    let(:valid_attributes) do
      {
        tipo_infracao: 'velocidade',
        cidadao_id: SecureRandom.uuid
      }
    end

    context "quando criar novo processo de defesa (gratuito)" do
      it "retorna 201 Created com processo criado" do
        post '/api/v1/processos',
             params: valid_attributes.to_json,
             headers: valid_headers

        expect(response).to have_http_status(201)
        expect(response.content_type).to eq('application/json; charset=utf-8')

        json_response = JSON.parse(response.body)
        expect(json_response).to have_key('id')
        expect(json_response).to have_key('codigo_acompanhamento')
        expect(json_response['tipo_infracao']).to eq('velocidade')
        expect(json_response['status']).to eq('rascunho')
        expect(json_response['cidadao_id']).to eq(valid_attributes[:cidadao_id])
        expect(json_response).to have_key('data_criacao')
        expect(json_response).to have_key('data_limite')

        # Validar formato UUID para campos obrigatórios
        expect(json_response['id']).to match(/\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/)

        # Validar formato do código de acompanhamento (12 caracteres alfanuméricos)
        expect(json_response['codigo_acompanhamento']).to match(/\A[A-Z0-9]{12}\z/)
      end

      it "retorna 400 Bad Request quando tipo_infracao é inválido" do
        invalid_attributes = valid_attributes.merge(tipo_infracao: 'invalido')

        post '/api/v1/processos',
             params: invalid_attributes.to_json,
             headers: valid_headers

        expect(response).to have_http_status(400)

        json_response = JSON.parse(response.body)
        expect(json_response).to have_key('error')
        expect(json_response).to have_key('message')
        expect(json_response).to have_key('details')
      end

      it "retorna 400 Bad Request quando cidadao_id está ausente" do
        invalid_attributes = valid_attributes.except(:cidadao_id)

        post '/api/v1/processos',
             params: invalid_attributes.to_json,
             headers: valid_headers

        expect(response).to have_http_status(400)

        json_response = JSON.parse(response.body)
        expect(json_response).to have_key('error')
        expect(json_response).to have_key('message')
        expect(json_response['details']).to include(match(/cidadao_id.*obrigatório/i))
      end

      it "retorna 401 Unauthorized quando token de autenticação é inválido" do
        invalid_headers = { 'Content-Type' => 'application/json', 'Authorization' => 'Bearer invalid_token' }

        post '/api/v1/processos',
             params: valid_attributes.to_json,
             headers: invalid_headers

        expect(response).to have_http_status(401)

        json_response = JSON.parse(response.body)
        expect(json_response['error']).to eq('Unauthorized')
        expect(json_response['message']).to match(/token.*inválido.*expirado/i)
      end
    end
  end

  describe "GET /api/v1/processos" do
    context "quando listar processos para dashboards" do
      it "retorna 200 OK com lista paginada de processos" do
        get '/api/v1/processos', headers: valid_headers

        expect(response).to have_http_status(200)
        expect(response.content_type).to eq('application/json; charset=utf-8')

        json_response = JSON.parse(response.body)
        expect(json_response).to have_key('data')
        expect(json_response).to have_key('total')
        expect(json_response).to have_key('limit')
        expect(json_response).to have_key('offset')

        expect(json_response['data']).to be_an(Array)
        expect(json_response['limit']).to eq(20) # Default limit
        expect(json_response['offset']).to eq(0) # Default offset
      end

      it "retorna 200 OK com filtro por status" do
        get '/api/v1/processos?status=em_votacao', headers: valid_headers

        expect(response).to have_http_status(200)

        json_response = JSON.parse(response.body)
        # Se houver processos, todos devem ter o status solicitado
        json_response['data'].each do |processo|
          expect(processo['status']).to eq('em_votacao')
        end
      end

      it "retorna 200 OK com paginação customizada" do
        get '/api/v1/processos?limit=5&offset=10', headers: valid_headers

        expect(response).to have_http_status(200)

        json_response = JSON.parse(response.body)
        expect(json_response['limit']).to eq(5)
        expect(json_response['offset']).to eq(10)
      end
    end
  end

  describe "GET /api/v1/processos/:id" do
    let(:processo_id) { SecureRandom.uuid }

    context "quando obter detalhes do processo existente" do
      it "retorna 200 OK com detalhes completos do processo" do
        get "/api/v1/processos/#{processo_id}", headers: valid_headers

        # Este teste deve falhar até implementarmos o controller
        expect(response).to have_http_status(200)
        expect(response.content_type).to eq('application/json; charset=utf-8')

        json_response = JSON.parse(response.body)
        expect(json_response).to have_key('id')
        expect(json_response).to have_key('codigo_acompanhamento')
        expect(json_response).to have_key('tipo_infracao')
        expect(json_response).to have_key('status')
        expect(json_response).to have_key('cidadao_id')
        expect(json_response).to have_key('data_criacao')
        expect(json_response).to have_key('parecer_relator')
        expect(json_response).to have_key('documentos')
        expect(json_response).to have_key('votos')

        expect(json_response['documentos']).to be_an(Array)
        expect(json_response['votos']).to be_an(Array)
      end

      it "retorna 404 Not Found quando processo não existe" do
        non_existent_id = SecureRandom.uuid

        get "/api/v1/processos/#{non_existent_id}", headers: valid_headers

        expect(response).to have_http_status(404)

        json_response = JSON.parse(response.body)
        expect(json_response['error']).to eq('Not Found')
        expect(json_response['message']).to eq('Recurso não encontrado')
      end
    end
  end

  describe "PATCH /api/v1/processos/:id" do
    let(:processo_id) { SecureRandom.uuid }

    context "quando atualizar processo (status, parecer, etc.)" do
      let(:update_attributes) do
        {
          status: 'em_votacao',
          parecer_relator: 'Defesa procedente. Radar não calibrado conforme documentação apresentada.'
        }
      end

      it "retorna 200 OK com processo atualizado" do
        patch "/api/v1/processos/#{processo_id}",
              params: update_attributes.to_json,
              headers: valid_headers

        expect(response).to have_http_status(200)
        expect(response.content_type).to eq('application/json; charset=utf-8')

        json_response = JSON.parse(response.body)
        expect(json_response['id']).to eq(processo_id)
        expect(json_response['status']).to eq('em_votacao')
        expect(json_response['parecer_relator']).to eq(update_attributes[:parecer_relator])
      end

      it "retorna 400 Bad Request quando status é inválido" do
        invalid_update = { status: 'status_inexistente' }

        patch "/api/v1/processos/#{processo_id}",
              params: invalid_update.to_json,
              headers: valid_headers

        expect(response).to have_http_status(400)

        json_response = JSON.parse(response.body)
        expect(json_response).to have_key('error')
        expect(json_response).to have_key('message')
      end

      it "retorna 404 Not Found quando processo não existe" do
        non_existent_id = SecureRandom.uuid

        patch "/api/v1/processos/#{non_existent_id}",
              params: update_attributes.to_json,
              headers: valid_headers

        expect(response).to have_http_status(404)
      end
    end
  end
end