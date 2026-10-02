# Painel Safra — Editora do Brasil

Torre corporativa de governança de contingências. Este repositório (`incident-log-pro`) contém um único produto: o Painel Safra.

> **Reliability Monitor/MTTR descontinuado (D-50, 30/09/2026).** O projeto nasceu como um monitor de incidentes de TI com MTTD, MTTR, MTBF e disponibilidade. Esse produto foi retirado: tabelas, telas e métricas foram removidas. A especificação original continua no histórico Git (commit `8c38efe`).

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

Use esta estrutura como fonte canônica:

- [docs/ROADMAP.md](docs/ROADMAP.md) — fases, gates e ordem de execução;
- [docs/STATUS.md](docs/STATUS.md) — estado atual, evidências e bloqueios;
- [docs/ARQUITETURA.md](docs/ARQUITETURA.md) — arquitetura real/alvo;
- [docs/PROJECT_PROFILE.yaml](docs/PROJECT_PROFILE.yaml) — perfil estruturado do projeto;
- [docs/PRIVACIDADE_THREAT_MODEL.md](docs/PRIVACIDADE_THREAT_MODEL.md) — privacidade e ameaças;
- [docs/REGRAS_NEGOCIO.md](docs/REGRAS_NEGOCIO.md) — regras e invariantes;
- [docs/MATRIZ_PARIDADE.md](docs/MATRIZ_PARIDADE.md) — legado x produto-alvo;
- [docs/DECISOES.md](docs/DECISOES.md) — decisões e ADRs.
- [docs/GOVERNANCE_ISSUES.md](docs/GOVERNANCE_ISSUES.md) — pendências de governança (fonte oficial dos GI-SAFRA);
- [docs/GLOSSARIO_DOMINIO.md](docs/GLOSSARIO_DOMINIO.md) — vocabulário e modelo de domínio;
- [docs/historico/](docs/historico/) — versões anteriores do STATUS e do ROADMAP, preservadas sem alteração.

> Em caso de conflito, prevalecem os documentos canônicos acima conforme a autoridade de cada tema.
