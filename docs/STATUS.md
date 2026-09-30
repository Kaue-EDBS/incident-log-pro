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
| C01-AUD2 — documentação canônica e PROJECT_PROFILE | EM EXECUÇÃO | `AUDITORIA_C01_REABERTURA_2026-09-30.md` |
| C02-AUD — threat model | registrada como EM EXECUÇÃO; próxima a reconciliar | `AUDITORIA_C02_REABERTURA_2026-09-27.md` |

---

## 2. Produto no ar

- **Produto único:** Painel Safra (D-50). O Reliability Monitor/MTTR foi retirado.
- **Acesso:** só login Microsoft corporativo dos domínios `editoradobrasil.com.br` e `editoradobrasil1.onmicrosoft.com` (D-48).
- **Telas:** Visão Geral ("Em obras") e Abrir Protocolo.
- **START:** os 11 cenários publicados podem ser abertos (D-51). A liberação por card fica para a governança futura (GI-SAFRA-010).
- **Publicação:** feita sempre pelo owner no Lovable.

---

## 3. Banco (Lovable Cloud PRIMARY)

- Motor: PostgreSQL na stack Supabase, gerenciado pelo Lovable Cloud.
- Tabelas em `public`: 17, todas do domínio Safra, todas com RLS e sem acesso `anon`.
- Pessoas e papéis: `private.safra_principals` e `private.safra_role_grants` (2 usuários Auth, 2 principals vinculados, 9 grants ativos em 30/09).
- Tratativas registradas: 0.
- Migrations: 31 no PRIMARY e 28 no repositório. As 3 a mais são o **drift conhecido** de 28/09 (C00-AUD2-07, encaminhado ao C05).
- Regra (D-52): toda mudança no banco começa como arquivo em `supabase/migrations/`; cada sessão começa comparando PRIMARY e repositório.

---

## 4. Testes automáticos

- **App Smoke Test** e **Database Disposable Test** verdes em 30/09 (run `36745901521`).
- Os minutos do GitHub Actions do repositório privado estavam esgotados. Para rodar em 30/09, o repositório ficou temporariamente público.

---

## 5. Pendências abertas

- Pendências de governança: ver `docs/GOVERNANCE_ISSUES.md` (GI-SAFRA-001 a 010, todas não bloqueantes ou adiadas com fase).
- Drift de 3 migrations no PRIMARY sem arquivo: reauditoria do C05.
- Estado da C02-AUD a reconciliar.
- Homologação do START com sessão real (checklist em `docs/HANDOFF_C08_START_2026-09-27.md`).
- Backup/restore com RTO 30 min e RPO 5 min: SAFRA-C09.

---

## 6. Próximo passo

Concluir a C01-AUD2 e seguir para a reconciliação da C02-AUD.
