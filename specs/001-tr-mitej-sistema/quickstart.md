# Quickstart: TrâmiteJá Sistema de Defesa Prévia

## Cenários de Validação End-to-End

### Cenário 1: Fluxo Completo do Cidadão - Defesa Bem-sucedida

**Objetivo**: Validar o fluxo completo desde o protocolo até a decisão final favorável

**Pré-condições**:
- Sistema inicializado com usuários de teste
- Relator disponível com especialização em 'velocidade'
- 3 julgadores disponíveis
- OAuth Gov.br configurado em modo test

**Passos**:

1. **Registro do Cidadão**
   ```bash
   # Registrar cidadão via OAuth Gov.br (mock)
   POST /api/v1/cidadaos
   {
     "cpf": "12345678901",
     "nome_completo": "João Silva",
     "email": "joao@example.com",
     "oauth_gov_id": "gov_123456"
   }
   ```

2. **Protocolo da Defesa (Gratuito)**
   ```bash
   # Criar processo de defesa imediatamente
   POST /api/v1/processos
   {
     "tipo_infracao": "velocidade",
     "cidadao_id": "{cidadao_id}"
   }

   # Upload de documentos obrigatórios
   POST /api/v1/processos/{processo_id}/documentos
   Content-Type: multipart/form-data
   arquivo: [CNH.pdf]
   tipo: "cnh"

   POST /api/v1/processos/{processo_id}/documentos
   Content-Type: multipart/form-data
   arquivo: [CRLV.pdf]
   tipo: "crlv"
   ```

3. **Triagem Automatizada**
   ```bash
   # Sistema automaticamente valida documentos e aprova
   # Verifica se documentos CNH e CRLV estão presentes
   # Verifica prazo legal (30 dias)
   # Atualiza status para 'triagem' → 'distribuido'
   ```

4. **Distribuição Automática**
   ```bash
   # Sistema distribui para relator com menor carga
   GET /api/v1/relatores?especialização=velocidade&disponivel=true
   # Atribui ao relator com menor processos_ativos
   # Envia notificação para relator
   ```

5. **Análise do Relator**
   ```bash
   # Relator acessa dashboard
   GET /api/v1/relatores/{relator_id}/dashboard

   # Relator adiciona parecer
   PATCH /api/v1/processos/{processo_id}
   {
     "status": "em_votacao",
     "parecer_relator": "Defesa procedente. Radar não calibrado conforme documentação apresentada."
   }
   ```

6. **Votação Colegiada**
   ```bash
   # Julgador 1 vota
   POST /api/v1/processos/{processo_id}/votos
   {
     "decisao": "concordo",
     "julgador_id": "{julgador_1_id}",
     "justificativa": "Concordo com o parecer do relator"
   }

   # Julgador 2 vota
   POST /api/v1/processos/{processo_id}/votos
   {
     "decisao": "concordo",
     "julgador_id": "{julgador_2_id}"
   }

   # Sistema detecta quórum (2/3 = maioria)
   # Atualiza status para 'decidido'
   # Define decisao_final = 'deferido'
   ```

7. **Acompanhamento pelo Cidadão**
   ```bash
   # Cidadão consulta processo sem login
   GET /api/v1/acompanhamento/{codigo_acompanhamento}

   # Verifica timeline completa
   # Faz download da decisão final
   ```

**Resultado Esperado**:
- Processo completo em < 5 dias
- Status final: 'decidido'
- Decisão final: 'deferido'
- Cidadão notificado por email
- Documentos disponíveis para download

---

### Cenário 2: Rejeição na Triagem - Documentos Insuficientes

**Objetivo**: Validar rejeição automática por documentação incompleta

**Passos**:

1. **Protocolo com Documentação Incompleta**
   ```bash
   # Criar processo
   POST /api/v1/processos
   {
     "tipo_infracao": "rodizio",
     "cidadao_id": "{cidadao_id}"
   }

   # Upload apenas CNH (faltando CRLV)
   POST /api/v1/processos/{processo_id}/documentos
   Content-Type: multipart/form-data
   arquivo: [CNH.pdf]
   tipo: "cnh"
   ```

2. **Triagem Rejeita Automaticamente**
   ```bash
   # Sistema detecta documentação incompleta
   # Atualiza status para 'rejeitado'
   # Define justificativa_rejeicao
   ```

**Resultado Esperado**:
- Status: 'rejeitado'
- Justificativa clara sobre documentos faltantes
- Cidadão notificado por email
- Cidadão pode criar novo processo imediatamente (gratuito)

---

### Cenário 3: Votação com Discordância - Processo Indeferido

**Objetivo**: Validar votação com resultado desfavorável

**Passos**:

1. **Processo até Votação** (seguir passos 1-5 do Cenário 1)

2. **Votação com Discordância**
   ```bash
   # Julgador 1 discorda
   POST /api/v1/processos/{processo_id}/votos
   {
     "decisao": "discordo",
     "julgador_id": "{julgador_1_id}",
     "justificativa": "Documentação insuficiente para comprovar defeito no radar"
   }

   # Julgador 2 discorda
   POST /api/v1/processos/{processo_id}/votos
   {
     "decisao": "discordo",
     "julgador_id": "{julgador_2_id}",
     "justificativa": "Infração confirmada pela documentação"
   }

   # Sistema detecta maioria contrária
   # Define decisao_final = 'indeferido'
   ```

**Resultado Esperado**:
- Status: 'decidido'
- Decisão final: 'indeferido'
- Justificativas dos votos registradas
- Cidadão notificado sobre resultado

---

### Cenário 4: Dashboard Gerencial - Métricas em Tempo Real

**Objetivo**: Validar funcionamento do dashboard administrativo

**Passos**:

1. **Consultar Métricas**
   ```bash
   GET /api/v1/dashboard/metricas
   ```

2. **Validar Dados Retornados**
   ```json
   {
     "processos_hoje": 15,
     "processos_pendentes": 8,
     "tempo_medio_processamento": 3.2,
     "taxa_deferimento": 68.5,
     "alertas_prazo": 2
   }
   ```

**Resultado Esperado**:
- Métricas atualizadas em tempo real
- Cálculos corretos baseados nos dados do BD
- Interface responsiva para gestores

---

### Cenário 5: Real-time - Notificações via Socket.io

**Objetivo**: Validar notificações em tempo real

**Passos**:

1. **Conectar WebSocket**
   ```javascript
   const socket = io('ws://localhost:3001');

   // Autenticar julgador
   socket.emit('authenticate', { julgador_id: 'uuid' });

   // Escutar novos processos para votação
   socket.on('novo_processo_votacao', (data) => {
     console.log('Novo processo:', data.processo_id);
   });
   ```

2. **Testar Notificação**
   ```bash
   # Relator submete parecer
   PATCH /api/v1/processos/{processo_id}
   {
     "status": "em_votacao"
   }

   # Verificar se julgadores recebem notificação via WebSocket
   ```

**Resultado Esperado**:
- Notificações instantâneas para julgadores
- Atualizações de status em tempo real
- Contadores de votos atualizados automaticamente

---

### Cenário 6: Performance - Carga de 100 Processos Simultâneos

**Objetivo**: Validar performance sob carga

**Passos**:

1. **Criar 100 Processos Simultaneamente**
   ```bash
   # Script de carga
   for i in {1..100}; do
     curl -X POST /api/v1/processos \
       -H "Content-Type: application/json" \
       -d "{\"tipo_infracao\":\"velocidade\",\"cidadao_id\":\"${cidadao_ids[$i]}\"}" &
   done
   wait
   ```

2. **Verificar Tempos de Resposta**
   - APIs < 200ms
   - Distribuição automática < 5s
   - Notificações entregues < 1s

**Resultado Esperado**:
- Todos os processos criados com sucesso
- Distribuição balanceada entre relatores
- Performance dentro dos SLAs constitucionais

---

## Testes de Integração Críticos

### Teste 1: Integração Gov.br OAuth
```bash
# Simular callback OAuth
GET /auth/govbr/callback?code=authorization_code&state=csrf_token

# Verificar criação/atualização do cidadão
# Validar dados recebidos do Gov.br
```

### Teste 2: Integração R2 Cloudflare
```bash
# Upload de arquivo
POST /api/v1/processos/{id}/documentos
Content-Type: multipart/form-data

# Verificar:
# - Arquivo salvo no R2
# - URL de acesso gerada
# - Metadados corretos no BD
```

### Teste 3: Socket.io Real-time
```bash
# Conectar WebSocket
# Submeter processo para votação
# Verificar notificações em tempo real para julgadores
```

---

## Checklist de Validação Final

### Funcionalidades Core
- [ ] Cadastro via Gov.br OAuth funcional
- [ ] Criação gratuita de processos funcionando
- [ ] Upload de documentos para R2 Cloudflare
- [ ] Triagem automatizada com validações
- [ ] Distribuição inteligente entre relatores
- [ ] Sistema de votação com quórum
- [ ] Portal público de acompanhamento
- [ ] Dashboard gerencial com métricas
- [ ] Notificações por email funcionais
- [ ] WebSocket para updates em tempo real

### Performance
- [ ] APIs respondem < 200ms
- [ ] Upload de arquivos < 5s (10MB)
- [ ] Página carrega < 1s
- [ ] Sistema suporta 100 usuários simultâneos
- [ ] Processo completo em < 5 dias

### Segurança
- [ ] Autenticação Gov.br obrigatória
- [ ] Autorização por tipo de usuário
- [ ] Dados sensíveis criptografados
- [ ] Logs de auditoria funcionais
- [ ] Headers de segurança configurados

### UX/UI
- [ ] Interface 100% em português BR
- [ ] Design responsivo (mobile-first)
- [ ] Máximo 3 cliques para qualquer ação
- [ ] Acessibilidade WCAG 2.1 AA
- [ ] Feedback visual para todas as ações

### Compliance
- [ ] LGPD: Consentimento e portabilidade
- [ ] Trilha de auditoria completa
- [ ] Backup automatizado
- [ ] Retenção de dados configurada
- [ ] Relatórios de compliance disponíveis

### Acesso Gratuito
- [ ] Nenhuma barreira de pagamento para cidadãos
- [ ] Processo de submissão completamente gratuito
- [ ] Múltiplas submissões permitidas sem custo
- [ ] Acompanhamento público sem restrições
- [ ] Download de documentos sempre disponível