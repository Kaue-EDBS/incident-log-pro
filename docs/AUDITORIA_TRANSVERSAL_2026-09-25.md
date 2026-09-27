# AUDITORIA TRANSVERSAL — Painel Safra

**Data:** 25/09/2026  
**Escopo:** baseline técnica e funcional de C00 até C06.1  
**Princípio:** corrigir automaticamente somente o que não exige nova decisão de negócio; demais pontos ficam em `WAITING_HUMAN_DECISION`.

## 1. Resumo executivo

A fundação do Painel Safra foi auditada de ponta a ponta nos eixos de arquitetura, schema, migrations, integridade, identidade, RBAC, RLS, API direta, dados canônicos, CI, rollback, frontend, supply chain, performance, privacidade e documentação.

A carga canônica possui exatamente 11 cenários oficiais da Matriz v3, sem tratamentos fictícios e sem inferência de criticidade.

## 2. Eixos auditados

| Eixo                    | Estado                    | Evidência/observação                                                    |
| ----------------------- | ------------------------- | ----------------------------------------------------------------------- |
| Arquitetura             | PASS                      | Lovable Cloud PRIMARY + PostgreSQL/Supabase; GitHub canônico            |
| Schema v2               | PASS                      | 17 tabelas de domínio presentes                                         |
| Migrations              | PASS                      | GitHub e PRIMARY reconciliados                                          |
| RLS                     | PASS                      | 17/17 tabelas de domínio com RLS                                        |
| API direta              | PASS                      | acesso público/anon bloqueado no CI                                     |
| RBAC                    | PASS                      | papéis separados de ownership                                           |
| Ownership               | PASS                      | 11/11 owners conforme Matriz v3                                         |
| Versionamento           | PASS                      | 11 versões v1 PUBLISHED e current_version correto                       |
| Criticidade             | PASS/PENDÊNCIA DE NEGÓCIO | 11 NULL; GI-SAFRA-001 preservado                                        |
| Integridade histórica   | PASS                      | append-only/version freeze/sem cascade destrutivo                       |
| Integridade temporal    | PASS                      | timestamps server-side e guardas temporais                              |
| Idempotência estrutural | PASS                      | chaves e testes de double submit                                        |
| Rollback de migration   | PASS                      | workflow generalizado para a migration mais recente                     |
| Banco descartável       | PASS                      | rebuild canônico por Supabase local                                     |
| Performance relacional  | PASS                      | 35/35 FKs do domínio cobertas por índice                                |
| Storage                 | PASS                      | 0 buckets; não habilitado no MVP atual                                  |
| Dados fictícios Safra   | PASS                      | 0 treatments                                                            |
| Frontend typecheck      | PASS                      | CI                                                                      |
| Frontend build          | PASS                      | CI                                                                      |
| Lint legado             | TECH_DEBT                 | erros antigos de Prettier; não funcionais                               |
| Tipos Supabase          | PASS                      | schema v2 regenerado no frontend                                        |
| Supply chain            | PASS                      | patches transitivos seguros aplicados; gate HIGH passou no App Smoke 20 |
| Backup/restore/RTO/RPO  | FUTURA FASE               | SAFRA-C09                                                               |
| UX Safra                | FUTURA FASE               | frontend ainda preserva legado conforme roadmap                         |

## 3. Correções aplicadas pela auditoria

- rollback do CI deixou de depender do C05;
- runs antigas do teste de banco passam a ser canceladas quando existe commit novo;
- Supabase CLI fixada em versão estável no CI;
- smoke do frontend passou a testar instalação, dependências, TypeScript e build;
- helpers privados perderam EXECUTE indevido herdado;
- writer de auditoria de acesso negado passou a ser backend-only;
- índices ausentes de FKs foram adicionados;
- teste pgTAP transversal foi criado;
- documentação C05/C06/paridade foi reconciliada;
- decisões humanas restantes foram consolidadas em `docs/GOVERNANCE_ISSUES.md`;
- dependências transitivas vulneráveis foram atualizadas sem mudança de major das dependências diretas.

## 4. Dados canônicos conferidos

- 11 cenários;
- 11 versões v1 PUBLISHED;
- 11 owners ativos;
- 7 áreas;
- 10 ferramentas/sistemas;
- 20 vínculos de áreas impactáveis;
- 11 vínculos de sistemas;
- 0 SLAs estruturados — intencional até C07;
- 0 treatments;
- 0 buckets de storage;
- 11 criticidades NULL;
- hash da Matriz v3 presente nas 11 versões.

## 5. Segurança conferida

- Microsoft/Entra permanece o único login funcional;
- não há autorização por `user_metadata`;
- antigo `safra_access` não é usado;
- não há `auth.role()` nas funções Safra;
- sessão precisa permanecer viva em `auth.sessions`;
- admins não herdam ownership;
- nenhum admin é owner ativo por acidente;
- domínio Safra não concede tabela diretamente a `anon`/`authenticated`;
- zero FK do domínio usa `ON DELETE CASCADE`;
- funções SECURITY DEFINER relevantes usam `search_path = ''`.

## 6. Dívida técnica não bloqueante

### Lint/Prettier legado

O código herdado possui grande volume de diferenças de formatação. TypeScript e build passam. A correção deve ser feita em mudança cosmética própria para evitar misturar centenas de linhas de formatação com evolução funcional.

### Frontend legado

A interface ainda se apresenta como Reliability Monitor. Isso é esperado nesta etapa: o produto Safra ainda não entrou nas fases de redesign/fluxos funcionais.

## 7. WAITING_HUMAN_DECISION

A fonte canônica é `docs/GOVERNANCE_ISSUES.md`.

Pendências:

- GI-SAFRA-001 — quais são os quatro cenários CRITICAL;
- GI-SAFRA-002 — thresholds dos cenários 2, 4, 10 e 11;
- GI-SAFRA-003 — fonte oficial do mínimo da curva A do cenário 9;
- GI-SAFRA-004 — múltiplos treatments ACTIVE do mesmo cenário;
- GI-SAFRA-005 — provider/canal de notificações e e-mail de platform admins;
- GI-SAFRA-006 — janela exata da Safra corrente;
- GI-SAFRA-007 — publicação formal do 12º card após ownership;
- GI-SAFRA-008 — janela oficial da governança semanal.

## 8. Pontos deliberadamente não antecipados

- START funcional: C08;
- END/CANCEL funcionais: F01/F02;
- SLA engine: C07/M04;
- provider de notificações: M05;
- pós-mortem: F03;
- backup/restore e ensaio RTO/RPO: C09.

## 9. Gate

Gate final aprovado:

```text
Database Disposable Test Run 58 / 36205238018 = PASS
App Smoke Test Run 20 / 36205238059 = PASS
C00_TO_C06_1_CROSS_AXIS_AUDIT = PASS
TECHNICAL_BASELINE = READY_TO_ADVANCE
```

O lint/Prettier legado permanece dívida cosmética não bloqueante; todas as verificações funcionais e de segurança exigidas nesta auditoria passaram.
