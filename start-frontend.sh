#!/bin/bash
echo "🚀 Iniciando Frontend (Next.js) na porta 3002..."
cd frontend
if command -v yarn &> /dev/null; then
    yarn dev --port 3002
else
    npm run dev -- --port 3002
fi
