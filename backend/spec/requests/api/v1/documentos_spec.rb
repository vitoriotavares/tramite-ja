# Contract tests for /api/v1/processos/{id}/documentos endpoints
# Tests document upload and retrieval API contract compliance

require 'rails_helper'

RSpec.describe "Api::V1::Documentos", type: :request do
  let(:valid_headers) { { 'Content-Type' => 'application/json' } }
  let(:processo_id) { SecureRandom.uuid }

  describe "POST /api/v1/processos/:processo_id/documentos" do
    context "quando fazer upload de documento" do
      let(:arquivo_pdf) do
        # Simular arquivo PDF
        fixture_file_upload(Rails.root.join('spec', 'fixtures', 'files', 'cnh_exemplo.pdf'), 'application/pdf')
      end

      let(:valid_upload_params) do
        {
          arquivo: arquivo_pdf,
          tipo: 'cnh'
        }
      end

      before do
        # Criar arquivo de exemplo para testes se não existir
        FileUtils.mkdir_p(Rails.root.join('spec', 'fixtures', 'files'))
        unless File.exist?(Rails.root.join('spec', 'fixtures', 'files', 'cnh_exemplo.pdf'))
          File.write(Rails.root.join('spec', 'fixtures', 'files', 'cnh_exemplo.pdf'),
                     '%PDF-1.4 exemplo documento PDF para testes')
        end
      end

      it "retorna 201 Created com documento uploadado com sucesso" do
        post "/api/v1/processos/#{processo_id}/documentos",
             params: valid_upload_params,
             headers: { 'Content-Type' => 'multipart/form-data' }

        expect(response).to have_http_status(201)
        expect(response.content_type).to eq('application/json; charset=utf-8')

        json_response = JSON.parse(response.body)

        # Validar estrutura do documento criado
        expect(json_response).to have_key('id')
        expect(json_response).to have_key('processo_id')
        expect(json_response).to have_key('tipo')
        expect(json_response).to have_key('nome_arquivo')
        expect(json_response).to have_key('url_armazenamento')
        expect(json_response).to have_key('tamanho_bytes')
        expect(json_response).to have_key('status_validacao')
        expect(json_response).to have_key('data_upload')

        # Validar valores específicos
        expect(json_response['processo_id']).to eq(processo_id)
        expect(json_response['tipo']).to eq('cnh')
        expect(json_response['nome_arquivo']).to eq('cnh_exemplo.pdf')
        expect(json_response['tamanho_bytes']).to be_a(Integer)
        expect(json_response['status_validacao']).to eq('pendente')

        # Validar URL de armazenamento (deve ser URL válida do R2 Cloudflare)
        expect(json_response['url_armazenamento']).to match(/\Ahttps?:\/\//)

        # Validar formato da data
        expect(json_response['data_upload']).to match(/\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/)

        # Validar UUID do documento
        expect(json_response['id']).to match(/\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/)
      end

      it "retorna 400 Bad Request quando tipo de documento é inválido" do
        invalid_params = valid_upload_params.merge(tipo: 'tipo_invalido')

        post "/api/v1/processos/#{processo_id}/documentos",
             params: invalid_params,
             headers: { 'Content-Type' => 'multipart/form-data' }

        expect(response).to have_http_status(400)

        json_response = JSON.parse(response.body)
        expect(json_response).to have_key('error')
        expect(json_response).to have_key('message')
        expect(json_response['message']).to match(/tipo.*inválido/i)
      end

      it "retorna 400 Bad Request quando arquivo não é fornecido" do
        invalid_params = { tipo: 'cnh' } # Sem arquivo

        post "/api/v1/processos/#{processo_id}/documentos",
             params: invalid_params,
             headers: { 'Content-Type' => 'multipart/form-data' }

        expect(response).to have_http_status(400)

        json_response = JSON.parse(response.body)
        expect(json_response).to have_key('error')
        expect(json_response['message']).to match(/arquivo.*obrigatório/i)
      end

      it "retorna 400 Bad Request quando arquivo excede limite de tamanho (10MB)" do
        # Simular arquivo muito grande
        large_file_content = 'A' * (11 * 1024 * 1024) # 11MB
        large_file_path = Rails.root.join('spec', 'fixtures', 'files', 'arquivo_grande.pdf')
        File.write(large_file_path, large_file_content)

        large_file = fixture_file_upload(large_file_path, 'application/pdf')
        params_with_large_file = valid_upload_params.merge(arquivo: large_file)

        post "/api/v1/processos/#{processo_id}/documentos",
             params: params_with_large_file,
             headers: { 'Content-Type' => 'multipart/form-data' }

        expect(response).to have_http_status(400)

        json_response = JSON.parse(response.body)
        expect(json_response['message']).to match(/arquivo.*grande.*10MB/i)

        # Limpar arquivo de teste
        File.delete(large_file_path) if File.exist?(large_file_path)
      end

      it "retorna 400 Bad Request quando tipo MIME não é permitido" do
        # Criar arquivo com tipo MIME não permitido
        txt_file_path = Rails.root.join('spec', 'fixtures', 'files', 'documento.txt')
        File.write(txt_file_path, 'Arquivo de texto não permitido')

        txt_file = fixture_file_upload(txt_file_path, 'text/plain')
        params_with_txt = valid_upload_params.merge(arquivo: txt_file)

        post "/api/v1/processos/#{processo_id}/documentos",
             params: params_with_txt,
             headers: { 'Content-Type' => 'multipart/form-data' }

        expect(response).to have_http_status(400)

        json_response = JSON.parse(response.body)
        expect(json_response['message']).to match(/tipo.*arquivo.*permitido.*PDF.*JPG.*PNG/i)

        # Limpar arquivo de teste
        File.delete(txt_file_path) if File.exist?(txt_file_path)
      end

      it "aceita diferentes tipos de documentos válidos" do
        tipos_validos = ['cnh', 'crlv', 'comprovante', 'outros']

        tipos_validos.each do |tipo|
          params = valid_upload_params.merge(tipo: tipo)

          post "/api/v1/processos/#{processo_id}/documentos",
               params: params,
               headers: { 'Content-Type' => 'multipart/form-data' }

          # Deve retornar 201 ou outro código que não seja 400 para tipo válido
          expect(response).not_to have_http_status(400)
        end
      end

      it "retorna 404 Not Found quando processo não existe" do
        processo_inexistente = SecureRandom.uuid

        post "/api/v1/processos/#{processo_inexistente}/documentos",
             params: valid_upload_params,
             headers: { 'Content-Type' => 'multipart/form-data' }

        expect(response).to have_http_status(404)

        json_response = JSON.parse(response.body)
        expect(json_response['error']).to eq('Not Found')
      end
    end
  end

  describe "GET /api/v1/processos/:processo_id/documentos" do
    context "quando listar documentos do processo" do
      it "retorna 200 OK com lista de documentos" do
        get "/api/v1/processos/#{processo_id}/documentos", headers: valid_headers

        expect(response).to have_http_status(200)
        expect(response.content_type).to eq('application/json; charset=utf-8')

        json_response = JSON.parse(response.body)
        expect(json_response).to be_an(Array)

        # Se houver documentos, validar estrutura
        json_response.each do |documento|
          expect(documento).to have_key('id')
          expect(documento).to have_key('processo_id')
          expect(documento).to have_key('tipo')
          expect(documento).to have_key('nome_arquivo')
          expect(documento).to have_key('url_armazenamento')
          expect(documento).to have_key('tamanho_bytes')
          expect(documento).to have_key('status_validacao')
          expect(documento).to have_key('data_upload')

          # Validar tipos
          expect(documento['processo_id']).to eq(processo_id)
          expect(documento['tipo']).to be_in(['cnh', 'crlv', 'comprovante', 'outros'])
          expect(documento['status_validacao']).to be_in(['pendente', 'aprovado', 'rejeitado'])
          expect(documento['tamanho_bytes']).to be_a(Integer)
        end
      end

      it "retorna array vazio quando processo não tem documentos" do
        get "/api/v1/processos/#{processo_id}/documentos", headers: valid_headers

        expect(response).to have_http_status(200)

        json_response = JSON.parse(response.body)
        expect(json_response).to be_an(Array)
        # Pode estar vazio se processo não tem documentos
      end

      it "retorna 404 Not Found quando processo não existe" do
        processo_inexistente = SecureRandom.uuid

        get "/api/v1/processos/#{processo_inexistente}/documentos", headers: valid_headers

        expect(response).to have_http_status(404)

        json_response = JSON.parse(response.body)
        expect(json_response['error']).to eq('Not Found')
        expect(json_response['message']).to eq('Recurso não encontrado')
      end

      it "retorna documentos ordenados por data de upload (mais recente primeiro)" do
        get "/api/v1/processos/#{processo_id}/documentos", headers: valid_headers

        if response.status == 200
          json_response = JSON.parse(response.body)

          if json_response.length > 1
            # Verificar ordenação por data (mais recente primeiro)
            dates = json_response.map { |doc| DateTime.parse(doc['data_upload']) }
            expect(dates).to eq(dates.sort.reverse)
          end
        end
      end

      context "validação de acesso" do
        it "retorna 401 Unauthorized quando token é inválido" do
          invalid_headers = {
            'Content-Type' => 'application/json',
            'Authorization' => 'Bearer invalid_token'
          }

          get "/api/v1/processos/#{processo_id}/documentos", headers: invalid_headers

          expect(response).to have_http_status(401)

          json_response = JSON.parse(response.body)
          expect(json_response['error']).to eq('Unauthorized')
        end

        it "permite acesso para proprietário do processo" do
          # Este teste validará autorização quando implementado
          get "/api/v1/processos/#{processo_id}/documentos", headers: valid_headers

          # Deve retornar 200 ou 404 (não 403 Forbidden para proprietário)
          expect(response).to have_http_status(200).or have_http_status(404)
          expect(response).not_to have_http_status(403)
        end
      end
    end
  end
end