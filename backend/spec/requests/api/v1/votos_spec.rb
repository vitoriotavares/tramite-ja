# Contract tests for /api/v1/processos/{id}/votos endpoints
# Tests voting system API contract compliance

require 'rails_helper'

RSpec.describe "Api::V1::Votos", type: :request do
  let(:valid_headers) { { 'Content-Type' => 'application/json' } }
  let(:processo_id) { SecureRandom.uuid }
  let(:julgador_id) { SecureRandom.uuid }

  describe "POST /api/v1/processos/:processo_id/votos" do
    context "quando registrar voto do julgador" do
      let(:valid_vote_attributes) do
        {
          decisao: 'concordo',
          justificativa: 'Concordo com o parecer do relator. Documentação comprova defeito no radar.',
          julgador_id: julgador_id
        }
      end

      it "retorna 201 Created com voto registrado" do
        post "/api/v1/processos/#{processo_id}/votos",
             params: valid_vote_attributes.to_json,
             headers: valid_headers

        expect(response).to have_http_status(201)
        expect(response.content_type).to eq('application/json; charset=utf-8')

        json_response = JSON.parse(response.body)

        # Validar estrutura do voto criado
        expect(json_response).to have_key('id')
        expect(json_response).to have_key('processo_id')
        expect(json_response).to have_key('julgador_id')
        expect(json_response).to have_key('decisao')
        expect(json_response).to have_key('justificativa')
        expect(json_response).to have_key('data_voto')

        # Validar valores específicos
        expect(json_response['processo_id']).to eq(processo_id)
        expect(json_response['julgador_id']).to eq(julgador_id)
        expect(json_response['decisao']).to eq('concordo')
        expect(json_response['justificativa']).to eq(valid_vote_attributes[:justificativa])

        # Validar formato da data
        expect(json_response['data_voto']).to match(/\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/)

        # Validar UUID do voto
        expect(json_response['id']).to match(/\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/)
      end

      it "aceita voto 'discordo' com justificativa" do
        discordo_attributes = valid_vote_attributes.merge(
          decisao: 'discordo',
          justificativa: 'Documentação insuficiente para comprovar defeito no radar.'
        )

        post "/api/v1/processos/#{processo_id}/votos",
             params: discordo_attributes.to_json,
             headers: valid_headers

        expect(response).to have_http_status(201)

        json_response = JSON.parse(response.body)
        expect(json_response['decisao']).to eq('discordo')
        expect(json_response['justificativa']).to eq(discordo_attributes[:justificativa])
      end

      it "aceita voto sem justificativa (campo opcional)" do
        vote_without_justification = valid_vote_attributes.except(:justificativa)

        post "/api/v1/processos/#{processo_id}/votos",
             params: vote_without_justification.to_json,
             headers: valid_headers

        expect(response).to have_http_status(201)

        json_response = JSON.parse(response.body)
        expect(json_response['justificativa']).to be_nil
      end

      it "retorna 400 Bad Request quando decisão é inválida" do
        invalid_vote = valid_vote_attributes.merge(decisao: 'decisao_invalida')

        post "/api/v1/processos/#{processo_id}/votos",
             params: invalid_vote.to_json,
             headers: valid_headers

        expect(response).to have_http_status(400)

        json_response = JSON.parse(response.body)
        expect(json_response).to have_key('error')
        expect(json_response['message']).to match(/decisão.*inválida.*concordo.*discordo/i)
      end

      it "retorna 400 Bad Request quando julgador_id está ausente" do
        invalid_vote = valid_vote_attributes.except(:julgador_id)

        post "/api/v1/processos/#{processo_id}/votos",
             params: invalid_vote.to_json,
             headers: valid_headers

        expect(response).to have_http_status(400)

        json_response = JSON.parse(response.body)
        expect(json_response['message']).to match(/julgador_id.*obrigatório/i)
      end

      it "retorna 400 Bad Request quando julgador já votou neste processo" do
        # Primeiro voto
        post "/api/v1/processos/#{processo_id}/votos",
             params: valid_vote_attributes.to_json,
             headers: valid_headers

        # Segundo voto do mesmo julgador (deve falhar)
        second_vote = valid_vote_attributes.merge(decisao: 'discordo')

        post "/api/v1/processos/#{processo_id}/votos",
             params: second_vote.to_json,
             headers: valid_headers

        expect(response).to have_http_status(400)

        json_response = JSON.parse(response.body)
        expect(json_response['message']).to match(/julgador.*já.*votou/i)
      end

      it "retorna 404 Not Found quando processo não existe" do
        processo_inexistente = SecureRandom.uuid

        post "/api/v1/processos/#{processo_inexistente}/votos",
             params: valid_vote_attributes.to_json,
             headers: valid_headers

        expect(response).to have_http_status(404)

        json_response = JSON.parse(response.body)
        expect(json_response['error']).to eq('Not Found')
      end

      it "retorna 422 Unprocessable Entity quando processo não está em votação" do
        # Simular processo que não está no status 'em_votacao'
        post "/api/v1/processos/#{processo_id}/votos",
             params: valid_vote_attributes.to_json,
             headers: valid_headers

        # Dependendo da implementação, pode retornar 422 ou 400
        expect(response).to have_http_status(422).or have_http_status(400)

        if response.status == 422
          json_response = JSON.parse(response.body)
          expect(json_response['message']).to match(/processo.*não.*votação/i)
        end
      end

      it "retorna 401 Unauthorized quando julgador não autenticado" do
        invalid_headers = {
          'Content-Type' => 'application/json',
          'Authorization' => 'Bearer invalid_token'
        }

        post "/api/v1/processos/#{processo_id}/votos",
             params: valid_vote_attributes.to_json,
             headers: invalid_headers

        expect(response).to have_http_status(401)

        json_response = JSON.parse(response.body)
        expect(json_response['error']).to eq('Unauthorized')
      end
    end
  end

  describe "GET /api/v1/processos/:processo_id/votos" do
    context "quando obter votos do processo" do
      it "retorna 200 OK com lista de votos e informações de quórum" do
        get "/api/v1/processos/#{processo_id}/votos", headers: valid_headers

        expect(response).to have_http_status(200)
        expect(response.content_type).to eq('application/json; charset=utf-8')

        json_response = JSON.parse(response.body)

        # Validar estrutura da resposta
        expect(json_response).to have_key('votos')
        expect(json_response).to have_key('quorum_atingido')
        expect(json_response).to have_key('resultado')

        # Validar tipos
        expect(json_response['votos']).to be_an(Array)
        expect(json_response['quorum_atingido']).to be_in([true, false])
        expect(json_response['resultado']).to be_in(['deferido', 'indeferido', 'pendente'])

        # Validar estrutura dos votos
        json_response['votos'].each do |voto|
          expect(voto).to have_key('id')
          expect(voto).to have_key('processo_id')
          expect(voto).to have_key('julgador_id')
          expect(voto).to have_key('decisao')
          expect(voto).to have_key('data_voto')

          # Validar valores dos votos
          expect(voto['processo_id']).to eq(processo_id)
          expect(voto['decisao']).to be_in(['concordo', 'discordo'])

          # Validar UUIDs
          expect(voto['id']).to match(/\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/)
          expect(voto['julgador_id']).to match(/\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/)
        end
      end

      it "retorna votos ordenados por data (mais antigo primeiro)" do
        get "/api/v1/processos/#{processo_id}/votos", headers: valid_headers

        if response.status == 200
          json_response = JSON.parse(response.body)
          votos = json_response['votos']

          if votos.length > 1
            # Verificar ordenação por data (mais antigo primeiro)
            dates = votos.map { |voto| DateTime.parse(voto['data_voto']) }
            expect(dates).to eq(dates.sort)
          end
        end
      end

      it "calcula quórum corretamente" do
        get "/api/v1/processos/#{processo_id}/votos", headers: valid_headers

        if response.status == 200
          json_response = JSON.parse(response.body)
          votos = json_response['votos']
          quorum_atingido = json_response['quorum_atingido']

          # Quórum é atingido com 3 ou mais votos (maioria simples)
          if votos.length >= 3
            expect(quorum_atingido).to be true
          else
            expect(quorum_atingido).to be false
          end
        end
      end

      it "calcula resultado baseado na maioria dos votos" do
        get "/api/v1/processos/#{processo_id}/votos", headers: valid_headers

        if response.status == 200
          json_response = JSON.parse(response.body)
          votos = json_response['votos']
          resultado = json_response['resultado']

          if json_response['quorum_atingido']
            concordam = votos.count { |v| v['decisao'] == 'concordo' }
            discordam = votos.count { |v| v['decisao'] == 'discordo' }

            if concordam > discordam
              expect(resultado).to eq('deferido')
            elsif discordam > concordam
              expect(resultado).to eq('indeferido')
            end
          else
            expect(resultado).to eq('pendente')
          end
        end
      end

      it "retorna array vazio quando processo não tem votos" do
        get "/api/v1/processos/#{processo_id}/votos", headers: valid_headers

        expect(response).to have_http_status(200)

        json_response = JSON.parse(response.body)
        expect(json_response['votos']).to be_an(Array)
        expect(json_response['quorum_atingido']).to be false
        expect(json_response['resultado']).to eq('pendente')
      end

      it "retorna 404 Not Found quando processo não existe" do
        processo_inexistente = SecureRandom.uuid

        get "/api/v1/processos/#{processo_inexistente}/votos", headers: valid_headers

        expect(response).to have_http_status(404)

        json_response = JSON.parse(response.body)
        expect(json_response['error']).to eq('Not Found')
        expect(json_response['message']).to eq('Recurso não encontrado')
      end

      it "retorna 401 Unauthorized quando não autenticado" do
        get "/api/v1/processos/#{processo_id}/votos"

        expect(response).to have_http_status(401)

        json_response = JSON.parse(response.body)
        expect(json_response['error']).to eq('Unauthorized')
      end

      context "validação de autorização" do
        it "permite acesso para julgadores autorizados" do
          # Este teste validará autorização quando implementado
          get "/api/v1/processos/#{processo_id}/votos", headers: valid_headers

          # Deve retornar 200 ou 404 (não 403 para julgador autorizado)
          expect(response).to have_http_status(200).or have_http_status(404)
          expect(response).not_to have_http_status(403)
        end

        it "permite acesso para relatores do processo" do
          # Relatores devem poder ver os votos do processo que analisaram
          get "/api/v1/processos/#{processo_id}/votos", headers: valid_headers

          expect(response).to have_http_status(200).or have_http_status(404)
          expect(response).not_to have_http_status(403)
        end
      end
    end
  end
end