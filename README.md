# TrâmiteJá - Setup Local

Plataforma digital gratuita para defesas de trânsito com processamento inteligente e votação colegiada.

## 📋 Pré-requisitos

### Sistema Operacional
- **macOS**, **Linux** ou **Windows** (com WSL2 recomendado)

### Ferramentas Necessárias

#### 1. **Ruby** (Backend)
```bash
# macOS com Homebrew
brew install ruby
# ou usar rbenv para gerenciar versões
brew install rbenv
rbenv install 3.3.6
rbenv global 3.3.6
```

#### 2. **Node.js** (Frontend)
```bash
# macOS com Homebrew
brew install node
# ou usar nvm
brew install nvm
nvm install 20
nvm use 20
```

#### 3. **PostgreSQL** (Banco de Dados)
```bash
# macOS com Homebrew
brew install postgresql@16
brew services start postgresql@16

# Linux (Ubuntu/Debian)
sudo apt update
sudo apt install postgresql postgresql-contrib

# Windows (com chocolatey)
choco install postgresql
```

#### 4. **Redis** (Cache e Background Jobs)
```bash
# macOS
brew install redis
brew services start redis

# Linux
sudo apt install redis-server

# Windows
choco install redis-64
```

## 🚀 Instalação

### 1. **Clone o Repositório**
```bash
git clone <repository-url>
cd tramite_ja_spec_kit
```

### 2. **Setup do Backend (Rails 8)**

#### a) Entre no diretório do backend
```bash
cd backend
```

#### b) Instale as dependências
```bash
# Instalar bundler se não tiver
gem install bundler

# Instalar gems
bundle install
```

#### c) Configure o banco de dados
```bash
# Criar arquivo de configuração local (opcional)
cp config/database.yml.example config/database.yml

# Criar banco de dados
rails db:create

# Executar migrações
rails db:migrate

# Popular com dados de exemplo
rails db:seed
```

#### d) Configure variáveis de ambiente
```bash
# Criar arquivo .env (se necessário)
cp .env.example .env

# Editar .env com suas configurações:
# DATABASE_URL=postgresql://user:password@localhost/tramiteja_development
# REDIS_URL=redis://localhost:6379/0
# SECRET_KEY_BASE=sua_chave_secreta
```

#### e) Inicie o servidor Rails
```bash
# Servidor de desenvolvimento
rails server
# ou
./bin/dev

# O backend estará disponível em: http://localhost:3000
```

### 3. **Setup do Frontend (Next.js 14)**

#### a) Em outro terminal, entre no diretório do frontend
```bash
cd frontend
```

#### b) Instale as dependências
```bash
npm install
# ou
yarn install
```

#### c) Configure variáveis de ambiente
```bash
# Criar arquivo .env.local
cp .env.example .env.local

# Editar .env.local:
NEXT_PUBLIC_API_URL=http://localhost:3000/api/v1
NEXT_PUBLIC_SOCKET_URL=http://localhost:3000
```

#### d) Inicie o servidor Next.js
```bash
npm run dev
# ou
yarn dev

# O frontend estará disponível em: http://localhost:3001
```

## 🧪 Executar Testes

### Backend (RSpec)
```bash
cd backend

# Executar todos os testes
bundle exec rspec

# Executar testes específicos
bundle exec rspec spec/models/
bundle exec rspec spec/requests/
bundle exec rspec spec/features/

# Com coverage
COVERAGE=true bundle exec rspec
```

### Frontend (Jest)
```bash
cd frontend

# Executar testes
npm test
# ou
yarn test

# Executar com watch mode
npm test -- --watch
```

## 🗄️ Configuração do Banco de Dados

### PostgreSQL Local
1. **Criar usuário** (se necessário):
```sql
-- Conectar como superusuário
sudo -u postgres psql

-- Criar usuário
CREATE USER tramiteja WITH PASSWORD 'senha123';
ALTER USER tramiteja CREATEDB;
```

2. **Configurar `config/database.yml`**:
```yaml
development:
  adapter: postgresql
  encoding: unicode
  database: tramiteja_development
  pool: 5
  username: tramiteja
  password: senha123
  host: localhost
```

### Dados de Exemplo
O comando `rails db:seed` criará:
- **Relatores** com diferentes especializações
- **Julgadores** para votação colegiada
- **Processos** de exemplo em diferentes status
- **Cidadãos** de teste

## 🔧 Comandos Úteis

### Backend
```bash
# Console Rails
rails console

# Verificar rotas
rails routes

# Reset completo do banco
rails db:drop db:create db:migrate db:seed

# Executar linter
bundle exec rubocop

# Corrigir problemas de style
bundle exec rubocop -a
```

### Frontend
```bash
# Verificar tipos TypeScript
npm run type-check

# Linter
npm run lint

# Corrigir problemas de lint
npm run lint:fix

# Formatar código
npm run format
```

## 🌐 URLs de Acesso

Após subir os serviços:

### Frontend (Next.js)
- **URL**: http://localhost:3001
- **Páginas principais**:
  - `/` - Página inicial (formulário de processo)
  - `/acompanhamento` - Rastreamento público
  - `/relator` - Dashboard do relator
  - `/julgador` - Interface de votação
  - `/admin` - Dashboard administrativo

### Backend (Rails API)
- **URL**: http://localhost:3000
- **Endpoints principais**:
  - `GET /api/v1/processos` - Listar processos
  - `POST /api/v1/processos` - Criar processo
  - `GET /api/v1/acompanhamento/:codigo` - Rastreamento público
  - `GET /api/v1/dashboard/metricas` - Métricas administrativas

### Documentação da API
- **URL**: http://localhost:3000/api-docs (quando implementado)

## 🔍 Troubleshooting

### Problemas Comuns

#### 1. **Erro de conexão com PostgreSQL**
```bash
# Verificar se PostgreSQL está rodando
brew services list | grep postgresql
# ou
sudo systemctl status postgresql

# Reiniciar PostgreSQL
brew services restart postgresql
```

#### 2. **Erro de dependências Ruby**
```bash
# Atualizar bundler
gem update bundler

# Limpar cache e reinstalar
bundle clean --force
bundle install
```

#### 3. **Erro de dependências Node.js**
```bash
# Limpar cache npm
npm cache clean --force
rm -rf node_modules package-lock.json
npm install
```

#### 4. **Porta já em uso**
```bash
# Verificar processos na porta 3000
lsof -ti:3000

# Matar processo se necessário
kill -9 $(lsof -ti:3000)
```

### Logs de Debug
```bash
# Backend - logs detalhados
tail -f log/development.log

# Frontend - logs no console do navegador
# Abrir DevTools (F12) > Console
```

## 📝 Desenvolvimento

### Estrutura do Projeto
```
tramite_ja_spec_kit/
├── backend/          # Rails 8 API
│   ├── app/
│   │   ├── models/
│   │   ├── controllers/
│   │   └── services/
│   ├── spec/         # Testes RSpec
│   └── db/           # Migrações e seeds
├── frontend/         # Next.js 14
│   ├── src/
│   │   ├── components/
│   │   ├── pages/
│   │   └── services/
│   └── __tests__/    # Testes Jest
└── specs/            # Documentação do projeto
```

### Workflow de Desenvolvimento
1. **Criar branch** para feature: `git checkout -b feature/nova-funcionalidade`
2. **Escrever testes** primeiro (TDD)
3. **Implementar** funcionalidade
4. **Rodar testes** e verificar qualidade
5. **Commit** e **push**
6. **Criar PR** para revisão

### Qualidade de Código
- **Cobertura de testes**: Mínimo 70% (meta 85%)
- **Linting**: Deve passar sem erros
- **Performance**: APIs < 200ms, páginas < 1s
- **Acessibilidade**: WCAG 2.1 AA

## 📞 Suporte

Para dúvidas sobre setup local:
1. Verificar logs de erro
2. Consultar troubleshooting acima
3. Verificar issues no repositório
4. Contato: dev@tramiteja.com.br

---

**TrâmiteJá** - Digitalizando a defesa de trânsito no Brasil 🇧🇷