# TrâmiteJá - Exemplos de API

Exemplos práticos para testar e usar a API do TrâmiteJá.

## 🚀 Setup Rápido para Testes

```bash
# 1. Subir o backend
cd backend
bundle exec rails server

# 2. Em outro terminal, popular dados de teste
bundle exec rails db:seed

# 3. Testar conectividade
curl http://localhost:3000/api/v1/processos
```

## 📋 Endpoints Principais

### 1. **Criar Processo** (Público - Sem Auth)

```bash
# POST /api/v1/processos
curl -X POST http://localhost:3000/api/v1/processos \
  -H "Content-Type: application/json" \
  -d '{
    "processo": {
      "tipo_infracao": "velocidade",
      "cidadao_attributes": {
        "nome": "João Silva",
        "cpf": "12345678901",
        "email": "joao@example.com",
        "telefone": "11999999999"
      }
    }
  }'
```

**Resposta esperada**:
```json
{
  "id": "uuid-do-processo",
  "codigo_acompanhamento": "TR2024001234",
  "tipo_infracao": "velocidade",
  "status": "rascunho",
  "data_criacao": "2024-09-20T14:30:00Z",
  "data_limite": "2024-09-25T14:30:00Z",
  "cidadao": {
    "nome": "João Silva",
    "email": "joao@example.com"
  }
}
```

### 2. **Acompanhar Processo** (Público - Sem Auth)

```bash
# GET /api/v1/acompanhamento/:codigo
curl http://localhost:3000/api/v1/acompanhamento/TR2024001234
```

**Resposta esperada**:
```json
{
  "processo": {
    "codigo_acompanhamento": "TR2024001234",
    "tipo_infracao": "velocidade",
    "status": "em_analise",
    "data_criacao": "2024-09-20T14:30:00Z",
    "data_limite": "2024-09-25T14:30:00Z",
    "cidadao_nome": "João Silva",
    "relator_nome": "Dr. Maria Santos"
  },
  "timeline": [
    {
      "status": "rascunho",
      "data": "2024-09-20T14:30:00Z",
      "descricao": "Processo criado"
    },
    {
      "status": "triagem",
      "data": "2024-09-20T15:00:00Z",
      "descricao": "Documentos validados"
    },
    {
      "status": "distribuido",
      "data": "2024-09-20T15:30:00Z",
      "descricao": "Distribuído para relator"
    }
  ]
}
```

### 3. **Upload de Documento**

```bash
# POST /api/v1/processos/:id/documentos
curl -X POST http://localhost:3000/api/v1/processos/uuid-do-processo/documentos \
  -H "Authorization: Bearer $TOKEN" \
  -F "documento[tipo]=cnh" \
  -F "documento[arquivo]=@/path/to/cnh.pdf"
```

### 4. **Dashboard do Relator**

```bash
# GET /api/v1/relatores/:id/dashboard
curl http://localhost:3000/api/v1/relatores/uuid-relator/dashboard \
  -H "Authorization: Bearer $TOKEN"
```

### 5. **Registrar Voto**

```bash
# POST /api/v1/processos/:id/votos
curl -X POST http://localhost:3000/api/v1/processos/uuid-processo/votos \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{
    "voto": {
      "decisao": "concordo",
      "justificativa": "Documentos completos e defesa procedente",
      "tempo_analise": 1800
    }
  }'
```

## 🧪 Scripts de Teste

### Script 1: Fluxo Completo de Cidadão

```bash
#!/bin/bash
# test_citizen_flow.sh

BASE_URL="http://localhost:3000/api/v1"

echo "🧪 Testando fluxo completo do cidadão..."

# 1. Criar processo
echo "1. Criando processo..."
RESPONSE=$(curl -s -X POST $BASE_URL/processos \
  -H "Content-Type: application/json" \
  -d '{
    "processo": {
      "tipo_infracao": "velocidade",
      "cidadao_attributes": {
        "nome": "Teste Cidadão",
        "cpf": "12345678901",
        "email": "teste@example.com",
        "telefone": "11999999999"
      }
    }
  }')

CODIGO=$(echo $RESPONSE | jq -r '.codigo_acompanhamento')
PROCESSO_ID=$(echo $RESPONSE | jq -r '.id')

echo "✅ Processo criado: $CODIGO"

# 2. Acompanhar processo
echo "2. Acompanhando processo..."
curl -s $BASE_URL/acompanhamento/$CODIGO | jq '.processo.status'

echo "✅ Fluxo testado com sucesso!"
```

### Script 2: Teste de Performance

```bash
#!/bin/bash
# test_performance.sh

BASE_URL="http://localhost:3000/api/v1"

echo "🚀 Testando performance da API..."

# Testar tempo de resposta
echo "Testando GET /processos..."
curl -w "%{time_total}s\n" -s -o /dev/null $BASE_URL/processos

echo "Testando POST /processos..."
curl -w "%{time_total}s\n" -s -o /dev/null -X POST $BASE_URL/processos \
  -H "Content-Type: application/json" \
  -d '{"processo":{"tipo_infracao":"velocidade","cidadao_attributes":{"nome":"Test","cpf":"12345678901","email":"test@test.com","telefone":"11999999999"}}}'

echo "✅ Testes de performance concluídos!"
```

## 🔐 Autenticação para Testes

### Gerar Token JWT (Desenvolvimento)

```bash
# No console Rails
cd backend
bundle exec rails console

# Gerar token para relator
payload = { user_id: 1, role: 'relator', exp: 1.hour.from_now.to_i }
token = JWT.encode(payload, Rails.application.secret_key_base)
puts token

# Usar o token nos requests
export TOKEN="eyJ0eXAiOiJKV1QiLCJhbGc..."
```

### Usar Token em Requests

```bash
# Exemplo com autorização
curl -H "Authorization: Bearer $TOKEN" \
     http://localhost:3000/api/v1/relatores/1/dashboard
```

## 📊 Testando com Dados de Exemplo

### Criar Dados de Teste via Seeds

```bash
cd backend

# Executar seeds (cria dados de exemplo)
bundle exec rails db:seed

# Verificar dados criados
bundle exec rails console
> Cidadao.count
> Processo.count
> Relator.count
```

### Dados Criados pelos Seeds
- **3 Relatores** com especializações diferentes
- **5 Julgadores** para votação
- **10 Processos** em diferentes status
- **1 Cidadão** para cada processo

## 🔍 Debug e Monitoramento

### Verificar Logs Durante Testes

```bash
# Em um terminal separado
tail -f backend/log/development.log

# Filtrar apenas erros
tail -f backend/log/development.log | grep ERROR

# Filtrar por serviço específico
tail -f backend/log/development.log | grep "ProcessoDistributionService"
```

### Verificar Performance de Queries

```bash
# No console Rails
cd backend
bundle exec rails console

# Habilitar log de queries
ActiveRecord::Base.logger.level = 0

# Testar query específica
Processo.includes(:cidadao, :relator).where(status: 'em_analise')
```

## 🐛 Exemplos de Tratamento de Erro

### Erro: Dados Inválidos

```bash
# Tentar criar processo sem dados obrigatórios
curl -X POST http://localhost:3000/api/v1/processos \
  -H "Content-Type: application/json" \
  -d '{
    "processo": {
      "tipo_infracao": "invalido"
    }
  }'
```

**Resposta esperada**:
```json
{
  "error": "Dados inválidos",
  "details": {
    "cidadao.nome": ["é obrigatório"],
    "cidadao.cpf": ["é obrigatório"],
    "tipo_infracao": ["não está incluído na lista"]
  }
}
```

### Erro: Processo Não Encontrado

```bash
curl http://localhost:3000/api/v1/acompanhamento/CODIGO_INEXISTENTE
```

**Resposta esperada**:
```json
{
  "error": "Processo não encontrado",
  "message": "O código de acompanhamento fornecido não existe"
}
```

## 📱 Testando Frontend + Backend

### 1. Subir Ambos Serviços

```bash
# Terminal 1 - Backend
cd backend
bundle exec rails server

# Terminal 2 - Frontend
cd frontend
npm run dev
```

### 2. Testar Integração

```bash
# Verificar se frontend consegue acessar API
curl http://localhost:3001/api/proxy/processos

# Testar upload de arquivo via frontend
# (usar interface web em http://localhost:3001)
```

## 📈 Métricas e Monitoramento

### Endpoints de Saúde

```bash
# Health check básico
curl http://localhost:3000/health

# Status dos serviços
curl http://localhost:3000/api/v1/dashboard/status
```

### Métricas de Uso

```bash
# Estatísticas gerais
curl http://localhost:3000/api/v1/dashboard/metricas \
  -H "Authorization: Bearer $TOKEN"
```

---

💡 **Dica**: Salve estes comandos em scripts `.sh` para facilitar os testes durante o desenvolvimento!