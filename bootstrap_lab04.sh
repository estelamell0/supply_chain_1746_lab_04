#!/usr/bin/env bash
# Uso recomendado dentro do container: source ./bootstrap_lab04.sh
set -e

echo "=========================================================================="
echo " [BOOTSTRAP LAB 04] PREPARANDO ESTADO BASE (EQUIVALENTE A FASE 4 DO LAB 03)"
echo "=========================================================================="

mkdir -p dist

echo "[1/4] Construindo imagem payment-api e publicando em localhost:5000..."
docker build -q -f docker/Dockerfile.app -t localhost:5000/payment-api:v1.0.0 .
docker push -q localhost:5000/payment-api:v1.0.0 >/dev/null

IMAGE_DIGEST=$(docker inspect --format='{{index .RepoDigests 0}}' localhost:5000/payment-api:v1.0.0)
export IMAGE_DIGEST
echo "export IMAGE_DIGEST=\"$IMAGE_DIGEST\"" > .env_lab04
echo "  -> IMAGE_DIGEST=$IMAGE_DIGEST"

echo "[2/4] Gerando SBOM CycloneDX 1.6 (dist/sbom.cdx.json) com Syft..."
syft localhost:5000/payment-api:v1.0.0 -o cyclonedx-json=dist/sbom.cdx.json >/dev/null 2>&1

if [ ! -f cosign.key ] || [ ! -f cosign.pub ]; then
    echo "[3/4] Gerando par de chaves efemero Cosign (senha vazia)..."
    COSIGN_PASSWORD="" cosign generate-key-pair >/dev/null 2>&1
else
    echo "[3/4] Chaves Cosign ja existentes reaproveitadas."
fi

echo "[4/4] Assinando imagem base com Cosign pelo Digest SHA-256..."
COSIGN_PASSWORD="" cosign sign --yes --key cosign.key --tlog-upload=false "$IMAGE_DIGEST" >/dev/null 2>&1

echo ""
echo "[OK] Bootstrap concluido! Variavel IMAGE_DIGEST exportada no seu shell."
echo "Voce ja pode iniciar a Parte 1 (Atestacoes in-toto) imediatamente."
echo "=========================================================================="
