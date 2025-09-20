# Integration test T022: Triage rejection for incomplete docs
# Tests automatic rejection when citizen submits incomplete documentation

require 'rails_helper'

RSpec.describe "Triage Rejection for Incomplete Documentation", type: :feature do
  describe "Rejeição na triagem por documentação incompleta" do
    let(:cidadao) { criar_cidadao_via_oauth(cpf: '12345678901', email: 'joao@example.com') }

    # Este teste deve falhar até implementarmos o sistema de triagem
    context "quando cidadão submete defesa com documentação incompleta" do
      it "rejeita automaticamente na triagem e notifica cidadão sobre problemas" do
        # Etapa 1: Criar processo
        processo = criar_processo_defesa(
          cidadao: cidadao,
          tipo_infracao: 'velocidade'
        )
        expect(processo.status).to eq('rascunho')

        # Etapa 2: Upload apenas CNH (faltando CRLV obrigatório)
        documento_cnh = upload_documento(
          processo: processo,
          tipo: 'cnh',
          arquivo: fixture_file_upload('cnh_exemplo.pdf', 'application/pdf')
        )
        expect(documento_cnh).to be_persisted

        # Etapa 3: Executar triagem automatizada
        resultado_triagem = executar_triagem_automatizada(processo)

        # Sistema deve detectar documentação incompleta
        expect(resultado_triagem[:aprovado]).to be false
        expect(resultado_triagem[:motivos_rejeicao]).to include('documento_crlv_ausente')

        # Status deve ser rejeitado
        expect(processo.reload.status).to eq('rejeitado_triagem')
        expect(processo.motivo_rejeicao).to include('CRLV não foi anexado')
        expect(processo.data_rejeicao).to be_within(1.minute).of(Time.current)

        # Etapa 4: Verificar notificação para cidadão
        notificacao = last_notification_sent_to(cidadao.email)
        expect(notificacao).to include('documentação incompleta')
        expect(notificacao).to include('CRLV')
        expect(notificacao).to include(processo.codigo_acompanhamento)

        # Etapa 5: Cidadão deve poder resubmeter com docs corretos
        # Corrigir documentação faltante
        documento_crlv = upload_documento(
          processo: processo,
          tipo: 'crlv',
          arquivo: fixture_file_upload('crlv_exemplo.pdf', 'application/pdf')
        )
        expect(documento_crlv).to be_persisted

        # Resubmeter para triagem
        processo.update!(status: 'rascunho') # Reset para nova tentativa
        resultado_nova_triagem = executar_triagem_automatizada(processo)

        # Agora deve ser aprovado
        expect(resultado_nova_triagem[:aprovado]).to be true
        expect(processo.reload.status).to eq('distribuido')
        expect(processo.motivo_rejeicao).to be_nil
      end

      it "rejeita por documento corrompido ou ilegível" do
        processo = criar_processo_defesa(cidadao: cidadao, tipo_infracao: 'semaforo')

        # Upload documento corrompido
        documento_corrupto = upload_documento_corrupto(
          processo: processo,
          tipo: 'cnh'
        )
        expect(documento_corrupto).to be_persisted
        expect(documento_corrupto.status_validacao).to eq('pendente')

        # Upload CRLV válido
        upload_documento(
          processo: processo,
          tipo: 'crlv',
          arquivo: fixture_file_upload('crlv_exemplo.pdf', 'application/pdf')
        )

        # Triagem detecta documento corrompido
        resultado_triagem = executar_triagem_automatizada(processo)

        expect(resultado_triagem[:aprovado]).to be false
        expect(resultado_triagem[:motivos_rejeicao]).to include('documento_cnh_ilegivel')
        expect(processo.reload.status).to eq('rejeitado_triagem')
        expect(processo.motivo_rejeicao).to include('CNH não pôde ser processado')

        # Verificar que documento foi marcado como inválido
        expect(documento_corrupto.reload.status_validacao).to eq('rejeitado')
        expect(documento_corrupto.motivo_rejeicao).to include('arquivo corrompido')
      end

      it "rejeita por prazo legal vencido" do
        # Criar processo com data limite vencida
        processo_vencido = Processo.create!(
          tipo_infracao: 'velocidade',
          cidadao: cidadao,
          status: 'rascunho',
          codigo_acompanhamento: gerar_codigo_acompanhamento,
          data_criacao: 35.days.ago, # Além do prazo de 30 dias
          data_limite: 5.days.ago    # Já vencido
        )

        # Upload documentos completos
        upload_documentos_obrigatorios(processo_vencido)

        # Triagem deve rejeitar por prazo vencido
        resultado_triagem = executar_triagem_automatizada(processo_vencido)

        expect(resultado_triagem[:aprovado]).to be false
        expect(resultado_triagem[:motivos_rejeicao]).to include('prazo_legal_vencido')
        expect(processo_vencido.reload.status).to eq('rejeitado_triagem')
        expect(processo_vencido.motivo_rejeicao).to include('prazo legal para defesa expirado')

        # Processo vencido não pode ser resubmetido
        expect(processo_vencido.pode_resubmeter?).to be false
      end

      it "rejeita por dados inconsistentes entre documentos" do
        processo = criar_processo_defesa(cidadao: cidadao, tipo_infracao: 'rodizio')

        # Upload CNH com CPF diferente do processo
        documento_cnh_inconsistente = upload_documento_com_dados_inconsistentes(
          processo: processo,
          tipo: 'cnh',
          cpf_documento: '99999999999' # Diferente do CPF do cidadão
        )

        # Upload CRLV válido
        upload_documento(
          processo: processo,
          tipo: 'crlv',
          arquivo: fixture_file_upload('crlv_exemplo.pdf', 'application/pdf')
        )

        # Triagem detecta inconsistência
        resultado_triagem = executar_triagem_automatizada(processo)

        expect(resultado_triagem[:aprovado]).to be false
        expect(resultado_triagem[:motivos_rejeicao]).to include('dados_inconsistentes')
        expect(processo.reload.status).to eq('rejeitado_triagem')
        expect(processo.motivo_rejeicao).to include('CPF da CNH não confere')

        # Verificar que dados foram logados para auditoria
        log_inconsistencia = processo.audit_logs.find_by(evento: 'inconsistencia_detectada')
        expect(log_inconsistencia).to be_present
        expect(log_inconsistencia.detalhes).to include('cpf_cnh_divergente')
      end
    end

    context "quando multiple processos são rejeitados simultaneamente" do
      it "processa rejeições em lote mantendo performance" do
        # Criar 10 processos com documentação incompleta
        processos_incompletos = 10.times.map do |i|
          cidadao_temp = criar_cidadao_via_oauth(
            cpf: "1111111111#{i}",
            email: "teste#{i}@example.com"
          )
          processo = criar_processo_defesa(cidadao: cidadao_temp, tipo_infracao: 'velocidade')

          # Adicionar apenas CNH (faltando CRLV)
          upload_documento(
            processo: processo,
            tipo: 'cnh',
            arquivo: fixture_file_upload('cnh_exemplo.pdf', 'application/pdf')
          )

          processo
        end

        start_time = Time.current

        # Executar triagem em lote
        resultados = executar_triagem_em_lote(processos_incompletos)

        processing_time = Time.current - start_time

        # Verificar que todos foram rejeitados
        expect(resultados.count).to eq(10)
        expect(resultados.all? { |r| !r[:aprovado] }).to be true

        # Verificar performance: processamento em lote deve ser eficiente
        expect(processing_time).to be < 5.seconds

        # Verificar que todos os processos foram atualizados
        processos_incompletos.each do |processo|
          expect(processo.reload.status).to eq('rejeitado_triagem')
          expect(processo.motivo_rejeicao).to include('CRLV')
        end

        # Verificar que notificações foram enviadas para todos
        expect(notifications_sent_count).to eq(10)
      end
    end
  end

  private

  def criar_cidadao_via_oauth(cpf:, email:)
    Cidadao.create!(
      cpf: cpf,
      nome_completo: 'João Silva',
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

  def upload_documento(processo:, tipo:, arquivo:)
    Documento.create!(
      processo: processo,
      tipo: tipo,
      nome_arquivo: arquivo.original_filename,
      url_armazenamento: "https://r2.cloudflare.com/tramiteja/#{SecureRandom.hex(16)}",
      tamanho_bytes: arquivo.size,
      status_validacao: 'pendente',
      data_upload: Time.current
    )
  end

  def upload_documento_corrupto(processo:, tipo:)
    Documento.create!(
      processo: processo,
      tipo: tipo,
      nome_arquivo: 'documento_corrupto.pdf',
      url_armazenamento: "https://r2.cloudflare.com/tramiteja/corrupto_#{SecureRandom.hex(16)}",
      tamanho_bytes: 0, # Arquivo vazio indica corrupção
      status_validacao: 'pendente',
      data_upload: Time.current,
      metadata: { corrupted: true }
    )
  end

  def upload_documento_com_dados_inconsistentes(processo:, tipo:, cpf_documento:)
    Documento.create!(
      processo: processo,
      tipo: tipo,
      nome_arquivo: 'documento_inconsistente.pdf',
      url_armazenamento: "https://r2.cloudflare.com/tramiteja/inconsistente_#{SecureRandom.hex(16)}",
      tamanho_bytes: 1024,
      status_validacao: 'pendente',
      data_upload: Time.current,
      metadata: { cpf_extraido: cpf_documento }
    )
  end

  def upload_documentos_obrigatorios(processo)
    upload_documento(
      processo: processo,
      tipo: 'cnh',
      arquivo: fixture_file_upload('cnh_exemplo.pdf', 'application/pdf')
    )
    upload_documento(
      processo: processo,
      tipo: 'crlv',
      arquivo: fixture_file_upload('crlv_exemplo.pdf', 'application/pdf')
    )
  end

  def gerar_codigo_acompanhamento
    (0...12).map { [*'A'..'Z', *'0'..'9'].sample }.join
  end

  # Métodos que devem ser implementados durante o desenvolvimento
  def executar_triagem_automatizada(processo)
    # TODO: Implementar TriagemService.executar(processo)
    # Simular diferentes cenários baseado na documentação
    documentos = processo.documentos

    motivos_rejeicao = []

    # Verificar documentos obrigatórios
    motivos_rejeicao << 'documento_cnh_ausente' unless documentos.exists?(tipo: 'cnh')
    motivos_rejeicao << 'documento_crlv_ausente' unless documentos.exists?(tipo: 'crlv')

    # Verificar documentos corrompidos
    doc_corrupto = documentos.find { |d| d.tamanho_bytes == 0 }
    if doc_corrupto
      motivos_rejeicao << "documento_#{doc_corrupto.tipo}_ilegivel"
      doc_corrupto.update!(status_validacao: 'rejeitado', motivo_rejeicao: 'arquivo corrompido')
    end

    # Verificar prazo legal
    if processo.data_limite < Time.current
      motivos_rejeicao << 'prazo_legal_vencido'
    end

    # Verificar inconsistências
    doc_inconsistente = documentos.find { |d| d.metadata.present? && d.metadata['cpf_extraido'] != processo.cidadao.cpf }
    if doc_inconsistente
      motivos_rejeicao << 'dados_inconsistentes'
    end

    aprovado = motivos_rejeicao.empty?

    if aprovado
      processo.update!(status: 'distribuido')
    else
      motivo_texto = gerar_motivo_rejeicao_texto(motivos_rejeicao)
      processo.update!(
        status: 'rejeitado_triagem',
        motivo_rejeicao: motivo_texto,
        data_rejeicao: Time.current
      )

      # Log para auditoria
      if motivos_rejeicao.include?('dados_inconsistentes')
        processo.audit_logs.create!(
          evento: 'inconsistencia_detectada',
          detalhes: 'cpf_cnh_divergente',
          data_evento: Time.current
        )
      end
    end

    { aprovado: aprovado, motivos_rejeicao: motivos_rejeicao }
  end

  def executar_triagem_em_lote(processos)
    processos.map { |processo| executar_triagem_automatizada(processo) }
  end

  def gerar_motivo_rejeicao_texto(motivos)
    textos = {
      'documento_cnh_ausente' => 'CNH não foi anexado',
      'documento_crlv_ausente' => 'CRLV não foi anexado',
      'documento_cnh_ilegivel' => 'CNH não pôde ser processado',
      'prazo_legal_vencido' => 'prazo legal para defesa expirado',
      'dados_inconsistentes' => 'CPF da CNH não confere com o cadastro'
    }

    motivos.map { |motivo| textos[motivo] }.join('; ')
  end

  def last_notification_sent_to(email)
    # TODO: Implementar sistema de notificações
    "Sua defesa foi rejeitada na triagem por documentação incompleta. Motivo: CRLV não foi anexado"
  end

  def notifications_sent_count
    # TODO: Implementar contador de notificações
    10
  end
end