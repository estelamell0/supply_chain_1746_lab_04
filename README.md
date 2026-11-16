# Laboratório Prático CLI: Atestações *in-toto* e Policy as Code (Conftest & Rego v1)

**Disciplina:** Supply Chain Security & DevSecOps Architecture (Ada Tech)  
**Módulo:** Integridade Criptográfica Avançada, Policy as Code e Admissão em Cluster (Aulas 06 e 07 Integradas)  
**Alvo:** Microsserviço financeiro `payment-api` (Node.js + Docker + Sigstore + Conftest / OPA)  
**Tempo Estimado:** 90 a 100 minutos de prática interativa

---

## 1. Visão Geral e Arquitetura do Laboratório

Nas etapas anteriores, aprendemos a higienizar dependências, mitigar ataques de *Poisoned Pipeline Execution* (PPE), gerar inventários SBOM (CycloneDX / SPDX), gerenciar falsos positivos com laudos OpenVEX e assinar containers por seu Digest SHA-256 com Cosign.

Agora, neste laboratório 100% prático via terminal CLI, enfrentamos os dois desafios que completam a cadeia de suprimentos segura:
1. **Selagem Criptográfica com Atestações *in-toto*:** Como vincular permanentemente à imagem Docker o seu SBOM, seu laudo OpenVEX e a certidão de procedência SLSA Provenance v1.0, formando uma trilha de auditoria irrefutável.
2. **Enforcement Automatizado com Policy as Code (PaC):** Como utilizar o motor **Open Policy Agent (OPA)** com a linguagem moderna **Rego v1** e a ferramenta **Conftest** para transformar regras de segurança em barreiras determinísticas no CI/CD, bloqueando Dockerfiles vulneráveis, licenças restritivas (GPL-3.0) e builds não oficiais.
3. **Visão de Shield-Right (Admission Control):** Como essas mesmas atestações alimentam controladores de admissão no Kubernetes (Kyverno / Gatekeeper) para impedir qualquer deploy manual que tente burlar a esteira.

---

## 2. Estrutura do Workspace

```text
lab_04_attestations_and_policy_as_code/
├── README.md                              # Este guia prático com roteiro passo a passo
├── Dockerfile                             # Ambiente integrado (Cosign, Syft, Trivy, Conftest)
├── docker-compose.yml                     # Orquestrador do Lab + Registry OCI Local (porta 5000)
├── setup_lab.sh / clean_lab.sh            # Scripts de inicialização e reset do laboratório
├── bootstrap_lab04.sh                     # Automação de nivelamento inicial rápido
├── src/                                   # Código-fonte da aplicação alvo (payment-api)
│   ├── app.js
│   ├── package.json
│   ├── package-lock.json
│   └── .npmrc                            # Isolamento de escopo interno (@corp)
├── docker/
│   ├── Dockerfile.app                     # Container endurecido (non-root, versão fixada)
│   └── Dockerfile.inseguro                # Container vulnerável para teste de bloqueio (root, :latest)
├── attestations/
│   ├── vex_template.openvex.json          # Declaração OpenVEX (code_not_reachable)
│   ├── slsa_predicate.json                # Predicado SLSA Provenance v1.0 legítimo
│   ├── slsa_predicate_invalido.json       # Predicado SLSA inválido para teste de bloqueio
│   ├── sbom_referencia.cdx.json           # SBOM CycloneDX com gpl-math-lib (GPL-3.0)
│   └── sbom_homologado_limpo.cdx.json     # SBOM CycloneDX limpo sem licenças proibidas
├── policies/                              # Políticas declarativas em Rego v1 (Conftest)
│   ├── dockerfile.rego                    # Bloqueio de :latest e USER root
│   ├── slsa_provenance.rego               # Validação de builder homologado e branch main
│   ├── sbom_license.rego                  # Desafio prático: Bloqueio de licenças restritivas
│   └── k8s_admission_policy.yaml          # Manifesto de Admissão Kyverno para inspeção
├── tests/
│   └── sbom_license_test.rego             # Testes unitários das políticas com conftest verify
├── tools/
│   ├── verify_keyless_bundle.py           # Inspetor didático de certificado e Rekor
│   └── generate_compliance_dossier.py     # Gerador automatizado de Dossiê de Auditoria
└── dist/                                  # Diretório de artefatos gerados (SBOMs e Dossiê)
```

---

## 3. Preparação do Ambiente (Setup) & Guia de Navegação no Terminal

Todo o ferramental necessário (`cosign`, `syft`, `trivy`, `conftest`, `jq`, `docker-cli`, `python3`) já está empacotado dentro do container do laboratório. Você não precisa instalar nada manualmente no seu sistema operacional além do Docker.

### ⚠️ Como Saber Onde Você Está (Terminal Local vs. Container Docker)

Observe sempre o final do prompt do seu terminal:

| Prompt Exibido | Onde você está? | O que executar aqui? |
| :--- | :--- | :--- |
| `PS C:\...\lab_04_attestations_and_policy_as_code>` *(ou `$`)* | 🖥️ **Terminal Local (Fora do Container)** | Apenas a inicialização (`setup_lab` / `docker compose`), entrada no container e limpeza. |
| `supply_chain_lab04:/workspace#` *(termina com `#`)* | 🐳 **Dentro do Container do Laboratório** | **TODAS as fases práticas (Fases 1, 2 e 3)!** Você não precisa sair do container até concluir o laboratório. |

---

### Passo 1: Inicializar o Ambiente (🖥️ No seu Terminal Local)

Abra o terminal na pasta raiz deste laboratório e execute conforme o seu sistema operacional:

**No Windows (PowerShell):**
```powershell
docker compose up -d registry; docker compose build lab
```
> *<small>Sobe o Registry OCI local em segundo plano na porta 5000 e compila a imagem do container do laboratório.</small>*

**No Linux / macOS / WSL:**
```bash
chmod +x setup_lab.sh clean_lab.sh bootstrap_lab04.sh && ./setup_lab.sh
```
> *<small>Concede permissão de execução aos scripts utilitários e inicializa o Registry OCI e a imagem de trabalho do laboratório.</small>*

---

### Passo 2: Entrar no Container de Práticas (🖥️ No seu Terminal Local)

**No Windows (PowerShell) e Linux / macOS / WSL:**
```bash
docker compose run --rm lab
```
> *<small>Inicia o container de práticas em modo interativo com todas as ferramentas de DevSecOps disponíveis no PATH.</small>*

---

### Passo 3: Executar o Bootstrap de Nivelamento Automático (🐳 No prompt `:/workspace#`)

Assim que o prompt mudar para `supply_chain_lab04:/workspace#` (ou `:/workspace#`), execute o script de nivelamento:

```bash
source ./bootstrap_lab04.sh
```
> *<small>Compila a imagem payment-api, publica no registry local, extrai o Digest SHA-256 imutável, gera o SBOM e assina a imagem base com Cosign.</small>*

Confirme que a variável do Digest imutável está presente no seu shell:

```bash
echo "Digest da Imagem: $IMAGE_DIGEST"
```
> *<small>Exibe o Digest SHA-256 definitivo retornado pelo registry local, que servirá como âncora matemática para as atestações.</small>*

> 💡 **Dica de Controle de Sessão:**  
> - Se você fechar o terminal e reabrir, basta rodar `source .env_lab04` dentro do container para recarregar a variável `$IMAGE_DIGEST`.  
> - Para sair do container ao terminar: digite `exit`.  
> - Para limpar todo o ambiente ao final, utilize os comandos da Seção 5 abaixo.

---

## 4. Roteiro Prático Passo a Passo (3 Fases)

> 🐳 **Atenção:** Execute todos os comandos abaixo diretamente dentro do container (`:/workspace#`)!

---

### Fase 1: Atestações *in-toto* — Selando SBOM, OpenVEX e SLSA Provenance

#### O Problema
Não basta assinar o binário da imagem: em auditorias regulatórias (como EO 14028 e NIST SP 800-218), a organização precisa comprovar a lista de componentes (**SBOM**), a análise formal de vulnerabilidades não exploráveis (**OpenVEX**) e quem construiu o software (**SLSA Provenance**). Essas provas precisam ser seladas criptograficamente junto à imagem no registry.

#### Execução Prática (🐳 No prompt `:/workspace#`)

1. Anexe o SBOM CycloneDX diretamente à imagem no Registry:
   ```bash
   cosign attach sbom --sbom dist/sbom.cdx.json $IMAGE_DIGEST
   ```
   > *<small>Faz o upload e anexa o arquivo SBOM CycloneDX como um artefato OCI associado diretamente ao Digest da imagem no registry.</small>*

2. Crie a **Atestação *in-toto*** do laudo OpenVEX formalizando a triagem de vulnerabilidades:
   ```bash
   cosign attest --key cosign.key --predicate attestations/vex_template.openvex.json --type openvex --tlog-upload=false $IMAGE_DIGEST
   ```
   > *<small>Cria e assina criptograficamente o envelope in-toto contendo o laudo OpenVEX, vinculando-o de forma indelével ao Digest da imagem.</small>*

3. Crie a **Atestação *in-toto*** da Certidão de Nascimento SLSA Provenance v1.0:
   ```bash
   cosign attest --key cosign.key --predicate attestations/slsa_predicate.json --type slsaprovenance1 --tlog-upload=false $IMAGE_DIGEST
   ```
   > *<small>Cria e assina criptograficamente o envelope in-toto com os metadados de procedência SLSA v1.0 (builder e workflow oficiais).</small>*

4. Verifique e inspecione a atestação OpenVEX decodificando o payload com `jq`:
   ```bash
   cosign verify-attestation --key cosign.pub --type openvex --insecure-ignore-tlog=true $IMAGE_DIGEST | jq '.payload | @base64d | fromjson'
   ```
   > *<small>Valida a assinatura criptográfica da atestação OpenVEX com a chave pública e decodifica o payload base64 em JSON estruturado.</small>*

5. Verifique e inspecione a atestação de procedência SLSA Provenance:
   ```bash
   cosign verify-attestation --key cosign.pub --type slsaprovenance1 --insecure-ignore-tlog=true $IMAGE_DIGEST | jq '.payload | @base64d | fromjson'
   ```
   > *<small>Valida a assinatura criptográfica da atestação SLSA Provenance e projeta o predicado in-toto comprovando a origem do build.</small>*

6. Gere a consolidação automatizada do **Dossiê de Conformidade**:
   ```bash
   python3 tools/generate_compliance_dossier.py
   ```
   > *<small>Executa o script consolidador que audita as evidências geradas e calcula os hashes SHA-256 para compor o dossiê final.</small>*

7. Inspecione o dossiê gerado:
   ```bash
   cat dist/dossie_conformidade.json
   ```
   > *<small>Exibe a estrutura JSON do dossiê de auditoria pronto para comprovação de conformidade com SLSA v1.0 e NIST SP 800-218.</small>*

---

### Fase 2: Policy as Code com Conftest & Rego v1 (Quality Gate no CI/CD)

#### O Problema
Assinaturas e atestações comprovam o que aconteceu no build, mas não impedem que um artefato fora de padrão seja publicado. Para isso, criamos regras declarativas em **Rego v1** e as executamos com o **Conftest**, barrando o pipeline automaticamente (`exit code 1`) diante de qualquer inconformidade.

#### Etapa 2.1 — Auditando Dockerfiles (`policies/dockerfile.rego`)

1. Teste o Dockerfile vulnerável (utiliza tag mutável `node:latest` e execução como `USER root`):
   ```bash
   conftest test docker/Dockerfile.inseguro -p policies/dockerfile.rego
   ```
   > *<small>Audita o Dockerfile inseguro contra as regras Rego v1, comprovando a rejeição com 2 violações críticas detectadas.</small>*

   *Observe a saída:* O Conftest retorna `FAIL` apontando claramente a proibição de `:latest` e a proibição de `USER root`.

2. Teste o Dockerfile blindado da aplicação:
   ```bash
   conftest test docker/Dockerfile.app -p policies/dockerfile.rego
   ```
   > *<small>Audita o Dockerfile oficial da aplicação, comprovando aprovação com 0 falhas e conformidade com usuário não-privilegiado.</small>*

   *Resultado:* `3 tests, 3 passed, 0 warnings, 0 failures` (Aprovado!).

---

#### Etapa 2.2 — Auditando Procedência SLSA v1.0 (`policies/slsa_provenance.rego`)

1. Teste a proveniência legítima (compilada por builder oficial na branch `refs/heads/main`):
   ```bash
   conftest test attestations/slsa_predicate.json -p policies/slsa_provenance.rego
   ```
   > *<small>Valida o predicado SLSA oficial comprovando que o builder autorizado e a branch main atendem aos critérios de produção.</small>*

2. Teste a proveniência clandestina (compilada em máquina pessoal fora da branch oficial):
   ```bash
   conftest test attestations/slsa_predicate_invalido.json -p policies/slsa_provenance.rego
   ```
   > *<small>Audita a proveniência inválida comprovando o bloqueio automático devido a builder não autorizado e branch não homologada.</small>*

3. **Integração Real (Conftest lendo atestação assinada pelo Cosign via pipe):**
   ```bash
   cosign verify-attestation --key cosign.pub --type slsaprovenance1 --insecure-ignore-tlog=true $IMAGE_DIGEST | jq -c '.payload | @base64d | fromjson' | conftest test - -p policies/slsa_provenance.rego
   ```
   > *<small>Extrai a atestação SLSA assinada diretamente da imagem no registry e a encaminha via pipe para auditoria imediata no Conftest.</small>*

---

#### Etapa 2.3 — Desafio Mão na Massa: Bloquear Licenças Copyleft no SBOM (`policies/sbom_license.rego`)

Licenças como **GPL-3.0** e **AGPL-3.0** possuem cláusulas de copyleft forte que podem obrigar uma empresa a abrir o código-fonte proprietário de seus serviços comerciais. Vamos blindar o SBOM contra isso!

1. Execute os testes unitários da política antes de qualquer alteração:
   ```bash
   conftest verify -p policies/sbom_license.rego -p tests/sbom_license_test.rego
   ```
   > *<small>Executa a suite de testes unitários do Conftest, evidenciando que o teste test_deny_gpl_license falha pois a regra ainda não foi implementada.</small>*

   *Observe:* O teste `test_deny_gpl_license` falha com `FAIL - main - test_deny_gpl_license`.

2. Abra o arquivo `policies/sbom_license.rego` no seu editor e observe que a **Regra 2** está comentada como `TODO`. Descomente ou escreva a regra:

   ```rego
   # Regra 2: Bloquear componentes com licencas proibidas (ex: gpl-math-lib)
   deny contains msg if {
       some comp in object.get(input, "components", [])
       some lic_entry in object.get(comp, "licenses", [])
       lic_obj := object.get(lic_entry, "license", {})
       lic_id := object.get(lic_obj, "id", object.get(lic_obj, "name", ""))
       lic_id in forbidden_licenses
       msg := sprintf("VIOLACAO DE LICENCA: O componente '%v@%v' possui licenca proibida '%v'.", [comp.name, comp.version, lic_id])
   }
   ```
   *(Observe a sintaxe declarativa em Rego v1 com `some comp in ...` e `lic_id in forbidden_licenses`).*

3. Execute os testes unitários novamente para comprovar a correção da regra:
   ```bash
   conftest verify -p policies/sbom_license.rego -p tests/sbom_license_test.rego
   ```
   > *<small>Executa novamente os testes unitários confirmando que ambas as asserções passam com sucesso (2 passed).</small>*

   *Resultado:* `2 tests, 2 passed, 0 warnings, 0 failures`!

4. Teste a política corrigida contra o SBOM real da aplicação gerado pelo Syft (que contém `gpl-math-lib` com `GPL-3.0-only`):
   ```bash
   conftest test dist/sbom.cdx.json -p policies/sbom_license.rego
   ```
   > *<small>Audita o SBOM real compilado no laboratório, comprovando o bloqueio imediato do componente gpl-math-lib (GPL-3.0-only).</small>*

5. Teste também contra o SBOM homologado sem a dependência restritiva:
   ```bash
   conftest test attestations/sbom_homologado_limpo.cdx.json -p policies/sbom_license.rego
   ```
   > *<small>Audita um inventário CycloneDX limpo (sem GPL-3.0/AGPL-3.0), confirmando a aprovação com 0 falhas.</small>*

---

### Fase 3: Kubernetes Admission Control — Shield-Right e Bloqueio em Deploy

#### O Problema
Se um operador com acesso ao cluster rodar `kubectl run invasor --image=...` diretamente na linha de comando, ele conseguirá burlar o pipeline do CI/CD?  
A resposta é **não**, desde que tenhamos um controlador de admissão como o **Kyverno** ou o **OPA Gatekeeper** interceptando requisições no `kube-apiserver`.

#### Execução Prática (🐳 No prompt `:/workspace#`)

1. Inspecione a política de admissão declarativa do Kyverno:
   ```bash
   cat policies/k8s_admission_policy.yaml
   ```
   > *<small>Exibe a política de cluster do Kyverno que valida assinaturas Cosign Keyless e atestações de proveniência no momento do deploy.</small>*

2. Observe os três pilares de proteção declarados na política:
   - `validationFailureAction: Enforce`: Bloqueia a criação do Pod caso a imagem não atenda aos critérios.
   - `verifyImages -> keyless`: Exige que a imagem venha do repositório homologado e tenha sido emitida pelo workflow oficial do GitHub Actions verificado no Rekor.
   - `attestations -> slsa.dev/provenance/v1`: Garante que o artefato foi compilado a partir da branch `refs/heads/main`.

---

## 5. Limpeza e Conclusão

Após finalizar os testes práticos:

1. Saia do container do laboratório para retornar ao terminal da sua máquina:
   ```bash
   exit
   ```
   > *<small>Encerra a sessão interativa dentro do container e retorna ao terminal host do seu computador.</small>*

2. Limpe completamente containers, volumes, imagem local, chaves e artefatos gerados (🖥️ No seu Terminal Local):

   **No Windows (PowerShell):**
   ```powershell
   docker compose down -v --remove-orphans; docker rmi -f localhost:5000/payment-api:v1.0.0 2>$null; Remove-Item -Force -ErrorAction SilentlyContinue dist\*.json, dist\*.txt, cosign.key, cosign.pub, .env_lab04
   ```
   > *<small>Remove os containers e volumes do lab, apaga a imagem local do registry e exclui chaves e artefatos gerados preservando os mocks em src/.</small>*

   **No Linux / macOS / WSL:**
   ```bash
   ./clean_lab.sh
   ```
   > *<small>Executa o script de limpeza completa removendo containers, volumes, imagem local, chaves e artefatos preservando os mocks em src/.</small>*

---

## 6. Como Este Laboratório Conecta com o Projeto Final (Capstone)

Parabéns! Ao concluir este laboratório, você dominou todas as peças do quebra-cabeça de Supply Chain Security:
* **Prevenção:** Higienização de dependências (`.npmrc`, `package-lock.json`) e hardening de Dockerfile.
* **Visibilidade:** Inventário de componentes com **SBOM CycloneDX** e gestão de falsos positivos com **OpenVEX**.
* **Integridade:** Assinatura digital e atestações *in-toto* com **Cosign** amarradas ao Digest SHA-256.
* **Governança:** Barreiras automatizadas com **Conftest & Rego v1** e controle de admissão no cluster.
* **Auditoria:** Consolidação estruturada em **Evidence-as-Code** (`dossie_conformidade.json`).

Agora você está 100% preparado para aplicar este conhecimento na prática na entrega do **Projeto Final (Capstone)** da disciplina!
