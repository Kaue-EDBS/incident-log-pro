# AUDITORIA TRANSVERSAL C00–C05 — 01/10/2026

**Objetivo:** conferir se documentos, código, testes e o banco PRIMARY contam a mesma história depois das reauditorias C00-AUD2 a C05-AUD2 e das decisões D-50 a D-73.  
**Estado:** CONCLUÍDA

## 1. Consistente

| Verificação | Resultado |
|---|---|
| Migrations PRIMARY × repositório | 36 = 36, mesmas versões |
| Ficha técnica × PRIMARY | 2 logins, 9 cadastros (2 ligados), 9 papéis ativos, 16 tabelas, 11 cards CRITICAL na versão 2, 0 tratativas |
| `GOVERNANCE_ISSUES.md` × `public.governance_issues` | 11 GI com o mesmo status |
| `types.ts` × PRIMARY | 16 tabelas e as funções vigentes |
| Login | só Microsoft (Email desligado pelo owner) |
| CI | verde |

## 2. Corrigido nesta auditoria

| Item | Correção |
|---|---|
| Contagem "17 tabelas" em ARQUITETURA, PRIVACIDADE_THREAT_MODEL e ROLLBACK | 16 (D-73) |
| `C07_SLA_ENGINE.md` sem a D-62 e com thresholds "aguardando decisão" | aviso de engine sem uso nos cards; thresholds adiados (D-56) |
| `MATRIZ_PARIDADE.md` com SLA e escalonamento "a construir" | SLA → PARK; escalonamento → REMOVE; linhas novas para trava, dono, duas partes, avisos e Safra corrente |
| `HANDOFF_C08_START_2026-09-27.md` desatualizado | aviso no topo com rota `/abrir-protocolo`, CRITICAL, sem SLA e os testes novos (D-57/D-65) |
| Tela de Abrir Protocolo exibindo "SLAs estruturados" | blocos removidos (D-62) |
| `DECISOES.md` com índice fora de ordem | 73 decisões em ordem numérica, sem lacunas |
| Gate C02 marcado "recertificação em execução" no histórico do threat model | apontado para a recertificação de 01/10 |

## 3. Fora do escopo desta auditoria (decisão do owner)

As especificações das fases futuras **M01, M04, M05, F01, F02 e F04** no `ROADMAP.md` são anteriores às decisões D-55 a D-73. Elas serão revistas uma a uma, quando cada fase for auditada. O ROADMAP tem um aviso no topo da seção 11 dizendo que, em caso de conflito, valem `DECISOES.md`, `REGRAS_NEGOCIO.md` e `GLOSSARIO_DOMINIO.md` v2.0.
