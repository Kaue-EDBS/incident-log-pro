-- GI-SAFRA-013..015 (02/10/2026) — espelha docs/GOVERNANCE_ISSUES.md (D-53).
-- Origem: respostas do Lovable ao C09 (capacidade do plano, região dos dados, cabeçalhos).
-- Nenhum valor é assumido; ficam OPEN até a decisão do owner.
begin;

insert into public.governance_issues(issue_key, title, description, status)
values
  ('GI-SAFRA-013', 'Tamanho da instância do banco antes de liberar o acesso',
   'OPEN — DEFERRED_TO_ACCESS_RELEASE. O Lovable informou (02/10/2026) que a instância atual é a menor (Tiny: cerca de 1 GB de memória, 2 vCPUs compartilhadas) e que ela não aguenta 400 pessoas abrindo protocolo no mesmo minuto; recomenda subir para Small ou Medium antes de liberar o acesso, o que pode ser feito pelo painel em 2 a 5 minutos e desfeito depois do pico. O teste de capacidade do C09 (D-94) passou num computador do CI mais forte que o Tiny, então não prova a capacidade do Tiny. Decidir: (1) subir a instância antes de liberar o acesso e manter; (2) subir só nos períodos de pico; ou (3) medir antes numa cópia de homologação do mesmo tamanho. Custo a confirmar no painel do Lovable. Bloqueia a liberação do acesso às pessoas (junto com a D-79).',
   'OPEN'),
  ('GI-SAFRA-014', 'Região dos dados: Londres (AWS eu-west-2)',
   'OPEN — DEFERRED_TO_ACCESS_RELEASE. O Lovable informou (02/10/2026) que o banco e os backups ficam na AWS eu-west-2 (Londres, Reino Unido). O Painel guarda nome e e-mail corporativo das pessoas e o que elas registram nos protocolos. Decidir com o jurídico ou o encarregado de dados (DPO) da Editora se a guarda fora do Brasil é aceitável pela LGPD (transferência internacional) ou se o banco precisa ficar no Brasil (por exemplo, um projeto Supabase próprio na região de São Paulo). Nenhum valor é assumido.',
   'OPEN'),
  ('GI-SAFRA-015', 'Cabeçalhos de segurança e domínio próprio',
   'OPEN — DEFERRED_TO_ACCESS_RELEASE. Origem: auditoria do Lovable L-02 e resposta de 02/10/2026. No endereço painelsafra.lovable.app o Lovable já envia HSTS e nosniff, mas não deixa configurar Content-Security-Policy nem a proteção contra o app ser embutido em outro site (frame-ancestors/X-Frame-Options). Uma CSP pela tag meta no HTML não cobre frame-ancestors, porque o navegador ignora essa regra fora do cabeçalho. Caminho recomendado: subdomínio da Editora (ex.: safra.editoradobrasil.com.br) passando pela Cloudflare da TI, onde a TI configura os cabeçalhos e pode liberar o limite de login para o IP corporativo. Impacto: o novo endereço precisa entrar nas URLs de retorno do login. Decidir: fazer antes ou depois de liberar o acesso.',
   'OPEN')
on conflict (issue_key) do nothing;

commit;
