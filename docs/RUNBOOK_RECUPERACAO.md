# RUNBOOK DE RECUPERAÇÃO — Painel Safra

**Versão:** 1.1 — 02/10/2026 (SAFRA-C09; respostas do Lovable incorporadas)  
**Meta (D-93):** perda máxima de dados de **até 24 h** (RPO) e volta em **até 4 h** (RTO).  
**Quem aciona:** Kaue Pastrello (owner). Substitutos: Amanda Bueno, João Jurado, Vinicius Moraes (platform admins).

> Regra de ouro: **não improvisar no banco de produção (PRIMARY)**. Toda mudança de estrutura nasce em `supabase/migrations` (D-52). Em dúvida, pare e registre.

---

## 1. O que existe para recuperar

| Peça | Onde está | Como volta |
|---|---|---|
| Estrutura do banco e os 11 cards | `supabase/migrations` no GitHub | reconstrução automática (o CI faz isso a cada mudança, em cerca de 2 min) |
| Protocolos, eventos, vínculos de login, auditoria, registro técnico | só no banco PRIMARY (AWS eu-west-2, Londres) | **backup diário do Lovable Cloud**, guardado por cerca de 14 dias, com dados e logins (`auth.users`, `auth.identities`) |
| Telas | GitHub + publicação do Lovable | publicar de novo no Lovable |
| Login | Microsoft Entra ID (TI) + intermediário de login do Lovable | TI / suporte do Lovable |

---

## 2. Primeiros 15 minutos (qualquer incidente)

> Sem monitor externo (D-97): o Painel fora do ar é percebido por quem usa ou pela página de status do Lovable. Quem perceber avisa o Kaue.

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
| Muito lento | carga ou plano pequeno | ver Saúde do sistema; aumentar a instância pelo painel | 4.6 |
| Avisos por e-mail não chegam | envio desligado, segredo vencido ou Microsoft fora | Saúde do sistema → avisos; TI | 4.7 |

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
A restauração é feita **por nós, no painel do Lovable**, sem chamado. O suporte do plano Pro pode levar até 24 h úteis para responder, então não dependa dele.

1. **Parar o uso**: avisar que nada deve ser aberto até a volta.
2. **Guardar o que existe agora** (a restauração substitui o banco inteiro): Cloud → Advanced settings → **Export data**. O arquivo tem dados pessoais: guardar só no armazenamento corporativo da Editora, **nunca** no GitHub, no CI ou em e-mail pessoal.
3. Cloud → Database → **Backups** → escolher o backup diário mais recente **anterior** ao problema → restaurar. Tempo informado pelo Lovable: 5 a 15 min; o Painel fica sem banco por 3 a 10 min (as telas abrem, mas as ações dão erro de conexão).
4. Depois da restauração, conferir:
   - `select count(*) from supabase_migrations.schema_migrations` igual ao número de arquivos em `supabase/migrations`;
   - se faltar alguma migration (backup antigo), aplicar as que faltam pela ordem (D-52);
   - `select jobname from cron.job` mostra os 2 agendamentos (`safra-auto-cancel-72h` e `safra-cron-log-cleanup`, D-101); se faltar, reaplicar a migration `20261002160000`;
   - entrar no Painel, abrir um protocolo de teste e cancelá-lo com o motivo "teste pós-restauração".
5. Recuperar o que se perdeu desde o backup (até 24 h): comparar com o export do passo 2 e com a lista dos donos de card, e registrar de novo os protocolos do período, com o início real do problema.
6. Registrar o tempo total (seção 7).

### 4.6 Lentidão
1. Saúde do sistema: quantas respostas lentas e em quais telas.
2. Se for geral: Cloud → Advanced settings → **Upgrade instance** (2 a 5 min). A instância atual é a menor (Tiny: ~1 GB de memória, 2 vCPUs compartilhadas). Reduzir de novo depois do pico.
3. Se muita gente não consegue **entrar** ao mesmo tempo: o login tem limite de tentativas por IP, e a Editora sai para a internet por um IP só. Pedir que as pessoas entrem aos poucos; quem já entrou continua logado.


### 4.7 Avisos por e-mail não chegam (M05)
1. **Saúde do sistema** (Administração): "Avisos na fila", "enviados", "com falha" e "expirados" nas últimas 24 h.
2. **Envio provisório (D-133):** a cada 2 minutos o banco chama a função `safra-send-notifications`, que envia pela conexão Outlook do Lovable. Conferir o agendamento (`select * from cron.job_run_details where command like '%safra-send-notifications%' order by start_time desc limit 5`) e a resposta da função (`select status_code, content from net._http_response order by created desc limit 5`). `disabled`: a conexão Outlook não chegou à função. Aviso `FAILED` com `SEND_FAILED: NO_REPORT`: foi pego 5 vezes sem resultado (rodada interrompida); conferir se o destinatário recebeu antes de reenviar. Falhas `HTTP 401`: reconectar o Microsoft Outlook em Connectors no Lovable.
3. **Fila crescendo e nada enviado (depois da troca pelo App do TI):** o envio está desligado ou parado. Conferir se os 3 segredos (`MS_TENANT_ID`, `MS_CLIENT_ID`, `MS_CLIENT_SECRET`; `MAIL_SENDER` é opcional) estão no projeto do Lovable e se o agendamento do envio existe (`select jobname from cron.job`).
4. **Muitos "com falha":** abrir o histórico de um protocolo afetado (gestão/admin) e ver o motivo. `TOKEN_HTTP_401`: o **segredo do aplicativo venceu** ou foi trocado; pedir um novo ao TI e atualizar no Lovable. `HTTP 403`: a permissão Mail.Send ou a restrição da caixa mudou; chamado ao TI. `HTTP 429/503`: Microsoft lenta; o Painel tenta de novo sozinho (até 5 vezes).
5. **Status da Microsoft:** https://status.cloud.microsoft (ou o Centro de administração do Microsoft 365, pelo TI).
6. **Avisos perdidos não são reenviados** (expiram em 24 h, para ninguém receber aviso velho). Se a falha durou mais que isso, avisar os donos de card para olharem "Protocolos dos meus cards".
7. Registrar o incidente (seção 7).

---

## 5. Evidências de que o runbook funciona (CI, a cada mudança)

| Ensaio | O que prova |
|---|---|
| Reconstrução do banco a partir das migrations | a estrutura e os 11 cards voltam sozinhos |
| Ensaio de restauração cronometrado (`test-safra-restore-drill.sh`) | cópia → apagar tudo → reconstruir → restaurar → mesmos números e mesma assinatura dos protocolos → Painel abre protocolo continuando a numeração |
| Ensaio de desfazer a última migration | o caminho da seção 4.4 funciona |
| Smoke do front e teste de capacidade | o Painel funciona e aguenta o pior caso (400 pessoas, 1.000 protocolos) |

Resultados mais recentes: `AUDITORIA_C09_REABERTURA_2026-10-02.md`.

**Tempo real (Lovable, 02/10/2026):** restauração pelo painel em 5 a 15 min, com 3 a 10 min sem banco. Somando a conferência do §4.5, a volta fica bem dentro das 4 h da D-93.

---

## 6. Contatos e perguntas abertas

| Para quem | Assunto |
|---|---|
| Suporte do Lovable (https://lovable.dev/support; até 24 h úteis no plano Pro) | incidente da plataforma; página de status https://status.lovable.dev (assinar avisos por e-mail) |
| TI da Editora | login Microsoft, grupo de acesso, MFA, caixa de envio de e-mail (chamado aberto em 02/10/2026); subdomínio próprio (GI-SAFRA-015). Sem monitor externo de disponibilidade (D-97) |
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
