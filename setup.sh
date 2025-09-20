#!/bin/bash

# TrâmiteJá - Script de Setup Local
# Este script automatiza a instalação completa do ambiente de desenvolvimento

set -e  # Parar em caso de erro

echo "🚀 TrâmiteJá - Setup Local"
echo "=========================="
echo ""

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Função para log
log() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

# Verificar se estamos no diretório correto
if [ ! -f "CLAUDE.md" ]; then
    error "Execute este script na raiz do projeto TrâmiteJá"
fi

# 1. Verificar dependências do sistema
log "Verificando dependências do sistema..."

# Verificar Ruby
if ! command -v ruby &> /dev/null; then
    error "Ruby não encontrado. Instale Ruby 3.3.6"
fi

RUBY_VERSION=$(ruby -v | cut -d' ' -f2)
log "Ruby encontrado: $RUBY_VERSION"

# Verificar Node.js
if ! command -v node &> /dev/null; then
    error "Node.js não encontrado. Instale Node.js 20.x"
fi

NODE_VERSION=$(node -v)
log "Node.js encontrado: $NODE_VERSION"

# Verificar PostgreSQL
if ! command -v psql &> /dev/null; then
    error "PostgreSQL não encontrado. Instale PostgreSQL 16.x"
fi

PG_VERSION=$(psql --version | cut -d' ' -f3)
log "PostgreSQL encontrado: $PG_VERSION"

# Verificar Redis
if ! command -v redis-cli &> /dev/null; then
    warn "Redis não encontrado. Algumas funcionalidades podem não funcionar."
else
    REDIS_VERSION=$(redis-cli --version | cut -d' ' -f2)
    log "Redis encontrado: $REDIS_VERSION"
fi

echo ""

# 2. Setup do Backend
log "Configurando Backend (Rails 8)..."
cd backend

# Verificar se bundler está instalado
if ! command -v bundle &> /dev/null; then
    log "Instalando Bundler..."
    gem install bundler
fi

# Instalar gems
log "Instalando dependências Ruby..."
bundle install

# Copiar arquivo de configuração de exemplo
if [ ! -f ".env" ]; then
    log "Criando arquivo .env..."
    cp .env.example .env
    warn "Configure as variáveis de ambiente em backend/.env"
fi

# Configurar banco de dados
log "Configurando banco de dados..."

# Verificar se PostgreSQL está rodando
if ! pg_isready -q; then
    warn "PostgreSQL não está rodando. Tentando iniciar..."

    # Tentar iniciar no macOS
    if command -v brew &> /dev/null; then
        brew services start postgresql@16 || brew services start postgresql
    fi

    # Verificar novamente
    if ! pg_isready -q; then
        error "Não foi possível conectar ao PostgreSQL. Inicie manualmente."
    fi
fi

# Criar banco de dados
log "Criando banco de dados..."
bundle exec rails db:create || warn "Banco já existe ou erro na criação"

# Executar migrações
log "Executando migrações..."
bundle exec rails db:migrate

# Popular com dados de exemplo
log "Populando banco com dados de exemplo..."
bundle exec rails db:seed

# Executar testes para verificar se está tudo ok
log "Executando testes básicos..."
bundle exec rspec spec/models/cidadao_spec.rb -f doc

cd ..

echo ""

# 3. Setup do Frontend
log "Configurando Frontend (Next.js 14)..."
cd frontend

# Verificar se yarn está disponível
if command -v yarn &> /dev/null; then
    PACKAGE_MANAGER="yarn"
else
    PACKAGE_MANAGER="npm"
fi

log "Usando $PACKAGE_MANAGER para gerenciar dependências..."

# Instalar dependências
log "Instalando dependências Node.js..."
if [ "$PACKAGE_MANAGER" = "yarn" ]; then
    yarn install
else
    npm install
fi

# Copiar arquivo de configuração de exemplo
if [ ! -f ".env.local" ]; then
    log "Criando arquivo .env.local..."
    cp .env.example .env.local
fi

# Verificar se TypeScript compila
log "Verificando TypeScript..."
if [ "$PACKAGE_MANAGER" = "yarn" ]; then
    yarn type-check
else
    npm run type-check
fi

cd ..

echo ""

# 4. Verificações finais
log "Executando verificações finais..."

# Verificar conectividade do banco
log "Testando conexão com banco de dados..."
cd backend
bundle exec rails runner "puts 'Conexão OK: ' + ActiveRecord::Base.connection.active?.to_s" || error "Erro na conexão com banco"
cd ..

# Criar script de inicialização
log "Criando scripts de conveniência..."

cat > start-backend.sh << 'EOF'
#!/bin/bash
echo "🚀 Iniciando Backend (Rails)..."
cd backend
bundle exec rails server
EOF

cat > start-frontend.sh << 'EOF'
#!/bin/bash
echo "🚀 Iniciando Frontend (Next.js)..."
cd frontend
if command -v yarn &> /dev/null; then
    yarn dev
else
    npm run dev
fi
EOF

cat > start-all.sh << 'EOF'
#!/bin/bash
echo "🚀 Iniciando TrâmiteJá completo..."
echo "Backend estará disponível em: http://localhost:3000"
echo "Frontend estará disponível em: http://localhost:3001"
echo ""

# Função para cleanup
cleanup() {
    echo "Parando serviços..."
    kill $(jobs -p) 2>/dev/null
    exit
}

trap cleanup SIGINT

# Iniciar backend em background
cd backend
bundle exec rails server &
BACKEND_PID=$!

# Aguardar backend inicializar
sleep 5

# Iniciar frontend
cd ../frontend
if command -v yarn &> /dev/null; then
    yarn dev
else
    npm run dev
fi
EOF

chmod +x start-backend.sh start-frontend.sh start-all.sh

echo ""
echo "✅ Setup concluído com sucesso!"
echo ""
echo "📋 Próximos passos:"
echo "1. Configure as variáveis de ambiente em backend/.env"
echo "2. Configure as variáveis de ambiente em frontend/.env.local"
echo "3. Execute os serviços:"
echo ""
echo "   ${BLUE}# Apenas backend:${NC}"
echo "   ./start-backend.sh"
echo ""
echo "   ${BLUE}# Apenas frontend:${NC}"
echo "   ./start-frontend.sh"
echo ""
echo "   ${BLUE}# Ambos juntos:${NC}"
echo "   ./start-all.sh"
echo ""
echo "📍 URLs de acesso:"
echo "   Backend:  http://localhost:3000"
echo "   Frontend: http://localhost:3001"
echo ""
echo "🧪 Executar testes:"
echo "   cd backend && bundle exec rspec"
echo "   cd frontend && npm test"
echo ""
echo "📚 Consulte README.md para instruções detalhadas"