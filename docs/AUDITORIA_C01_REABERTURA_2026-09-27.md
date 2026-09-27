# AUDITORIA C01 — REABERTURA CORRETIVA

**Projeto:** `Kaue-EDBS/incident-log-pro`  
**Bloco:** SAFRA-C01 — Documentação canônica e PROJECT_PROFILE  
**Data de abertura da rodada corretiva:** 27/09/2026  
**Horário:** 17:34 BRT  
**Estado:** EM EXECUÇÃO  
**Natureza:** reauditoria técnica/documental com reconciliação contra código, Lovable runtime e PRIMARY

---

## 1. Objetivo

Revalidar o SAFRA-C01 contra o estado atual do produto, verificando documentação canônica, PROJECT_PROFILE, criticidade, service class, SLO/RTO/RPO, arquitetura, identidade, retenção, responsabilidades administrativas, réplica, unknown_material_count e coerência com código, hooks, funções, CI, Lovable runtime e Lovable Cloud PRIMARY.

O fechamento histórico do C01 não é apagado. Esta rodada registra uma nova fotografia do sistema após C04–C08.

## 2. Decisões humanas registradas em 27/09/2026

### C01-AUD-DEC-01 — audiência e domínios corporativos

**APPROVED — 27/09/2026 17:34 BRT**

O Painel Safra é de uso exclusivamente corporativo.

Domínios aceitos:
- `@editoradobrasil.com.br`;
- `@editoradobrasil1.onmicrosoft.com`.

Regra de arquitetura a implementar/reconciliar:

```text
business_audience = INTERNAL
application_access = MICROSOFT_CORPORATE_AUTH_ONLY
allowed_email_domains =
  - editoradobrasil.com.br
  - editoradobrasil1.onmicrosoft.com
```

A publicação técnica do endpoint não transforma a audiência funcional em pública. O acesso funcional deve ser permitido somente a identidades Microsoft corporativas pertencentes aos domínios aprovados, com autorização adicional governada no banco quando aplicável.

**Importante:** esta decisão está aprovada; a alteração técnica necessária para garantir os dois domínios ainda será executada e testada nesta rodada.

### C01-AUD-DEC-02 — gate de privacidade/base legal

**APPROVED / SATISFIED — 27/09/2026 17:34 BRT**

Foi confirmado que o enquadramento/base legal e a validação de privacidade exigidos antes da liberação para usuários reais já foram realizados.

Consequência documental:
- remover o estado de `DEFERRED_TO_PRIVACY_OWNER_BEFORE_REAL_USER_RELEASE`;
- registrar o gate como atendido;
- manter vigentes as regras já aprovadas de minimização, retenção, anonimização/eliminação e uso de texto livre.

Esta decisão não altera a política de retenção; apenas fecha a pendência documental de release.

## 3. Pendências corretivas abertas

### C01-AUD-01 — reconciliar PROJECT_PROFILE
**Estado:** OPEN

Atualizar o perfil estruturado para refletir o estado real atual, incluindo data de atualização, estado publicado/runtime, audiência interna, domínios corporativos aprovados, usuários Auth observados no PRIMARY e estado separado de START versus END/CANCEL.

### C01-AUD-02 — reconciliar controle de acesso com os dois domínios
**Estado:** OPEN

O predicado corporativo atual precisa ser auditado e, se necessário, alterado para aceitar somente `@editoradobrasil.com.br` e `@editoradobrasil1.onmicrosoft.com`, com testes positivos e negativos e coerência entre UI, middleware, RPC e RLS.

### C01-AUD-03 — fechar drift documental canônico
**Estado:** OPEN

Reconciliar `docs/ROADMAP.md`, `docs/ARQUITETURA.md`, `docs/STATUS.md`, `docs/DECISOES.md`, `docs/PRIVACIDADE_THREAT_MODEL.md` e `docs/PROJECT_PROFILE.yaml`.

### C01-AUD-04 — marcar snapshots históricos explicitamente
**Estado:** OPEN

No `STATUS.md`, separar claramente fotografia histórica da baseline e estado atual.

### C01-AUD-05 — reconciliar inventário de decisões abertas
**Estado:** OPEN

Classificar cada item como OPEN, RESOLVED, DEFERRED, IMPLEMENTED ou NON_BLOCKING_BY_APPROVED_SAFE_BEHAVIOR. Questões governadas e conhecidas não contam como UNKNOWN.

### C01-AUD-06 — fortalecer fronteiras de tipagem e segredo
**Estado:** OPEN / NÃO BLOQUEANTE DE C01

Revisar casts `as unknown as` nas RPCs START, validação explícita dos DTOs de retorno e proteção do client browser para rejeitar secret/service-role keys.

## 4. Gate de fechamento desta rodada

A reauditoria C01 somente será concluída quando a documentação canônica estiver reconciliada, o PROJECT_PROFILE refletir o runtime/PRIMARY atual, os dois domínios corporativos estiverem implementados e testados, privacidade/base legal estiver registrada como atendida, responsabilidades administrativas permanecerem coerentes, `replica_enabled = false` continuar explícito, service class/application criticality/SLO/RTO/RPO permanecerem consistentes, `unknown_material_count = 0` puder ser recertificado e os pipelines continuarem verdes.

## 5. Estado oficial

Em **27/09/2026 às 17:34 BRT**, foi autorizado iniciar as alterações decorrentes da reauditoria do SAFRA-C01.

> **C01 permanece historicamente fechado; C01-AUD está em execução e ainda não foi recertificado.**

Nenhuma pendência acima deve ser marcada como concluída antes da alteração, teste e evidência correspondente.
