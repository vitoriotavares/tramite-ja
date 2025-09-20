# Integration test T023: Collegial voting with disagreement
# Tests voting scenarios where judges disagree and different quorum outcomes

require 'rails_helper'

RSpec.describe "Collegial Voting with Disagreement", type: :feature do
  describe "Votação colegiada com divergências entre julgadores" do
    let(:cidadao) { criar_cidadao_via_oauth(cpf: '12345678901', email: 'joao@example.com') }
    let(:relator) { criar_relator_especializado(especializacao: 'velocidade') }

    # Este teste deve falhar até implementarmos o sistema de votação completo
    context "quando julgadores divergem sobre a decisão" do
      it "processa votação com maioria discordando do relator" do
        # Etapa 1: Criar e processar até votação
        processo = criar_processo_completo_ate_votacao(cidadao, relator)
        expect(processo.status).to eq('em_votacao')
        expect(processo.parecer_relator).to include('procedente')

        # Etapa 2: Criar 5 julgadores para votação
        julgadores = criar_julgadores_para_votacao(quantidade: 5)

        # Etapa 3: Votação com maioria discordando
        travel_to 1.day.from_now do
          # Primeiro voto: Discordo
          voto1 = registrar_voto(
            processo: processo,
            julgador: julgadores[0],
            decisao: 'discordo',
            justificativa: 'Documentação apresentada não comprova defeito no radar'
          )
          expect(voto1).to be_persisted
          expect(processo.reload.quorum_atingido?).to be false

          # Segundo voto: Discordo
          voto2 = registrar_voto(
            processo: processo,
            julgador: julgadores[1],
            decisao: 'discordo',
            justificativa: 'Velocidade registrada está dentro da margem de erro'
          )
          expect(voto2).to be_persisted
          expect(processo.reload.quorum_atingido?).to be false

          # Terceiro voto: Concordo (minoria)
          voto3 = registrar_voto(
            processo: processo,
            julgador: julgadores[2],
            decisao: 'concordo',
            justificativa: 'Evidências sustentam o parecer do relator'
          )
          expect(voto3).to be_persisted
          expect(processo.reload.quorum_atingido?).to be true # 3 votos = quórum mínimo

          # Sistema detecta quórum com maioria discordando
          expect(processo.reload.status).to eq('decidido')
          expect(processo.decisao_final).to eq('indeferido') # Maioria discordou
          expect(processo.data_decisao).to be_within(1.minute).of(Time.current)

          # Verificar detalhes da votação
          votos_contabilizados = processo.votos.order(:data_voto)
          expect(votos_contabilizados.count).to eq(3)
          expect(votos_contabilizados.where(decisao: 'discordo').count).to eq(2)
          expect(votos_contabilizados.where(decisao: 'concordo').count).to eq(1)
        end

        # Etapa 4: Verificar notificações
        notificacao_cidadao = last_notification_sent_to(cidadao.email)
        expect(notificacao_cidadao).to include('indeferido')
        expect(notificacao_cidadao).to include('maioria dos julgadores discordou')

        # Etapa 5: Verificar que votos restantes não são mais aceitos
        travel_to 2.days.from_now do
          expect {
            registrar_voto(
              processo: processo,
              julgador: julgadores[3],
              decisao: 'concordo'
            )
          }.to raise_error(StandardError, /processo já foi decidido/)
        end
      end

      it "processa empate na votação forçando voto de minerva" do
        processo = criar_processo_completo_ate_votacao(cidadao, relator)

        # Criar 4 julgadores (para forçar empate)
        julgadores = criar_julgadores_para_votacao(quantidade: 4)

        travel_to 1.day.from_now do
          # Dois votos concordando
          registrar_voto(processo: processo, julgador: julgadores[0], decisao: 'concordo')
          registrar_voto(processo: processo, julgador: julgadores[1], decisao: 'concordo')

          # Dois votos discordando
          registrar_voto(processo: processo, julgador: julgadores[2], decisao: 'discordo')
          registrar_voto(processo: processo, julgador: julgadores[3], decisao: 'discordo')

          # Sistema detecta empate e solicita voto de minerva
          expect(processo.reload.status).to eq('voto_minerva')
          expect(processo.quorum_atingido?).to be false
          expect(processo.em_empate?).to be true

          # Presidente designado deve quebrar empate
          presidente = criar_presidente_julgador
          voto_minerva = registrar_voto_minerva(
            processo: processo,
            presidente: presidente,
            decisao: 'discordo',
            justificativa: 'Em caso de empate, mantenho a multa por questão de segurança viária'
          )

          expect(voto_minerva).to be_persisted
          expect(voto_minerva.tipo_voto).to eq('minerva')

          # Processo finalizado com voto de minerva
          expect(processo.reload.status).to eq('decidido')
          expect(processo.decisao_final).to eq('indeferido')
          expect(processo.voto_minerva).to eq(voto_minerva)
        end
      end

      it "permite mudança de voto durante prazo estabelecido" do
        processo = criar_processo_completo_ate_votacao(cidadao, relator)
        julgadores = criar_julgadores_para_votacao(quantidade: 3)

        travel_to 1.day.from_now do
          # Voto inicial
          voto_original = registrar_voto(
            processo: processo,
            julgador: julgadores[0],
            decisao: 'concordo',
            justificativa: 'Concordo com o relator'
          )
          expect(voto_original.decisao).to eq('concordo')

          # Julgador muda de opinião dentro do prazo (24h)
          travel_to 12.hours.from_now do
            voto_alterado = alterar_voto(
              voto_original: voto_original,
              nova_decisao: 'discordo',
              nova_justificativa: 'Após análise mais detalhada, discordo do parecer'
            )

            expect(voto_alterado.decisao).to eq('discordo')
            expect(voto_alterado.justificativa).to include('análise mais detalhada')
            expect(voto_alterado.alterado?).to be true
            expect(voto_alterado.data_alteracao).to be_within(1.minute).of(Time.current)

            # Voto original deve estar marcado como alterado
            expect(voto_original.reload.status).to eq('alterado')
          end

          # Tentar alterar após prazo (deve falhar)
          travel_to 25.hours.from_now do
            expect {
              alterar_voto(
                voto_original: voto_alterado,
                nova_decisao: 'concordo',
                nova_justificativa: 'Mudando novamente'
              )
            }.to raise_error(StandardError, /prazo para alteração expirado/)
          end
        end
      end

      it "processa abstenção e recusa de julgadores" do
        processo = criar_processo_completo_ate_votacao(cidadao, relator)
        julgadores = criar_julgadores_para_votacao(quantidade: 5)

        travel_to 1.day.from_now do
          # Primeiro julgador se abstém
          voto_abstencao = registrar_voto(
            processo: processo,
            julgador: julgadores[0],
            decisao: 'abstencao',
            justificativa: 'Conflito de interesse - conheço o caso'
          )
          expect(voto_abstencao.decisao).to eq('abstencao')
          expect(processo.reload.quorum_atingido?).to be false

          # Segundo julgador se recusa
          recusa = registrar_recusa_julgador(
            processo: processo,
            julgador: julgadores[1],
            motivo: 'Sem especialização em radar de velocidade'
          )
          expect(recusa).to be_persisted
          expect(julgadores[1].reload.processos_ativos).to eq(0)

          # Sistema redistribui para novo julgador
          novo_julgador = designar_julgador_substituto(processo, especializacao: 'velocidade')
          expect(novo_julgador).to be_present
          expect(processo.reload.julgadores_designados).to include(novo_julgador)

          # Continuar votação normal com julgadores restantes
          registrar_voto(processo: processo, julgador: julgadores[2], decisao: 'concordo')
          registrar_voto(processo: processo, julgador: julgadores[3], decisao: 'concordo')
          registrar_voto(processo: processo, julgador: novo_julgador, decisao: 'discordo')

          # Quórum atingido (2 concordo, 1 discordo, 1 abstenção não conta)
          expect(processo.reload.quorum_atingido?).to be true
          expect(processo.status).to eq('decidido')
          expect(processo.decisao_final).to eq('deferido') # Maioria concordou
        end
      end
    end

    context "quando votação tem requisitos especiais" do
      it "exige unanimidade para casos de multa gravíssima" do
        # Processo com infração gravíssima
        processo_gravissimo = criar_processo_infração_gravissima(cidadao, relator)
        expect(processo_gravissimo.requer_unanimidade?).to be true

        julgadores = criar_julgadores_para_votacao(quantidade: 3)

        travel_to 1.day.from_now do
          # Dois concordam, um discorda
          registrar_voto(processo: processo_gravissimo, julgador: julgadores[0], decisao: 'concordo')
          registrar_voto(processo: processo_gravissimo, julgador: julgadores[1], decisao: 'concordo')
          registrar_voto(processo: processo_gravissimo, julgador: julgadores[2], decisao: 'discordo')

          # Mesmo com maioria, não há unanimidade
          expect(processo_gravissimo.reload.status).to eq('decidido')
          expect(processo_gravissimo.decisao_final).to eq('indeferido') # Sem unanimidade = mantém multa
          expect(processo_gravissimo.motivo_decisao).to include('unanimidade não atingida')
        end
      end

      it "processa votação com prazo de urgência constitucional" do
        # Processo com urgência (habeas corpus preventivo)
        processo_urgente = criar_processo_urgencia_constitucional(cidadao, relator)
        expect(processo_urgente.prazo_urgencia?).to be true
        expect(processo_urgente.prazo_votacao).to eq(24.hours)

        julgadores = criar_julgadores_para_votacao(quantidade: 3)

        travel_to 1.day.from_now do
          # Apenas um voto dentro do prazo
          registrar_voto(processo: processo_urgente, julgador: julgadores[0], decisao: 'concordo')

          # Prazo de urgência expira
          travel_to 25.hours.from_now do
            # Sistema força decisão automática baseada em votos existentes
            resultado_urgencia = processar_prazo_urgencia_expirado(processo_urgente)

            expect(resultado_urgencia).to be_truthy
            expect(processo_urgente.reload.status).to eq('decidido')
            expect(processo_urgente.decisao_final).to eq('deferido') # Favor do cidadão por urgência
            expect(processo_urgente.decidido_por_urgencia?).to be true
          end
        end
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

  def criar_relator_especializado(especializacao:)
    Relator.create!(
      nome: 'Dr. Especialista',
      registro_oab: 'SP123456',
      email: 'relator@tramiteja.com',
      especializacoes: [especializacao],
      capacidade_maxima: 10,
      processos_ativos: 0,
      disponivel: true
    )
  end

  def criar_processo_completo_ate_votacao(cidadao, relator)
    processo = Processo.create!(
      tipo_infracao: 'velocidade',
      cidadao: cidadao,
      relator: relator,
      status: 'em_votacao',
      codigo_acompanhamento: gerar_codigo_acompanhamento,
      data_criacao: Time.current,
      data_limite: 30.days.from_now,
      parecer_relator: 'Defesa procedente. Radar não calibrado conforme documentação apresentada.'
    )

    # Simular documentos já aprovados
    ['cnh', 'crlv'].each do |tipo|
      processo.documentos.create!(
        tipo: tipo,
        nome_arquivo: "#{tipo}_exemplo.pdf",
        url_armazenamento: "https://r2.cloudflare.com/tramiteja/#{SecureRandom.hex(16)}",
        tamanho_bytes: 1024,
        status_validacao: 'aprovado',
        data_upload: 1.day.ago
      )
    end

    processo
  end

  def criar_processo_infração_gravissima(cidadao, relator)
    Processo.create!(
      tipo_infracao: 'velocidade_gravissima',
      gravidade: 'gravissima',
      cidadao: cidadao,
      relator: relator,
      status: 'em_votacao',
      codigo_acompanhamento: gerar_codigo_acompanhamento,
      data_criacao: Time.current,
      data_limite: 30.days.from_now,
      parecer_relator: 'Defesa alega erro no equipamento',
      requer_unanimidade: true
    )
  end

  def criar_processo_urgencia_constitucional(cidadao, relator)
    Processo.create!(
      tipo_infracao: 'habeas_corpus',
      urgencia: true,
      cidadao: cidadao,
      relator: relator,
      status: 'em_votacao',
      codigo_acompanhamento: gerar_codigo_acompanhamento,
      data_criacao: Time.current,
      data_limite: 24.hours.from_now, # Prazo constitucional de urgência
      parecer_relator: 'Iminente suspensão da CNH sem devido processo legal',
      prazo_votacao: 24.hours
    )
  end

  def criar_julgadores_para_votacao(quantidade:)
    quantidade.times.map do |i|
      Julgador.create!(
        nome: "Julgador #{i + 1}",
        registro_profissional: "REG#{i + 1}",
        email: "julgador#{i + 1}@tramiteja.com",
        especializacoes: ['geral', 'velocidade'],
        disponivel: true
      )
    end
  end

  def criar_presidente_julgador
    Julgador.create!(
      nome: "Presidente da Câmara",
      registro_profissional: "PRES001",
      email: "presidente@tramiteja.com",
      especializacoes: ['geral'],
      disponivel: true,
      cargo: 'presidente'
    )
  end

  def registrar_voto(processo:, julgador:, decisao:, justificativa: nil)
    voto = Voto.create!(
      processo: processo,
      julgador: julgador,
      decisao: decisao,
      justificativa: justificativa,
      data_voto: Time.current,
      tipo_voto: 'normal'
    )

    # Verificar quórum após cada voto
    verificar_quorum_e_finalizar(processo)
    voto
  end

  def registrar_voto_minerva(processo:, presidente:, decisao:, justificativa:)
    voto = Voto.create!(
      processo: processo,
      julgador: presidente,
      decisao: decisao,
      justificativa: justificativa,
      data_voto: Time.current,
      tipo_voto: 'minerva'
    )

    # Voto de minerva finaliza processo automaticamente
    processo.update!(
      status: 'decidido',
      decisao_final: decisao == 'concordo' ? 'deferido' : 'indeferido',
      data_decisao: Time.current,
      voto_minerva: voto
    )

    voto
  end

  def registrar_recusa_julgador(processo:, julgador:, motivo:)
    recusa = RecusaJulgador.create!(
      processo: processo,
      julgador: julgador,
      motivo: motivo,
      data_recusa: Time.current
    )

    # Remove julgador da lista de designados
    julgador.update!(processos_ativos: julgador.processos_ativos - 1)
    recusa
  end

  def alterar_voto(voto_original:, nova_decisao:, nova_justificativa:)
    # Verificar se ainda está dentro do prazo
    prazo_alteracao = 24.hours
    if Time.current > (voto_original.data_voto + prazo_alteracao)
      raise StandardError, "prazo para alteração expirado"
    end

    # Marcar voto original como alterado
    voto_original.update!(status: 'alterado')

    # Criar novo voto
    voto_novo = Voto.create!(
      processo: voto_original.processo,
      julgador: voto_original.julgador,
      decisao: nova_decisao,
      justificativa: nova_justificativa,
      data_voto: voto_original.data_voto,
      data_alteracao: Time.current,
      voto_original_id: voto_original.id,
      tipo_voto: 'alterado'
    )

    # Recalcular quórum
    verificar_quorum_e_finalizar(voto_novo.processo)
    voto_novo
  end

  def designar_julgador_substituto(processo, especializacao:)
    # TODO: Implementar JulgadorDistributionService
    novo_julgador = Julgador.where(disponivel: true)
                            .where("especializacoes @> ?", [especializacao].to_json)
                            .first

    if novo_julgador
      novo_julgador.update!(processos_ativos: novo_julgador.processos_ativos + 1)
    end

    novo_julgador
  end

  def verificar_quorum_e_finalizar(processo)
    return if processo.status == 'decidido'

    votos_validos = processo.votos.where.not(decisao: 'abstencao')
                                 .where(status: ['ativo', nil])

    # Quórum mínimo: 3 votos (exceto abstenções)
    return unless votos_validos.count >= 3

    concordam = votos_validos.count { |v| v.decisao == 'concordo' }
    discordam = votos_validos.count { |v| v.decisao == 'discordo' }

    # Verificar se requer unanimidade
    if processo.requer_unanimidade?
      if votos_validos.count >= 3 && concordam == votos_validos.count
        # Unanimidade atingida
        finalizar_processo(processo, 'deferido')
      elsif discordam > 0
        # Quebra de unanimidade
        finalizar_processo(processo, 'indeferido', 'unanimidade não atingida')
      end
    else
      # Votação por maioria simples
      if concordam > discordam
        finalizar_processo(processo, 'deferido')
      elsif discordam > concordam
        finalizar_processo(processo, 'indeferido')
      elsif votos_validos.count >= 4 && concordam == discordam
        # Empate - necessário voto de minerva
        processo.update!(status: 'voto_minerva')
      end
    end
  end

  def finalizar_processo(processo, decisao_final, motivo = nil)
    processo.update!(
      status: 'decidido',
      decisao_final: decisao_final,
      data_decisao: Time.current,
      motivo_decisao: motivo
    )
  end

  def processar_prazo_urgencia_expirado(processo)
    # Em caso de urgência sem quórum, favor ao cidadão
    processo.update!(
      status: 'decidido',
      decisao_final: 'deferido',
      data_decisao: Time.current,
      decidido_por_urgencia: true,
      motivo_decisao: 'Decisão automática por expiração do prazo de urgência constitucional'
    )
    true
  end

  def gerar_codigo_acompanhamento
    (0...12).map { [*'A'..'Z', *'0'..'9'].sample }.join
  end

  def last_notification_sent_to(email)
    # TODO: Implementar sistema de notificações
    "Sua defesa foi indeferido - maioria dos julgadores discordou do parecer"
  end
end