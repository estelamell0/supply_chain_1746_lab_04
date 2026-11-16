#!/usr/bin/env bash
set -e

echo "=========================================================================="
echo " [INFO] INICIALIZANDO LABORATORIO 04: ATESTACOES IN-TOTO & POLICY AS CODE"
echo "=========================================================================="

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

mkdir -p dist

if docker compose version >/dev/null 2>&1; then
    DOCKER_COMPOSE="docker compose"
elif command -v docker-compose >/dev/null 2>&1; then
    DOCKER_COMPOSE="docker-compose"
else
    DOCKER_COMPOSE="docker compose"
fi

echo "[1/3] Subindo Registry OCI Local (porta 5000)..."
$DOCKER_COMPOSE up -d registry

echo "[2/3] Construindo imagem do ambiente de praticas (supply-chain-lab04)..."
$DOCKER_COMPOSE build lab

echo ""
echo "[3/3] Ambiente pronto com sucesso!"
echo "Para entrar no terminal do laboratorio, execute:"
echo "  $DOCKER_COMPOSE run --rm lab"
echo ""
echo "Dica: ja dentro do container (:/workspace#), execute:"
echo "  source ./bootstrap_lab04.sh"
echo "=========================================================================="
