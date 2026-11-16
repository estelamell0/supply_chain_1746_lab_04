#!/usr/bin/env bash
set -e

echo "Limpando artefatos gerados no Lab 04..."

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Detectar docker compose vs docker-compose
if docker compose version >/dev/null 2>&1; then
    DOCKER_COMPOSE="docker compose"
elif command -v docker-compose >/dev/null 2>&1; then
    DOCKER_COMPOSE="docker-compose"
else
    DOCKER_COMPOSE="docker compose"
fi

$DOCKER_COMPOSE down -v --remove-orphans || true

# Remover imagem local da aplicacao construida no bootstrap
docker rmi -f localhost:5000/payment-api:v1.0.0 >/dev/null 2>&1 || true

# Remover artefatos, chaves e variaveis de sessao gerados
rm -f dist/*.json dist/*.txt cosign.key cosign.pub .env_lab04
mkdir -p dist

# Limpar pacotes transientes mantendo os 4 mocks essenciais
if [ -d "src/node_modules" ]; then
    find src/node_modules -mindepth 1 -maxdepth 1 ! -name '@corp' ! -name 'gpl-math-lib' ! -name 'express' ! -name 'lodash' -exec rm -rf {} + 2>/dev/null || true
fi

echo "Ambiente limpo e resetado com sucesso!"
