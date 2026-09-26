-- SAFRA-C07 — sincroniza lacunas de governança canônicas.
-- OPEN no banco equivale a WAITING_HUMAN_DECISION na documentação.
-- Nenhuma issue é resolvida ou recebe default por esta migration.

insert into public.governance_issues(issue_key,title,description,status)
values
(
  'GI-SAFRA-002',
  'Thresholds abertos dos cenários 2, 4, 10 e 11',
  'WAITING_HUMAN_DECISION. SAFRA-02: definir o valor de X h no gatilho de transportadora sem coleta/atualização. SAFRA-04: definir o valor de X min entre pagamento aprovado no GoDeep e espelho no Protheus. SAFRA-10: definir o limite quantitativo de lead time/fila que caracteriza colapso de picking/esteira. SAFRA-11: definir capacidade planejada e limiar quantitativo que caracteriza pico acima da capacidade. Nenhum valor pode ser inferido pela aplicação, migration ou LLM. Afeta C07 e automações futuras.',
  'OPEN'
),
(
  'GI-SAFRA-003',
  'Fonte oficial do mínimo da curva A no cenário 9',
  'WAITING_HUMAN_DECISION. SAFRA-09 depende de uma fonte/regra oficial para definir o saldo mínimo de SKU curva A. Até decisão formal, a aplicação não pode inferir o mínimo, classificar ruptura automaticamente nem transformar o texto em threshold estruturado.',
  'OPEN'
),
(
  'GI-SAFRA-004',
  'Tratativas simultâneas do mesmo cenário',
  'WAITING_HUMAN_DECISION. Definir se um mesmo cenário pode possuir mais de uma treatment ACTIVE simultaneamente. Até decisão em SAFRA-M01, nenhuma constraint de unicidade por cenário ACTIVE deve ser criada.',
  'OPEN'
),
(
  'GI-SAFRA-005',
  'Canal/provider de notificações e comportamento dos platform admins',
  'WAITING_HUMAN_DECISION. Definir provider/canal produtivo de notificações e se platform admins recebem comunicação operacional, em quais eventos e condições. Fase responsável: SAFRA-M05.',
  'OPEN'
),
(
  'GI-SAFRA-006',
  'Janela temporal oficial da Safra corrente',
  'WAITING_HUMAN_DECISION. Definir início, fim, timezone e regra de corte da Safra corrente para métricas, e-mails e análises. Fases responsáveis: SAFRA-M05 e SAFRA-F04.',
  'OPEN'
),
(
  'GI-SAFRA-007',
  'Publicação formal do 12º card após ownership',
  'WAITING_HUMAN_DECISION. Após definição do owner do 12º card, definir quem aprova protocolo, SLA e criticidade e qual evento/condição torna a primeira scenario_version PUBLISHED. Nenhuma proposta pode ser publicada por inferência. Fase responsável: SAFRA-M10.',
  'OPEN'
),
(
  'GI-SAFRA-008',
  'Janela oficial da governança semanal',
  'WAITING_HUMAN_DECISION. Definir periodicidade, horário, timezone e corte de dados do ritual de governança semanal. Fase responsável: SAFRA-F05.',
  'OPEN'
),
(
  'GI-SAFRA-009',
  'Mapeamento formal dos eventos dos SLAs textuais',
  'WAITING_HUMAN_DECISION. Os 11 cenários possuem SLA textual preservado, mas a criação de scenario_slas exige definir explicitamente, por SLA mensurável, start_event, end_event e alvo estruturado. Também deve ser decidido quando um texto representa mais de um relógio. Até essa definição, scenario_slas permanece sem seed produtivo e a engine C07 retorna NOT_MEASURABLE para alvo/eventos ausentes.',
  'OPEN'
)
on conflict (issue_key) do nothing;
