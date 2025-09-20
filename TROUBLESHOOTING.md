# TrâmiteJá - Troubleshooting

Guia para resolver problemas comuns durante o setup e desenvolvimento.

## 🚨 Problemas Comuns

### 1. Erro: "PostgreSQL connection failed"

**Sintomas**:
```
FATAL: database "tramiteja_development" does not exist
could not connect to server: No such file or directory
```

**Soluções**:
```bash
# Verificar se PostgreSQL está rodando
pg_isready

# macOS - Iniciar PostgreSQL
brew services start postgresql@16

# Linux - Iniciar PostgreSQL
sudo systemctl start postgresql

# Criar banco manualmente
createdb tramiteja_development

# Ou usando Rails
cd backend
bundle exec rails db:create
```

### 2. Erro: "Bundler version mismatch"

**Sintomas**:
```
Bundler version mismatch
This Gemfile requires a different version of Bundler
```

**Soluções**:
```bash
# Atualizar bundler
gem update bundler

# Ou instalar versão específica
gem install bundler:2.5.23

# Limpar cache e reinstalar
bundle clean --force
bundle install
```

### 3. Erro: "Node.js version incompatible"

**Sintomas**:
```
Node.js version v16.x.x is not supported
The engine "node" is incompatible with this module
```

**Soluções**:
```bash
# Usando nvm (recomendado)
nvm install 20
nvm use 20

# Verificar versão
node -v  # Deve ser 20.x.x

# Limpar cache e reinstalar
rm -rf node_modules package-lock.json
npm install
```

### 4. Erro: "Redis connection refused"

**Sintomas**:
```
Redis::ConnectionError: Error connecting to Redis
Connection refused - connect(2)
```

**Soluções**:
```bash
# Verificar se Redis está rodando
redis-cli ping

# macOS - Iniciar Redis
brew services start redis

# Linux - Iniciar Redis
sudo systemctl start redis

# Verificar porta
netstat -an | grep 6379
```

### 5. Erro: "Permission denied" ao executar migrações

**Sintomas**:
```
PG::InsufficientPrivilege: ERROR: permission denied for database
```

**Soluções**:
```bash
# Criar usuário PostgreSQL
sudo -u postgres createuser -s $(whoami)

# Ou conectar como postgres e criar usuário
sudo -u postgres psql
CREATE USER tramiteja WITH PASSWORD 'senha123';
ALTER USER tramiteja CREATEDB;

# Atualizar database.yml com as credenciais
```

### 6. Erro: "Port already in use"

**Sintomas**:
```
Address already in use - bind(2) for "127.0.0.1" port 3000
```

**Soluções**:
```bash
# Encontrar processo usando a porta
lsof -ti:3000

# Matar processo
kill -9 $(lsof -ti:3000)

# Ou usar porta diferente
rails server -p 3001
npm run dev -- -p 3002
```

### 7. Erro: "Module not found" no frontend

**Sintomas**:
```
Module not found: Can't resolve '@/lib/utils'
Module not found: Can't resolve '@radix-ui/react-select'
```

**Soluções**:
```bash
# Reinstalar dependências
cd frontend
rm -rf node_modules package-lock.json
npm install

# Verificar tsconfig.json paths
# Deve conter: "paths": { "@/*": ["./src/*"] }

# Instalar dependências específicas
npm install @radix-ui/react-select lucide-react
```

### 8. Erro: "Secret key base not found"

**Sintomas**:
```
Rails.application.secret_key_base is nil
```

**Soluções**:
```bash
# Gerar nova secret key
cd backend
bundle exec rails secret

# Adicionar ao .env
echo "SECRET_KEY_BASE=sua_chave_gerada_aqui" >> .env

# Ou configurar credentials
EDITOR=nano bundle exec rails credentials:edit
```

## 🔧 Comandos de Reset Completo

### Reset do Backend
```bash
cd backend

# Parar todos os processos Rails
pkill -f 'rails server'

# Reset completo do banco
bundle exec rails db:drop db:create db:migrate db:seed

# Limpar cache
bundle exec rails tmp:clear

# Reinstalar gems
bundle clean --force
bundle install
```

### Reset do Frontend
```bash
cd frontend

# Parar processo Next.js
pkill -f 'next dev'

# Limpar cache e reinstalar
rm -rf node_modules package-lock.json .next
npm cache clean --force
npm install

# Verificar TypeScript
npm run type-check
```

## 🐛 Debug Avançado

### Logs Detalhados

#### Backend
```bash
# Logs em tempo real
tail -f backend/log/development.log

# Filtrar erros
grep "ERROR" backend/log/development.log

# Debug específico
grep "ProcessoDistributionService" backend/log/development.log
```

#### Frontend
```bash
# Debug Next.js
cd frontend
DEBUG=* npm run dev

# Logs do navegador
# Abrir DevTools (F12) > Console
```

### Verificação de Conectividade

```bash
# Testar banco de dados
cd backend
bundle exec rails runner "puts ActiveRecord::Base.connection.active?"

# Testar Redis
bundle exec rails runner "puts Redis.current.ping"

# Testar API
curl -X GET http://localhost:3000/api/v1/processos

# Testar frontend
curl -I http://localhost:3001
```

### Performance Debug

```bash
# Verificar uso de CPU/Memória
top -p $(pgrep -f "rails server")
top -p $(pgrep -f "next dev")

# Verificar conexões de banco
cd backend
bundle exec rails runner "puts ActiveRecord::Base.connection_pool.stat"
```

## 📱 Problemas Específicos por OS

### macOS

```bash
# Problemas com OpenSSL
export LDFLAGS="-L$(brew --prefix openssl)/lib"
export CPPFLAGS="-I$(brew --prefix openssl)/include"

# Problemas com PostgreSQL
brew unlink postgresql@16 && brew link postgresql@16 --force

# Problemas com Ruby/Gems
brew reinstall ruby
```

### Linux (Ubuntu/Debian)

```bash
# Dependências do sistema
sudo apt update
sudo apt install build-essential libpq-dev libssl-dev libreadline-dev

# Problemas com PostgreSQL
sudo apt remove --purge postgresql postgresql-*
sudo apt install postgresql postgresql-contrib

# Permissões Redis
sudo chown redis:redis /var/lib/redis
```

### Windows (WSL2)

```bash
# Atualizar WSL
wsl --update

# Problemas com PostgreSQL no WSL
sudo service postgresql start

# Problemas com Redis no WSL
sudo service redis-server start

# Path do Node.js
export PATH="/usr/local/bin:$PATH"
```

## 🆘 Quando Pedir Ajuda

Antes de reportar um problema, colete estas informações:

```bash
# Versões do sistema
echo "OS: $(uname -a)"
echo "Ruby: $(ruby -v)"
echo "Node: $(node -v)"
echo "Rails: $(cd backend && bundle exec rails -v)"

# Status dos serviços
echo "PostgreSQL: $(pg_isready && echo 'OK' || echo 'FAIL')"
echo "Redis: $(redis-cli ping 2>/dev/null || echo 'FAIL')"

# Logs de erro
tail -50 backend/log/development.log
```

### Onde Reportar
1. **Issues GitHub**: Para bugs e melhorias
2. **Email**: dev@tramiteja.com.br
3. **Chat**: [Link do chat da equipe]

### Template de Issue
```markdown
## Problema
Descrição clara do problema

## Passos para Reproduzir
1. Execute comando X
2. Acesse URL Y
3. Erro aparece

## Ambiente
- OS: [macOS/Linux/Windows]
- Ruby: [versão]
- Node: [versão]
- PostgreSQL: [versão]

## Logs
```
[Cole os logs de erro aqui]
```

## Tentativas de Solução
- [x] Tentei solução X
- [ ] Tentei solução Y
```

---

💡 **Dica**: Mantenha este arquivo aberto durante o desenvolvimento para consulta rápida!