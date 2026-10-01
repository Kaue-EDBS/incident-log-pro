# STATUS — Painel Safra

> **Atualizado em:** 30/09/2026  
> **Regra (D-54):** este arquivo diz só **onde o projeto está agora**. O histórico completo até 30/09/2026 está em `docs/historico/STATUS_ate_2026-09-30.md`. Detalhes de cada fase ficam nas auditorias (`docs/AUDITORIA_*.md`).

---

## 1. Fase atual

**SAFRA-C08 — UX do COMEÇO.** O "Abrir Protocolo" (START) está implementado e publicado. Falta a homologação completa com uma sessão Microsoft corporativa real antes das demais telas do C08.

**Em paralelo: rodada de reauditorias.**

| Rodada | Estado | Documento |
|---|---|---|
| C00-AUD2 — Reliability Monitor/MTTR descontinuado (D-50) | CONCLUÍDA em 30/09 | `AUDITORIA_C00_REABERTURA_2026-09-30.md` |
| C01-AUD2 — documentação canônica e PROJECT_PROFILE | CONCLUÍDA em 01/10 | `AUDITORIA_C01_REABERTURA_2026-09-30.md` |
| C03-AUD2 — glossário e modelo de domínio | CONCLUÍDA em 01/10 (glossário v2.0) | `AUDITORIA_C03_REABERTURA_2026-10-01.md` |
| C04-AUD2 — identidade, RBAC e RLS | CONCLUÍDA em 01/10 | `AUDITORIA_C04_REABERTURA_2026-10-01.md` |
| C05-AUD2 — schema, migrations e invariantes | CONCLUÍDA em 01/10 (drift zerado) | `AUDITORIA_C05_REABERTURA_2026-10-01.md` |
| C06-AUD2 — seed canônico da Matriz v3 | CONCLUÍDA em 01/10 (planilha = banco, 100% dos campos) | `AUDITORIA_C06_REABERTURA_2026-10-01.md` |
| C02-AUD e C02-AUD2 — threat model | CONCLUÍDAS em 01/10; G3.5, THREAT-001 e AUTHZ-001 recertificados | `AUDITORIA_C02_REABERTURA_2026-10-01.md` |

---

## 2. Produto no ar

- **Produto único:** Painel Safra (D-50). O Reliability Monitor/MTTR foi retirado.
- **Acesso:** só login Microsoft corporativo dos domínios `editoradobrasil.com.br` e `editoradobrasil1.onmicrosoft.com` (D-48).
- **Telas:** Visão Geral ("Em obras") e Abrir Protocolo.
- **START:** os 11 cenários, todos **CRITICAL** (versão 2, D-55), podem ser abertos por qualquer usuário corporativo (D-63). Cada pessoa só pode ter **um protocolo em andamento por card** (D-57). O dono de um card não abre protocolo dele (D-65).
- **Publicação:** feita sempre pelo owner no Lovable.
- **Safra corrente:** começou em 01/10/2026; termina quando o Kaue marcar (D-69).

---

## 3. Banco (Lovable Cloud PRIMARY)

- Motor: PostgreSQL na stack Supabase, gerenciado pelo Lovable Cloud.
- Tabelas em `public`: 16, todas do domínio Safra, todas com RLS e sem acesso `anon` (escalonamento removido, D-73).
- Pessoas e papéis: `private.safra_principals` e `private.safra_role_grants` (2 usuários Auth, 2 principals vinculados, 9 grants ativos em 30/09).
- Tratativas registradas: 0.
- Migrations: **37 no PRIMARY e 37 no repositório**, mesmas versões. O drift de 28/09 foi reconstituído na C05-AUD2.
- Regra (D-52): toda mudança no banco começa como arquivo em `supabase/migrations/`; cada sessão começa comparando PRIMARY e repositório.

---

## 4. Testes automáticos

- **App Smoke Test** e **Database Disposable Test** verdes em 30/09 (run `36745901521`).
- Os minutos do GitHub Actions do repositório privado estavam esgotados. Para rodar em 30/09, o repositório ficou temporariamente público.

---

## 5. Pendências abertas

- Pendências de governança: ver `docs/GOVERNANCE_ISSUES.md`. Resolvidas: 001, 004, 008, 009, 010. Decididas, aguardando construção: 005 (avisos, M05), 006 (marcar a Safra, F04/M05), 007 (12º card, M10). Adiadas para a V2 do produto: 002, 003.
- END/CANCEL (F01/F02) ainda não existem: com a trava D-57, quem abrir um protocolo não consegue abrir outro do mesmo card até o encerramento existir.
- Homologação do START com sessão real (checklist em `docs/HANDOFF_C08_START_2026-09-27.md`).
- Backup/restore com RTO 30 min e RPO 5 min: SAFRA-C09.

---

## 6. Próximo passo

Próxima reauditoria: C07.
