# PROVA COMPLETA DO PAINEL SAFRA (03/10/2026, D-141)

**Pedido do owner:** "auditoria pesada, longa e super detalhada, em todos os eixos... limpeza no código, teste de estresse, smoke, forçar todas as falhas, colocar a aplicação à prova".

## 1. Como foi feito

| Frente | O que foi feito |
|---|---|
| 6 auditorias independentes | segurança; integridade dos dados; operação e falhas; telas/UX/acessibilidade/desempenho; limpeza de código; testes e CI |
| Ataque 1 — sem login, no PRIMARY | 41 funções do Painel chamadas pela API pública; leitura e escrita em 21 tabelas; esquema privado |
| Ataque 2 — token falso, no PRIMARY | token forjado com o e-mail do owner; corpo malicioso na função de envio |
| Ataque 3 — funcionário comum logado, no PRIMARY (desfeito sozinho) | 14 ações indevidas; texto gigante; injeção de código; clique duplicado; segunda abertura; desfazer duas vezes; motivo curto; segunda proposta |
| Carga, estresse e restauração (CI) | 400 pessoas, 1.000 protocolos, pico de 400 aberturas; concorrência; restauração do backup |

## 2. Resultados dos ataques e da carga

| Teste | Resultado |
|---|---|
| Sem login: 41 funções | **41 recusadas** (401) |
| Sem login: 21 tabelas (ler e gravar) | **todas recusadas** (401); esquema privado não exposto |
| Token forjado | **recusado** em todas as chamadas |
| Função de envio com corpo malicioso | ignorou o corpo; só contagens na resposta |
| Funcionário comum: 14 ações indevidas (todos os protocolos, histórico, concluir/cancelar de outra pessoa, governança, pessoas, encerrar Safra, Indicadores de outro dono, fila de e-mails, etc.) | **14 recusadas** |
| Funcionário comum: ler a tabela de protocolos direto | **recusado** |
| Texto gigante | recusado (limite) |
| Injeção (`'); drop table ...` e `<img onerror>`) | guardado como texto; tabela intacta; a tela não executa |
| Clique duplicado na abertura | um protocolo só |
| Mesma chave com outro texto | recusado (conflito) |
| Segunda abertura no mesmo card | recusada |
| Desfazer duas vezes / motivo curto / segunda proposta | recusados |
| Carga: 14.475 chamadas | 0 erros; p95 280 ms |
| Pico: 400 aberturas juntas | 0 erros; p95 846 ms |
| Concorrência | numeração sem buraco nem repetição; clique duplicado = 1 protocolo |
| Restauração do backup | 29 s; contagens e assinatura idênticas; numeração continua |

## 3. Achados das auditorias e tratamento (D-141)

| Eixo | Achado principal | Tratamento |
|---|---|---|
| Segurança (M) | a pessoa podia trocar o próprio nome e aparecer como outra em e-mails e telas | corrigido: nome só do cadastro ou da Microsoft, sem quebras de linha |
| Segurança (M) | função de envio podia ser chamada por qualquer um na internet | corrigido: senha interna gerada no banco, enviada só pelo agendador |
| Segurança (L) | conta de fora podia gravar eventos técnicos falsos | corrigido: só registra a própria recusa |
| Segurança/Dados (L) | TRUNCATE nas tabelas novas | retirado |
| Telas (H) | Modo Camaleão deixava concluir, desfazer e cancelar | corrigido |
| Telas (H) | "sem acesso" aparecia enquanto os papéis carregavam ou se a consulta falhava | corrigido: "Conferindo o seu acesso..." e "Tentar de novo" |
| Operação (H) | e-mail parado sem alarme | corrigido: alarmes no topo da Administração |
| Operação (H) | restauração não religava o envio | corrigido: `private.safra_ensure_cron_jobs()` + runbook |
| Operação (H) | operação dos e-mails depende só do owner | GI-SAFRA-021 |
| Dados (M) | ação de governança duplicada para sempre | corrigido: vira uma só |
| Dados (M) | e-mails guardados para sempre | GI-SAFRA-020 |
| Segurança (M) | sem limite de abrir/cancelar por pessoa | GI-SAFRA-022 |
| Telas (M) | erro de regra demorava ~7 s (3 tentativas); mensagem genérica | corrigido |
| Telas (M) | "Iniciar nova Safra" sem confirmação | corrigido |
| Telas (M) | Administração com o título no fim e 6 consultas com tudo fechado | corrigido |
| Telas (M) | tabelas roláveis sem teclado; botões longos quebrando no celular | corrigido |
| Telas (M) | catálogo carregado para todo mundo na barra do Camaleão | corrigido |
| Operação (M) | rodada de 20 avisos lenta num pico | 50 por rodada |
| Dados (L) | data do "problema começou" sem limite inferior | GI-SAFRA-023 |
| Limpeza | código e tabelas sem uso | front limpo; banco: GI-SAFRA-024 |
| Testes (H) | permissões das funções não eram conferidas como "logado" | mapa fixo de permissões no CI |

## 4. Ainda aberto (decisão do owner ou baixo risco)

- GI-SAFRA-017 a 024 (aplicativo do TI, contagem semanal, semana do registro, retenção, substituto do owner, limite por pessoa, data mínima, objetos sem uso).
- Baixo risco aceito: contagens de "abertos" diferentes entre telas por causa das exclusões de demonstração; foco do teclado após ações; menu "Mais" sem foco automático; e2e só no computador (sem celular).
