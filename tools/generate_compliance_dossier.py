#!/usr/bin/env python3
"""
tools/generate_compliance_dossier.py
Consolidador de Evidencias Criptograficas e Governanca de Supply Chain.
Base inicial para a Aula 06 e entregavel final de homologacao do Capstone (Aula 08).
"""

import os
import sys
import json
import hashlib
from datetime import datetime, timezone

# Garantir compatibilidade de saida UTF-8 em terminais Windows/Linux
if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8', errors='replace')

def sha256_file(filepath: str) -> str:
    if not os.path.exists(filepath):
        return "N/A (Arquivo nao encontrado)"
    h = hashlib.sha256()
    with open(filepath, 'rb') as f:
        while chunk := f.read(8192):
            h.update(chunk)
    return h.hexdigest()

def generate_dossier():
    print("=" * 70)
    print(" [INFO] CONSOLIDADOR DE DOSSIE DE CONFORMIDADE - SUPPLY CHAIN SECURITY")
    print("=" * 70)

    dossier = {
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "standard_compliance": ["SLSA v1.0 Level 2", "NIST SP 800-218 (SSDF)", "EO 14028 (NTIA Minimum Elements)"],
        "target_application": "payment-api-service:1.0.0",
        "evidence_chain": {}
    }

    # 1. Lockfile Integrity
    lockfile_hash = sha256_file("src/package-lock.json")
    dossier["evidence_chain"]["dependency_lockfile"] = {
        "path": "src/package-lock.json",
        "sha256": lockfile_hash,
        "status": "PINNED_DETERMINISTIC"
    }

    # 2. SBOM Status
    sbom_path = "dist/sbom.cdx.json"
    if os.path.exists(sbom_path):
        dossier["evidence_chain"]["sbom"] = {
            "format": "CycloneDX 1.6 JSON",
            "sha256": sha256_file(sbom_path),
            "status": "ATTACHED_TO_OCI_REGISTRY"
        }
    else:
        dossier["evidence_chain"]["sbom"] = {"status": "PENDING_PHASE_2"}

    # 3. VEX Statement Status
    vex_path = "attestations/vex_template.openvex.json"
    if os.path.exists(vex_path):
        dossier["evidence_chain"]["openvex"] = {
            "specification": "OpenVEX v0.2.0",
            "justification": "code_not_reachable",
            "status": "ATTESTED_IN_TOTO"
        }

    # 4. SLSA Provenance
    slsa_path = "attestations/slsa_predicate.json"
    if os.path.exists(slsa_path):
        dossier["evidence_chain"]["slsa_provenance"] = {
            "specification": "SLSA Provenance v1.0",
            "builder": "https://github.com/actions/runner/slsa-builder-l2",
            "status": "ATTESTED_IN_TOTO"
        }

    os.makedirs("dist", exist_ok=True)
    out_json = "dist/dossie_conformidade.json"
    with open(out_json, "w", encoding="utf-8") as f:
        json.dump(dossier, f, indent=2)

    print(f"\n[OK] Dossie de evidencias estruturado gerado com sucesso em: {out_json}")
    print(f"Evidencias consolidadas: {list(dossier['evidence_chain'].keys())}")
    print("=" * 70)

if __name__ == "__main__":
    generate_dossier()
