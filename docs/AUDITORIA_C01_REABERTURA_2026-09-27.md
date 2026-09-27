# AUDITORIA C01 — REABERTURA CORRETIVA

**Projeto:** `Kaue-EDBS/incident-log-pro`  
**Bloco:** SAFRA-C01 — Documentação canônica e PROJECT_PROFILE  
**Data de abertura da rodada corretiva:** 27/09/2026  
**Horário:** 17:34 BRT  
**Estado:** CONCLUÍDA / RECERTIFICADA  
**Natureza:** reauditoria técnica/documental com reconciliação contra código, Lovable runtime e PRIMARY  
**Fechamento técnico:** 27/09/2026 às 18:16 BRT

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

**Executado:** os dois domínios foram implementados no predicado corporativo, testados no banco descartável e verificados diretamente no PRIMARY.

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
**Estado:** CLOSED

Atualizar o perfil estruturado para refletir o estado real atual, incluindo data de atualização, estado publicado/runtime, audiência interna, domínios corporativos aprovados, usuários Auth observados no PRIMARY e estado separado de START versus END/CANCEL.

### C01-AUD-02 — reconciliar controle de acesso com os dois domínios
**Estado:** CLOSED

O predicado corporativo atual precisa ser auditado e, se necessário, alterado para aceitar somente `@editoradobrasil.com.br` e `@editoradobrasil1.onmicrosoft.com`, com testes positivos e negativos e coerência entre UI, middleware, RPC e RLS.

### C01-AUD-03 — fechar drift documental canônico
**Estado:** CLOSED

Reconciliar `docs/ROADMAP.md`, `docs/ARQUITETURA.md`, `docs/STATUS.md`, `docs/DECISOES.md`, `docs/PRIVACIDADE_THREAT_MODEL.md` e `docs/PROJECT_PROFILE.yaml`.

### C01-AUD-04 — marcar snapshots históricos explicitamente
**Estado:** CLOSED

No `STATUS.md`, separar claramente fotografia histórica da baseline e estado atual.

### C01-AUD-05 — reconciliar inventário de decisões abertas
**Estado:** CLOSED

Classificar cada item como OPEN, RESOLVED, DEFERRED, IMPLEMENTED ou NON_BLOCKING_BY_APPROVED_SAFE_BEHAVIOR. Questões governadas e conhecidas não contam como UNKNOWN.

### C01-AUD-06 — fortalecer fronteiras de tipagem e segredo
**Estado:** CLOSED

Revisar casts `as unknown as` nas RPCs START, validação explícita dos DTOs de retorno e proteção do client browser para rejeitar secret/service-role keys.

## 4. Evidências de execução e fechamento

### C01-AUD-01 — PROJECT_PROFILE

- `schema_version` elevado para 3;
- estado publicado/runtime reconciliado;
- audiência funcional registrada como `INTERNAL`;
- endpoint técnico registrado como `PUBLIC_ENDPOINT_AUTH_GATED`;
- `current_auth_users = 2`;
- `current_bound_active_principals = 2`;
- START separado de END/CANCEL;
- migration C01-AUD registrada;
- `known_drift = []` após verificação no PRIMARY;
- `unknown_material_count = 0` recertificado.

### C01-AUD-02 — domínios corporativos

Migration canônica:

`20260927204325_c01_corporate_domains_and_profile_alignment.sql`

Predicado final mantém:
- `auth.uid()` presente;
- usuário não anônimo;
- provider `azure`;
- token não expirado;
- `auth.sessions` viva;
- domínio pertencente à lista aprovada.

Domínios aprovados:
- `editoradobrasil.com.br`;
- `editoradobrasil1.onmicrosoft.com`.

Verificação sintética direta no PRIMARY, em transação com rollback:

| Domínio | safra_is_corporate_user | START catalog |
|---|---:|---:|
| `editoradobrasil.com.br` | true | 11 cenários |
| `editoradobrasil1.onmicrosoft.com` | true | 11 cenários |
| `example.com` | false | não chamado |

Controles adicionais observados no PRIMARY:
- 2 usuários Auth corporativos reais;
- 2 principals ativos vinculados;
- 9 role grants ativos;
- 0 grants `anon` nas estruturas centrais auditadas;
- 0 policies públicas `USING (true)`.

### C01-AUD-03 / 04 / 05 — documentação canônica

Foram reconciliados:
- `docs/PROJECT_PROFILE.yaml`;
- `docs/ROADMAP.md`;
- `docs/ARQUITETURA.md`;
- `docs/STATUS.md`;
- `docs/DECISOES.md`;
- `docs/PRIVACIDADE_THREAT_MODEL.md`.

O `STATUS.md` passou a distinguir explicitamente snapshot histórico da baseline de estado atual.

O inventário de decisões passou a diferenciar:
- OPEN;
- DEFERRED;
- IMPLEMENTED;
- SATISFIED;
- NON_BLOCKING_BY_APPROVED_SAFE_BEHAVIOR.

Questões conhecidas, classificadas e governadas não são tratadas como UNKNOWN.

### C01-AUD-06 — fronteiras de runtime

- casts `as unknown as` do START removidos;
- respostas das RPCs `safra_get_start_catalog` e `safra_start_treatment` passam por schemas Zod em runtime;
- client browser rejeita `sb_secret_`;
- client browser rejeita JWT legado com role `service_role`;
- publishable key e legado `anon` continuam aceitos conforme o modelo Supabase;
- testes C01 entram no App Smoke.

### Pull request e merge

PR #5 — `C01-AUD: reconcile canonical docs, corporate domains and runtime contracts`

- estado: **MERGED**;
- merge commit: `ebb6670333837fab78990eafa3c8bd9b2680da7c`.

### Gates do PR #5 — head final

- App Smoke Test `36349954349`: **SUCCESS**;
- Database Disposable Test `36349954373`: **SUCCESS**.

### Gates pós-merge em main

- App Smoke Test `36350344716`: **SUCCESS**;
- Database Disposable Test `36350344599`: **SUCCESS**.

O Database Disposable Test reconstruiu migrations canônicas, executou pgTAP, denial de Data API/RPC, rollback/rebuild e lint de banco.

O App Smoke validou contratos de produto, autorização UI/server, timezone, novos contratos C01, dependências, typecheck, build e lint zero-warning.

---

## 5. Gate de fechamento desta rodada

A reauditoria C01 somente será concluída quando a documentação canônica estiver reconciliada, o PROJECT_PROFILE refletir o runtime/PRIMARY atual, os dois domínios corporativos estiverem implementados e testados, privacidade/base legal estiver registrada como atendida, responsabilidades administrativas permanecerem coerentes, `replica_enabled = false` continuar explícito, service class/application criticality/SLO/RTO/RPO permanecerem consistentes, `unknown_material_count = 0` puder ser recertificado e os pipelines continuarem verdes.

## 6. Estado oficial

Em **27/09/2026 às 17:34 BRT**, foi autorizado iniciar as alterações decorrentes da reauditoria do SAFRA-C01.

> **C01 permanece historicamente fechado; C01-AUD foi concluída e recertificada em 27/09/2026 às 18:16 BRT.**

Resultado final: **unknown_material_count = 0**. Não restou pendência corretiva aberta dentro do escopo C01-AUD.
