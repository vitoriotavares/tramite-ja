# TrâmiteJá - Backend API

API Rails 8 para plataforma digital de defesas de trânsito.

## 🔧 Versões

* **Ruby**: 3.3.6
* **Rails**: 8.0.2
* **PostgreSQL**: 16.x
* **Redis**: 7.x

## ⚡ Quick Start

```bash
# 1. Instalar dependências
bundle install

# 2. Configurar banco
rails db:create db:migrate db:seed

# 3. Iniciar servidor
rails server
```

## 🗄️ Configuração do Banco

### Development
```yaml
development:
  adapter: postgresql
  encoding: unicode
  database: tramiteja_development
  pool: 5
  username: <%= ENV['DB_USER'] || 'postgres' %>
  password: <%= ENV['DB_PASSWORD'] || '' %>
  host: <%= ENV['DB_HOST'] || 'localhost' %>
```

### Migrações Disponíveis
```bash
# Criar entidades principais
rails db:migrate:up VERSION=20250920170638  # Cidadãos
rails db:migrate:up VERSION=20250920170752  # Relatores
rails db:migrate:up VERSION=20250920170808  # Julgadores
rails db:migrate:up VERSION=20250920170822  # Processos
rails db:migrate:up VERSION=20250920170830  # Votos
rails db:migrate:up VERSION=20250920170839  # Documentos
rails db:migrate:up VERSION=20250920170848  # Notificações
rails db:migrate:up VERSION=20250920171005  # UUID constraints
```

## 🧪 Executar Testes

```bash
# Todos os testes
bundle exec rspec

# Por categoria
bundle exec rspec spec/models/      # Testes de modelo
bundle exec rspec spec/requests/    # Testes de API
bundle exec rspec spec/features/    # Testes integração

# Teste específico
bundle exec rspec spec/requests/api/v1/processos_spec.rb

# Com coverage
COVERAGE=true bundle exec rspec
```

## 📋 Endpoints Principais

### Processos (Público)
```
POST   /api/v1/processos              # Criar processo
GET    /api/v1/acompanhamento/:codigo # Rastreamento público
```

### Documentos
```
POST   /api/v1/processos/:id/documentos  # Upload documento
GET    /api/v1/documentos/:id           # Download documento
```

### Votação (Julgadores)
```
GET    /api/v1/processos/:id/votos     # Buscar processo para voto
POST   /api/v1/processos/:id/votos     # Registrar voto
```

### Dashboard (Relatores)
```
GET    /api/v1/relatores/:id/dashboard # Dashboard relator
GET    /api/v1/dashboard/metricas      # Métricas sistema
```

## 🔄 Serviços de Negócio

### ProcessoDistributionService
```ruby
# Distribuição inteligente baseada em especialização e carga
service = ProcessoDistributionService.new(processo: processo)
result = service.distribuir
```

### TriagemService
```ruby
# Validação automática de documentos
service = TriagemService.new(processo: processo)
result = service.executar_triagem
```

### VotacaoService
```ruby
# Detecção de quórum e finalização
service = VotacaoService.new(processo: processo)
result = service.verificar_quorum
```

### NotificationService
```ruby
# Sistema de notificações por email
service = NotificationService.new
service.enviar_notificacao_processo_criado(processo)
```

## 🏗️ Arquitetura

### Modelos Principais
- **Cidadao**: Usuários que submetem processos
- **Processo**: Casos de defesa com workflow de estados
- **Relator**: Especialistas que analisam processos
- **Julgador**: Membros que votam colegiadamente
- **Voto**: Decisões individuais com quórum
- **Documento**: Arquivos anexados com validação
- **Notificacao**: Sistema de comunicação

### Estados do Processo
```
rascunho → triagem → distribuido → em_analise → em_votacao → decidido
                   ↘️ rejeitado
```

### Especializações
- **velocidade**: Infrações de velocidade
- **rodizio**: Rodízio municipal
- **semaforo**: Desrespeito ao semáforo
- **geral**: Todos os tipos

## 🔐 Autenticação

### OAuth Gov.br (Planejado)
```ruby
# config/initializers/omniauth.rb
# Configuração comentada até ter provider específico
```

### JWT (Desenvolvimento)
```ruby
# Gerar token para testes
payload = { user_id: 1, role: 'relator' }
token = JWT.encode(payload, Rails.application.secret_key_base)
```

## 📊 Monitoramento

### Health Check
```bash
curl http://localhost:3000/health
```

### Métricas de Performance
```bash
# Tempo de resposta das APIs
curl -w "%{time_total}" http://localhost:3000/api/v1/processos

# Status dos serviços
rails runner "puts Redis.current.ping"  # Redis
rails runner "puts ActiveRecord::Base.connection.active?"  # DB
```

## 🐛 Debug e Logs

### Console Rails
```bash
rails console

# Exemplos úteis
Processo.count
Relator.disponivel.count
Voto.joins(:processo).where(processos: { status: :em_votacao }).count
```

### Logs Detalhados
```bash
# Seguir logs em tempo real
tail -f log/development.log

# Filtrar por nível
grep "ERROR" log/development.log
grep "ProcessoDistributionService" log/development.log
```

### Background Jobs (Sidekiq)
```bash
# Iniciar Sidekiq
bundle exec sidekiq

# Monitor web (desenvolvimento)
# http://localhost:4567
```

## 🚀 Deploy

### Produção (Railway/Heroku)
```bash
# Preparar assets
rails assets:precompile

# Migrar banco
rails db:migrate

# Iniciar
rails server -e production
```

### Docker
```bash
# Build
docker build -t tramiteja-api .

# Run
docker run -p 3000:3000 \
  -e DATABASE_URL=postgresql://user:pass@host/db \
  -e REDIS_URL=redis://host:6379/0 \
  tramiteja-api
```

## 🔧 Ferramentas de Desenvolvimento

### Linting
```bash
bundle exec rubocop              # Verificar style
bundle exec rubocop -a           # Auto-corrigir
bundle exec rubocop --only Style # Apenas style
```

### Security
```bash
bundle exec brakeman             # Scan vulnerabilidades
bundle exec bundler-audit        # Audit gems
```

### Performance
```bash
# Profiling (adicionar gem rack-mini-profiler)
# Acessar /?pp=help para opções
```

## 📈 Métricas de Qualidade

### Cobertura de Testes
- **Meta**: 85% de cobertura
- **Crítico**: 100% para payment, voting, distribution

### Performance
- **API Response**: < 200ms (target)
- **Database Queries**: < 100ms
- **Background Jobs**: < 30s

### Padrões de Código
- Seguir Rails conventions
- Métodos < 15 linhas
- Classes < 200 linhas
- Nomes descritivos em português para domínio
