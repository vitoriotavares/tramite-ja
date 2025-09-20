# Contract tests for /api/v1/acompanhamento endpoint
# Tests public process tracking API contract (no authentication required)

require 'rails_helper'

RSpec.describe "Api::V1::Acompanhamento", type: :request do
  let(:valid_headers) { { 'Content-Type' => 'application/json' } }

  describe "GET /api/v1/acompanhamento/:codigo" do
    let(:codigo_acompanhamento) { 'ABC123DEF456' } # Formato esperado: 12 caracteres alfanuméricos

    context "quando acompanhar processo por código (sem autenticação)" do
      it "retorna 200 OK com timeline do processo público" do
        get "/api/v1/acompanhamento/#{codigo_acompanhamento}", headers: valid_headers

        expect(response).to have_http_status(200)
        expect(response.content_type).to eq('application/json; charset=utf-8')

        json_response = JSON.parse(response.body)

        # Validar estrutura do objeto processo
        expect(json_response).to have_key('processo')
        expect(json_response).to have_key('timeline')

        processo = json_response['processo']
        expect(processo).to have_key('id')
        expect(processo).to have_key('codigo_acompanhamento')
        expect(processo).to have_key('tipo_infracao')
        expect(processo).to have_key('status')
        expect(processo).to have_key('data_criacao')
        expect(processo).to have_key('data_limite')

        # Campos opcionais baseados no status
        if processo['status'] == 'decidido'
          expect(processo).to have_key('data_decisao')
          expect(processo).to have_key('decisao_final')
        end

        # Validar timeline como array de etapas
        timeline = json_response['timeline']
        expect(timeline).to be_an(Array)

        timeline.each do |etapa|
          expect(etapa).to have_key('etapa')
          expect(etapa).to have_key('data')
          expect(etapa).to have_key('descricao')
          expect(etapa).to have_key('concluida')

          # Validar tipos de dados
          expect(etapa['etapa']).to be_a(String)
          expect(etapa['concluida']).to be_in([true, false])

          # Validar formato da data
          expect(etapa['data']).to match(/\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/)
        end

        # Validar que código retornado corresponde ao solicitado
        expect(processo['codigo_acompanhamento']).to eq(codigo_acompanhamento)
      end

      it "retorna 404 Not Found quando código de acompanhamento não existe" do
        codigo_inexistente = 'INEXISTENT01'

        get "/api/v1/acompanhamento/#{codigo_inexistente}", headers: valid_headers

        expect(response).to have_http_status(404)
        expect(response.content_type).to eq('application/json; charset=utf-8')

        json_response = JSON.parse(response.body)
        expect(json_response['error']).to eq('Not Found')
        expect(json_response['message']).to eq('Recurso não encontrado')
      end

      it "retorna 400 Bad Request quando código tem formato inválido" do
        codigo_invalido = 'ABC123' # Muito curto, formato incorreto

        get "/api/v1/acompanhamento/#{codigo_invalido}", headers: valid_headers

        expect(response).to have_http_status(400)
        expect(response.content_type).to eq('application/json; charset=utf-8')

        json_response = JSON.parse(response.body)
        expect(json_response).to have_key('error')
        expect(json_response).to have_key('message')
        expect(json_response['message']).to match(/código.*formato.*inválido/i)
      end

      it "aceita acesso sem autenticação (endpoint público)" do
        # Este endpoint deve ser acessível sem token de autenticação
        get "/api/v1/acompanhamento/#{codigo_acompanhamento}"

        # Não deve retornar 401 Unauthorized
        expect(response).not_to have_http_status(401)

        # Deve retornar 200 (se processo existe) ou 404 (se não existe)
        expect(response).to have_http_status(200).or have_http_status(404)
      end

      it "valida formato correto do código de acompanhamento" do
        # Código deve ter exatamente 12 caracteres alfanuméricos maiúsculos
        codigo_valido = 'A1B2C3D4E5F6'

        get "/api/v1/acompanhamento/#{codigo_valido}", headers: valid_headers

        # Se o processo não existir, deve retornar 404 (não 400)
        # Se existir, deve retornar 200
        expect(response).to have_http_status(200).or have_http_status(404)
        expect(response).not_to have_http_status(400)
      end

      context "quando processo tem diferentes status" do
        it "retorna informações adequadas para processo em rascunho" do
          get "/api/v1/acompanhamento/#{codigo_acompanhamento}", headers: valid_headers

          if response.status == 200
            json_response = JSON.parse(response.body)
            processo = json_response['processo']

            if processo['status'] == 'rascunho'
              # Em rascunho, não deve ter parecer ou decisão
              expect(processo['parecer_relator']).to be_nil
              expect(processo['decisao_final']).to be_nil
              expect(processo['data_decisao']).to be_nil
            end
          end
        end

        it "retorna informações adequadas para processo decidido" do
          get "/api/v1/acompanhamento/#{codigo_acompanhamento}", headers: valid_headers

          if response.status == 200
            json_response = JSON.parse(response.body)
            processo = json_response['processo']

            if processo['status'] == 'decidido'
              # Processo decidido deve ter decisão final e data
              expect(processo['decisao_final']).to be_in(['deferido', 'indeferido'])
              expect(processo['data_decisao']).not_to be_nil
            end
          end
        end
      end

      context "validação de timeline" do
        it "retorna timeline ordenada cronologicamente" do
          get "/api/v1/acompanhamento/#{codigo_acompanhamento}", headers: valid_headers

          if response.status == 200
            json_response = JSON.parse(response.body)
            timeline = json_response['timeline']

            # Timeline deve estar ordenada por data (mais antiga primeiro)
            dates = timeline.map { |etapa| DateTime.parse(etapa['data']) }
            expect(dates).to eq(dates.sort)
          end
        end

        it "inclui etapas obrigatórias do processo" do
          get "/api/v1/acompanhamento/#{codigo_acompanhamento}", headers: valid_headers

          if response.status == 200
            json_response = JSON.parse(response.body)
            timeline = json_response['timeline']
            etapas = timeline.map { |e| e['etapa'] }

            # Deve sempre incluir etapa de criação
            expect(etapas).to include('criacao')

            # Baseado no status, deve incluir outras etapas
            processo = json_response['processo']
            case processo['status']
            when 'triagem', 'distribuido', 'em_analise', 'em_votacao', 'decidido'
              expect(etapas).to include('triagem')
            when 'distribuido', 'em_analise', 'em_votacao', 'decidido'
              expect(etapas).to include('distribuicao')
            when 'decidido'
              expect(etapas).to include('decisao')
            end
          end
        end
      end
    end
  end
end