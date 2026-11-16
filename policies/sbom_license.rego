package main

import rego.v1

# Lista de licencas copyleft fortes proibidas para software proprietario comercial
forbidden_licenses := {"GPL-3.0", "GPL-3.0-only", "GPL-3.0-or-later", "AGPL-3.0", "AGPL-3.0-only"}

# Regra 1 (Pronta): Validar que o artefato e um CycloneDX valido
deny contains msg if {
	input.bomFormat != "CycloneDX"
	msg := sprintf("VIOLACAO SBOM: Formato invalido (%v). Exige-se padrao CycloneDX.", [object.get(input, "bomFormat", "desconhecido")])
}

# ==============================================================================
# DESAFIO MAO NA MASSA (AULA 07):
# Complete / descomente a Regra 2 abaixo para bloquear componentes do SBOM que
# possuam qualquer licenca listada em forbidden_licenses (ex.: gpl-math-lib).
# Depois, rode: conftest verify -p policies/sbom_license.rego -p tests/sbom_license_test.rego
# ==============================================================================
# deny contains msg if {
# 	some comp in object.get(input, "components", [])
# 	some lic_entry in object.get(comp, "licenses", [])
# 	lic_obj := object.get(lic_entry, "license", {})
# 	lic_id := object.get(lic_obj, "id", object.get(lic_obj, "name", ""))
# 	lic_id in forbidden_licenses
# 	msg := sprintf("VIOLACAO DE LICENCA: O componente '%v@%v' possui licenca proibida '%v'.", [comp.name, comp.version, lic_id])
# }
