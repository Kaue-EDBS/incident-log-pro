# AUDITORIA — Frontend, backend e UX (02/10/2026, D-137)

**Pedido do owner:** "audite frontend, backend e ux". Três revisões independentes sobre o código depois da D-134, D-135 e D-136; cada achado conferido de novo no código.
**Correções:** D-137, migration `20261002350000_audit2_backend_fixes.sql` e ajustes de tela.

## 1. Backend (nenhum crítico ou alto)

| # | Gravidade | Achado | Tratamento |
|---|---|---|---|
| B1 | média | Duplo clique ou duas abas criavam duas propostas em andamento | corrigido: índice único por pessoa; o segundo envio recebe a mensagem de "já tem uma proposta" |
| B2 | média | A rodada de envio podia passar do tempo do agendador (60 s); aviso não tentado gastava tentativa | corrigido: rodada de 40 s contada desde o início; aviso não tentado volta sem gastar tentativa |
| B3 | baixa/média | Dono que perde o papel antes da publicação travava a proposta com erro técnico | corrigido: aprovar e publicar conferem e dizem com clareza |
| B4 | baixa | Falha ao pedir acesso à Microsoft registrava resultado sem a proteção de nova tentativa | corrigido |
| B5 | baixa | Envio confirmado depois da trava vencida era ignorado (e-mail sairia de novo) | corrigido: envio confirmado sempre vale |
| B6 | baixa | Lembrete chegava para quem já tinha concluído a sua parte | corrigido: o lembrete não sai |
| B10 | baixa | Leituras da fila de e-mails sem índice por data | corrigido: índices; restante (retenção, consultas de protocolos) fica para quando o volume crescer |
| B7, B8, B9, B11, B12 | baixa | Aprovação sem conferir versão do conteúdo; dono de card novo no meio da consulta; repetir abertura depois do fim da Safra; contagens diferentes entre telas; código sem efeito | aceitos (baixo risco) e registrados |

## 2. Frontend (nenhum crítico)

| # | Gravidade | Achado | Tratamento |
|---|---|---|---|
| F1 | média | Falha de conexão na conferência de acesso deixava a pessoa presa no login | corrigido: botão "Tentar de novo" |
| F2 | média | A seção "Agora" fechava sozinha ao trocar o filtro | corrigido |
| F3 | média | O dono consultado não via a própria resposta | corrigido: "Sua resposta: ..." |
| F4 | média | "Desfazer conclusão" continuava aparecendo depois dos 5 minutos | corrigido |
| F5–F8 | baixa | ARIA da seção fechada; lista de andamento vazia; formulário com proposta já aberta; texto do registro do dono | corrigidos |

## 3. UX

| # | Gravidade | Achado | Tratamento |
|---|---|---|---|
| U15/U27/U18 | alta/média | Seções fechadas escondiam o principal ("Agora", situação da Safra, card que mais falha) | corrigido: o resumo aparece no título fechado |
| U19 | alta | Quem já tinha proposta preenchia tudo e só no fim descobria que não podia enviar | corrigido: aviso no lugar do formulário |
| U22 | média | Publicar, aprovar, recusar e "Não aceito" sem confirmação | corrigido: confirmação antes |
| U4 | média | Botões de confirmar com 36 px | corrigido: 44 px |
| U5, U8, U13, U21, U23–U26, U28 | baixa/média | códigos "D-xx" na tela; protocolos do Início não clicáveis; atributo ARIA errado; mínimos de caracteres sem aviso; texto do processo; "Sua vez"; tentar de novo; "Em construção" no topo; trilha de papéis com códigos | corrigidos |
| U2, U3, U11, U16, U17 | média | nomes de menu e botões ("Novo card", "Analytics", "Em andamento", "Iniciar/Abrir protocolo", menu de baixo com 8 itens) | **perguntas ao owner** (nomes são decisão dele) |
| U1, U7, U9, U10, U12, U14 | média/baixa | "Voltar" fecha o card aberto; aviso antes de perder o texto; ordem no celular; contagem de protocolos abertos no card; Safra encerrada; formato do tempo | próximos ajustes (pedem mudança maior ou decisão) |
