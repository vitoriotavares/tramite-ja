#!/bin/bash
echo "🚀 Iniciando TrâmiteJá completo..."
echo "Backend estará disponível em: http://localhost:3000"
echo "Frontend estará disponível em: http://localhost:3002"
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

# Iniciar frontend na porta 3002
cd ../frontend
if command -v yarn &> /dev/null; then
    yarn dev --port 3002
else
    npm run dev -- --port 3002
fi
