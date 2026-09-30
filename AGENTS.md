<!-- LOVABLE:BEGIN -->
> [!IMPORTANT]
> This project is connected to [Lovable](https://lovable.dev). Avoid rewriting
> published git history — force pushing, or rebasing/amending/squashing commits
> that are already pushed — as it rewrites history on Lovable's side and the
> user will likely lose their project history.
>
> Commits you push to the connected branch sync back to Lovable and show up in
> the editor, so keep the branch in a working state.
<!-- LOVABLE:END -->

## Regras do projeto (Painel Safra)

1. **Banco só por arquivo (D-52).** Toda mudança no banco começa como arquivo em `supabase/migrations/`, commitado no GitHub antes de ser aplicado no PRIMARY. Não alterar o banco direto pelo chat ou editor SQL sem esse arquivo.
2. **Conferência no início da sessão (D-52).** Comparar `supabase_migrations.schema_migrations` do PRIMARY com os arquivos de `supabase/migrations/` e reportar qualquer diferença nova.
3. **Fontes oficiais.** Leia `docs/STATUS.md` (onde estamos), `docs/ROADMAP.md` (fases), `docs/DECISOES.md` (decisões), `docs/GOVERNANCE_ISSUES.md` (pendências) e `docs/PROJECT_PROFILE.yaml` (ficha técnica) antes de mexer.
4. **Produto único (D-50).** O repositório contém só o Painel Safra. Não recriar o Reliability Monitor/MTTR.
5. **Sem inventar regra de negócio.** Pergunta sem resposta vira GI em `docs/GOVERNANCE_ISSUES.md`, nunca um valor padrão.
