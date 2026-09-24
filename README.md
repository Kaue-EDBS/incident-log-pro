# MTTR

Crie um projeto chamado "Reliability Monitor" para a Editora do Brasil, seguindo esta especificação de MVP.

OBJETIVO
Aplicação web interna, responsiva e minimalista para registrar incidentes de indisponibilidade e calcular automaticamente MTTD, MTTR, MTBF, downtime, quantidade de incidentes e disponibilidade.

IDENTIDADE VISUAL
Usar a identidade da Editora do Brasil com visual corporativo, moderno, limpo e bastante espaço em branco. Cores principais: azul institucional #19286E, turquesa #00C3B3, verde-limão #93D50A. Auxiliares: fundo #F7F8FA, cards #FFFFFF, texto #1F2937, secundário #667085, borda #E5E7EB, incidente #DC3545, alerta #F59E0B. O vermelho deve ser reservado a incidentes/erros. Evitar gradientes chamativos, excesso de sombras e aparência de dashboard genérico. O logo da Editora do Brasil será adicionado depois caso o anexo não esteja disponível nesta criação.

NAVEGAÇÃO
Sidebar no desktop e navegação adaptada no mobile com: Visão Geral, Novo Incidente, Incidentes, Aplicações e Indicadores.

APLICAÇÕES INICIAIS
Criar XPTO, ABC e SEP, todas iniciando como Operacional.

VISÃO GERAL
Cabeçalho com filtros de período (Hoje, 7 dias, 30 dias, Este mês, Personalizado) e aplicação (Todas, XPTO, ABC, SEP). Mostrar card por aplicação com status, disponibilidade, último incidente e cronômetro se houver incidente ativo. Cards principais: MTTD, MTTR, MTBF e Disponibilidade, com tooltip explicativo.

FLUXO PRINCIPAL
Novo Incidente: selecionar aplicação e tipo (Indisponibilidade, Lentidão, Erro de aplicação, Banco de dados, Infraestrutura, Integração, Outro). Botão grande INICIAR INCIDENTE em vermelho. Ao clicar: criar incidente, gravar detected_at, iniciar cronômetro, marcar aplicação como Incidente em andamento e abrir tela do incidente.

INCIDENTE EM ANDAMENTO
Dar destaque ao cronômetro. Mostrar aplicação, status, detected_at, campo failure_started_at, response_started_at com botão "Usar horário atual", responsável e observações. Botão grande APLICAÇÃO RECUPERADA em verde. Ao clicar: gravar recovered_at, parar cronômetro, marcar aplicação como Operacional e abrir finalização.

FINALIZAÇÃO
Exibir resumo com início da falha, detecção, recuperação, downtime, tempo para detecção e tempo para recuperação. Solicitar categoria, causa, solução aplicada e observações. Botão Salvar incidente.

CRONÔMETRO PERSISTENTE
Não depender apenas de estado local. Salvar detected_at no banco e reconstruir o cronômetro sempre como horário atual - detected_at, para sobreviver a refresh, fechamento do navegador e troca de computador.

TIMESTAMPS
incidents deve possuir failure_started_at, detected_at, response_started_at, recovered_at, created_at e updated_at.

MÉTRICAS
MTTD por incidente = detected_at - failure_started_at. Média apenas de incidentes válidos; sem failure_started_at não entra no MTTD.
MTTR = recovered_at - detected_at. Média apenas de incidentes encerrados.
Downtime = recovered_at - failure_started_at; se failure_started_at estiver ausente, usar detected_at provisoriamente e sinalizar como estimado.
MTBF deve ser calculado separadamente por aplicação: próxima failure_started_at - recovered_at do incidente anterior; média dos intervalos válidos.
Disponibilidade, para o MVP 24x7 = (tempo total do período - downtime) / tempo total do período * 100.
Não armazenar mttd_minutes, mttr_minutes, downtime_minutes e mtbf_minutes como fonte principal; calcular a partir dos timestamps.

HISTÓRICO
Tabela com Data, Aplicação, Categoria, Downtime, MTTD, MTTR e Status. Filtros por período, aplicação, categoria e status. Clique abre detalhes.

DETALHES DO INCIDENTE
Timeline: Falha iniciada -> Falha detectada (mostrar MTTD) -> Atuação iniciada -> Aplicação recuperada (mostrar MTTR). Mostrar responsável, categoria, causa, solução, observações e downtime.

APLICAÇÕES
Resumo por aplicação com status, número de incidentes, MTTD, MTTR, MTBF e disponibilidade. Preparar para cadastro/edição/ativação-desativação futura.

INDICADORES
Gráficos: incidentes por aplicação, MTTR por aplicação, MTTD por aplicação e incidentes ao longo do tempo. Tabela comparativa ordenável com Aplicação, Incidentes, MTTD, MTTR, MTBF e Disponibilidade.

BACKEND
Usar Supabase/PostgreSQL. Tabela applications: id UUID PK, name TEXT NOT NULL, description TEXT, is_active BOOLEAN DEFAULT TRUE, created_at TIMESTAMPTZ, updated_at TIMESTAMPTZ. Seeds: XPTO, ABC, SEP.
Tabela incidents: id UUID PK, application_id UUID, status TEXT, failure_started_at TIMESTAMPTZ, detected_at TIMESTAMPTZ, response_started_at TIMESTAMPTZ, recovered_at TIMESTAMPTZ, category TEXT, responsible TEXT, cause TEXT, resolution TEXT, notes TEXT, created_at TIMESTAMPTZ, updated_at TIMESTAMPTZ. Status: active ou resolved.

REGRAS DE INTEGRIDADE
Validar failure_started_at <= detected_at; detected_at <= recovered_at; se response_started_at existir, detected_at <= response_started_at <= recovered_at. Evitar datas futuras inadvertidas. Uma aplicação não pode ter dois incidentes ativos simultaneamente. Se já houver um, oferecer Abrir incidente existente.

DADOS DEMO
Popular com incidentes históricos coerentes para o dashboard não ficar vazio: XPTO com 5 incidentes, MTTR médio ~28 min e MTTD ~7 min; ABC com 4 incidentes, MTTR ~41 min e MTTD ~11 min; SEP com 3 incidentes, MTTR ~19 min e MTTD ~5 min.

RESPONSIVIDADE E UX
Desktop, notebook, tablet e smartphone. O fluxo de iniciar/encerrar incidente deve ser prioridade no mobile. Microinterações discretas. Tela vazia: "Todas as aplicações estão operacionais" e "Nenhum incidente em andamento neste momento".

ESCOPO OBRIGATÓRIO
Dashboard, aplicações XPTO/ABC/SEP, início de incidente, cronômetro persistente, encerramento, timestamps, histórico, MTTD, MTTR, MTBF, downtime, disponibilidade, filtros, dados fictícios, Supabase e layout responsivo.

FORA DO MVP
Não implementar monitoramento automático, Datadog, Grafana, New Relic, Azure Monitor, chamados automáticos, Teams, Slack, push, SMS, IA ou análise automática de causa raiz.

PRIORIDADE
1 visual e navegação; 2 banco de aplicações; 3 criação de incidente; 4 cronômetro persistente; 5 encerramento; 6 histórico; 7 métricas; 8 dashboard; 9 filtros; 10 refinamento visual/responsivo.

Critério de sucesso: o usuário deve registrar o incidente em poucos segundos, acompanhar o cronômetro, marcar a recuperação, complementar os dados e ter todas as métricas atualizadas automaticamente. O banco é a fonte da verdade.

This project was built with [Lovable](https://lovable.dev).

## Build with Lovable

Continue developing this project in the [Lovable editor](https://lovable.dev/projects/27aaa43d-ca38-4c18-96c0-eb54a37a1792).

- **Ship faster**: describe what you want to build and Lovable handles the code.
- **Stay in sync**: every change made in Lovable is committed straight to this repository.
- **Full ownership**: this code is yours. Push to `main` on GitHub and your changes sync back into Lovable, ready for your next prompt.

## Development

Prefer working locally? You need Node.js and npm — [install with nvm](https://github.com/nvm-sh/nvm#installing-and-updating).

```sh
git clone <this-repository-url>
cd <repository-name>
npm i
npm run dev
```

## Documentação canônica do Painel Safra

O plano de evolução do `incident-log-pro` para o **Painel Safra** está documentado em:

- [docs/ROADMAP.md](docs/ROADMAP.md) — roadmap v2.0 completo, estruturado em COMEÇO → MEIO → FIM e alinhado à Matriz de Contingência v3, Protocolos de Contingência v2, decisões da reunião de 22/09/2026 e Framework EBSA v1.7.

> O conteúdo acima do README registra o escopo histórico do Reliability Monitor/MTTR. Para a reformulação do produto como Painel Safra, prevalece o roadmap canônico em `docs/ROADMAP.md`.
