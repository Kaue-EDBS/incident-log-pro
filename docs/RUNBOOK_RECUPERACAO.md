# RUNBOOK DE RECUPERAÇÃO — Painel Safra

**Versão:** 1.0 — 02/10/2026 (SAFRA-C09)  
**Meta (D-93):** perda máxima de dados de **até 24 h** (RPO) e volta em **até 4 h** (RTO).  
**Quem aciona:** Kaue Pastrello (owner). Substitutos: Amanda Bueno, João Jurado, Vinicius Moraes (platform admins).

> Regra de ouro: **não improvisar no banco de produção (PRIMARY)**. Toda mudança de estrutura nasce em `supabase/migrations` (D-52). Em dúvida, pare e registre.

---

## 1. O que existe para recuperar

| Peça | Onde está | Como volta |
|---|---|---|
| Estrutura do banco e os 11 cards | `supabase/migrations` no GitHub | reconstrução automática (o CI faz isso a cada mudança, em cerca de 2 min) |
| Protocolos, eventos, vínculos de login, auditoria, registro técnico | só no banco PRIMARY | **backup diário do Lovable Cloud** |
| Telas | GitHub + publicação do Lovable | publicar de novo no Lovable |
| Login | Microsoft Entra ID (TI) + intermediário de login do Lovable | TI / suporte do Lovable |

---

## 2. Primeiros 15 minutos (qualquer incidente)

1. **Confirmar o problema**: abrir https://painelsafra.lovable.app com a sua conta. Anotar a hora e o que aparece.
2. **Olhar a Saúde do sistema** (Administração): erros de tela, falhas técnicas, respostas lentas e logins recusados nas últimas 24 h.
3. **Classificar** pelo quadro da seção 3.
4. **Avisar** os donos de card (Daniel, Jiane, Renato) e o Jair: "Painel com problema; protocolos novos por e-mail/Teams até a volta". Registrar a hora do aviso.
5. **Anotar tudo** na seção 7 (registro do incidente).

---

## 3. Quadro de decisão

| Sintoma | Provável causa | Ação | Seção |
|---|---|---|---|
| Ninguém consegue entrar; Microsoft recusa | Entra ID / TI | chamado urgente ao TI | 4.1 |
| Entra, mas aparece "só contas corporativas" para todos | sessão / tenant / banco | conferir a Saúde do sistema; suporte do Lovable | 4.2 |
| Telas não carregam (erro em todas as páginas) | publicação do app | republicar a última versão boa no Lovable | 4.3 |
| Erro ao abrir/concluir depois de uma mudança recente | migration nova | desfazer com nova migration (forward fix) | 4.4 |
| Dados sumiram ou foram corrompidos | perda de dados | restauração do backup | 4.5 |
| Muito lento | carga ou plano pequeno | ver Saúde do sistema; pedir aumento ao Lovable | 4.6 |

---

## 4. Procedimentos

### 4.1 Login Microsoft fora
1. Confirmar com outra pessoa da Editora se o login Microsoft funciona em outros sistemas.
2. Chamado ao TI com: hora, mensagem de erro, aplicativo "Painel Safra / Lovable".
3. Enquanto isso, protocolos seguem pelo canal combinado (e-mail/Teams); depois, registrar no Painel com o **início real do problema** em "Quando o problema começou?".

### 4.2 Todos recusados como não corporativos
1. Em Administração → Saúde do sistema, ver se há "Logins recusados" em massa.
2. Confirmar com o TI que o tenant `45ba725f-d260-45c3-ac85-11f433471277` não mudou.
3. Abrir chamado no suporte do Lovable (seção 6) pedindo a verificação do Auth e do banco.

### 4.3 Telas quebradas
1. No Lovable, abrir o histórico de versões e **publicar a última versão que funcionava**.
2. Conferir que a versão do GitHub (`main`) bate com a publicada.
3. Se a quebra veio de um commit, corrigir com **um commit novo** (nunca reescrever histórico).

### 4.4 Problema depois de uma migration
1. **Não** apagar a migration nem editar o histórico.
2. Escrever uma migration nova que desfaz a mudança (forward fix, `ROLLBACK_E_BANCO_DESCARTAVEL.md` §5).
3. CI verde → aplicar no PRIMARY → conferir `schema_migrations` (D-52).

### 4.5 Restauração do backup (perda de dados)
1. **Parar o uso**: avisar que nada deve ser aberto até a volta.
2. Abrir chamado no suporte do Lovable pedindo a **restauração do backup diário mais recente anterior ao problema** (informar data e hora do problema).
3. Depois da restauração, conferir:
   - `select count(*) from supabase_migrations.schema_migrations` igual ao número de arquivos em `supabase/migrations`;
   - se faltar alguma migration (backup antigo), aplicar as que faltam pela ordem (D-52);
   - entrar no Painel, abrir um protocolo de teste e cancelá-lo com o motivo "teste pós-restauração".
4. Recuperar o que se perdeu desde o backup (até 24 h): pedir aos donos de card a lista de protocolos do período e registrá-los de novo, com o início real do problema.
5. Registrar o tempo total (seção 7).

### 4.6 Lentidão
1. Saúde do sistema: quantas respostas lentas e em quais telas.
2. Se for geral, pedir ao Lovable a capacidade do plano atual e um aumento temporário.

---

## 5. Evidências de que o runbook funciona (CI, a cada mudança)

| Ensaio | O que prova |
|---|---|
| Reconstrução do banco a partir das migrations | a estrutura e os 11 cards voltam sozinhos |
| Ensaio de restauração cronometrado (`test-safra-restore-drill.sh`) | cópia → apagar tudo → reconstruir → restaurar → mesmos números e mesma assinatura dos protocolos → Painel abre protocolo continuando a numeração |
| Ensaio de desfazer a última migration | o caminho da seção 4.4 funciona |
| Smoke do front e teste de capacidade | o Painel funciona e aguenta o pior caso (400 pessoas, 1.000 protocolos) |

Resultados mais recentes: `AUDITORIA_C09_REABERTURA_2026-10-02.md`.

**Limite do ensaio:** a restauração **real** do PRIMARY é feita pelo Lovable; o tempo dela depende do suporte. Pendente: pedir ao Lovable o tempo típico de restauração (seção 6).

---

## 6. Contatos e perguntas abertas

| Para quem | Assunto |
|---|---|
| Suporte do Lovable | restauração de backup; capacidade do plano atual para 400 pessoas; restauração ponto a ponto (PITR) e custo |
| TI da Editora | login Microsoft, grupo de acesso, MFA, caixa de envio de e-mail (chamado aberto em 02/10/2026) |
| Donos de card | lista de protocolos durante a indisponibilidade |

---

## 7. Registro do incidente (copiar a cada ocorrência)

```text
Data/hora da detecção:
Quem detectou:
Sintoma:
Classificação (seção 3):
Avisos enviados (para quem, hora):
Ações (hora a hora):
Hora da volta:
Tempo total (RTO real):
Dados perdidos (RPO real):
Causa:
O que mudar para não repetir:
```
