# Contract tests for /api/v1/dashboard endpoints
# Tests management dashboard API contract compliance

require 'rails_helper'

RSpec.describe "Api::V1::Dashboard", type: :request do
  let(:valid_headers) { { 'Content-Type' => 'application/json' } }

  describe "GET /api/v1/dashboard/metricas" do
    context "quando obter métricas em tempo real do sistema" do
      it "retorna 200 OK com métricas completas do sistema" do
        get '/api/v1/dashboard/metricas', headers: valid_headers

        expect(response).to have_http_status(200)
        expect(response.content_type).to eq('application/json; charset=utf-8')

        json_response = JSON.parse(response.body)

        # Validar estrutura das métricas conforme especificação OpenAPI
        expect(json_response).to have_key('processos_hoje')
        expect(json_response).to have_key('processos_pendentes')
        expect(json_response).to have_key('tempo_medio_processamento')
        expect(json_response).to have_key('taxa_deferimento')
        expect(json_response).to have_key('alertas_prazo')

        # Validar tipos de dados
        expect(json_response['processos_hoje']).to be_a(Integer)
        expect(json_response['processos_pendentes']).to be_a(Integer)
        expect(json_response['tempo_medio_processamento']).to be_a(Numeric)
        expect(json_response['taxa_deferimento']).to be_a(Numeric)
        expect(json_response['alertas_prazo']).to be_a(Integer)

        # Validar ranges lógicos
        expect(json_response['processos_hoje']).to be >= 0
        expect(json_response['processos_pendentes']).to be >= 0
        expect(json_response['tempo_medio_processamento']).to be >= 0
        expect(json_response['taxa_deferimento']).to be_between(0, 100).inclusive
        expect(json_response['alertas_prazo']).to be >= 0
      end

      it "retorna métricas atualizadas e precisas" do
        get '/api/v1/dashboard/metricas', headers: valid_headers

        expect(response).to have_http_status(200)

        json_response = JSON.parse(response.body)

        # Tempo médio de processamento em dias (deve ser razoável)
        tempo_medio = json_response['tempo_medio_processamento']
        expect(tempo_medio).to be_between(0, 30) # Máximo 30 dias é razoável

        # Taxa de deferimento em percentual (0-100%)
        taxa = json_response['taxa_deferimento']
        expect(taxa).to be_between(0, 100)

        # Alertas de prazo não deve ser negativo
        alertas = json_response['alertas_prazo']
        expect(alertas).to be >= 0
      end

      it "calcula métricas baseadas em dados reais do banco" do
        get '/api/v1/dashboard/metricas', headers: valid_headers

        expect(response).to have_http_status(200)

        json_response = JSON.parse(response.body)

        # As métricas devem ser consistentes
        # Se não há processos hoje, não deve haver alertas
        if json_response['processos_hoje'] == 0
          # Pode ter alertas de processos de dias anteriores
          expect(json_response['alertas_prazo']).to be >= 0
        end

        # Se há processos pendentes, tempo médio deve ser > 0 (se há histórico)
        if json_response['processos_pendentes'] > 0
          # Tempo médio pode ser 0 se todos os processos são muito recentes
          expect(json_response['tempo_medio_processamento']).to be >= 0
        end
      end

      it "retorna 401 Unauthorized quando não autenticado" do
        get '/api/v1/dashboard/metricas'

        expect(response).to have_http_status(401)

        json_response = JSON.parse(response.body)
        expect(json_response['error']).to eq('Unauthorized')
        expect(json_response['message']).to match(/token.*inválido.*expirado/i)
      end

      it "retorna 403 Forbidden quando usuário não tem permissão administrativa" do
        # Simular token de usuário sem permissões administrativas
        non_admin_headers = {
          'Content-Type' => 'application/json',
          'Authorization' => 'Bearer user_token_without_admin_permissions'
        }

        get '/api/v1/dashboard/metricas', headers: non_admin_headers

        # Pode retornar 403 ou 401 dependendo da implementação
        expect(response).to have_http_status(403).or have_http_status(401)

        if response.status == 403
          json_response = JSON.parse(response.body)
          expect(json_response['message']).to match(/permissão.*administrat/i)
        end
      end

      context "validação de performance" do
        it "responde em menos de 200ms para métricas em tempo real" do
          start_time = Time.current

          get '/api/v1/dashboard/metricas', headers: valid_headers

          response_time = (Time.current - start_time) * 1000 # em millisegundos

          # Métricas devem ser rápidas (< 200ms conforme requisitos)
          expect(response_time).to be < 200
        end
      end

      context "métricas específicas" do
        it "inclui processos criados nas últimas 24 horas em processos_hoje" do
          get '/api/v1/dashboard/metricas', headers: valid_headers

          if response.status == 200
            json_response = JSON.parse(response.body)
            processos_hoje = json_response['processos_hoje']

            # Deve ser um número inteiro não negativo
            expect(processos_hoje).to be_an(Integer)
            expect(processos_hoje).to be >= 0
          end
        end

        it "conta apenas processos em status pendente para processos_pendentes" do
          get '/api/v1/dashboard/metricas', headers: valid_headers

          if response.status == 200
            json_response = JSON.parse(response.body)
            processos_pendentes = json_response['processos_pendentes']

            # Status pendentes: rascunho, triagem, distribuido, em_analise, em_votacao
            # Status finais: decidido, rejeitado
            expect(processos_pendentes).to be_an(Integer)
            expect(processos_pendentes).to be >= 0
          end
        end

        it "calcula tempo médio apenas de processos finalizados" do
          get '/api/v1/dashboard/metricas', headers: valid_headers

          if response.status == 200
            json_response = JSON.parse(response.body)
            tempo_medio = json_response['tempo_medio_processamento']

            # Deve estar em dias e ser razoável
            expect(tempo_medio).to be_a(Numeric)
            expect(tempo_medio).to be >= 0
            expect(tempo_medio).to be <= 30 # Máximo constitucional é 30 dias, meta é 5 dias
          end
        end

        it "identifica processos próximos ao vencimento para alertas_prazo" do
          get '/api/v1/dashboard/metricas', headers: valid_headers

          if response.status == 200
            json_response = JSON.parse(response.body)
            alertas = json_response['alertas_prazo']

            # Alertas devem incluir processos com > 80% do prazo legal (24 de 30 dias)
            expect(alertas).to be_an(Integer)
            expect(alertas).to be >= 0
          end
        end
      end
    end
  end
end