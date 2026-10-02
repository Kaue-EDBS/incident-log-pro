-- 02/10/2026 — D-116 e limpeza da M05.
--
-- D-116 decisão final do owner sobre as respostas do Lovable: nada muda.
--       GI-SAFRA-013: a instância do banco fica no tamanho atual (Tiny); risco do pico aceito.
--       GI-SAFRA-014: os dados ficam em Londres (AWS eu-west-2).
--       GI-SAFRA-015: o Painel fica em painelsafra.lovable.app, sem domínio próprio.
-- Limpeza: a escada antiga de lembretes (2 h, 4 h e de hora em hora, D-76) foi substituída
-- pela D-112 na M05; a função sem uso sai para ninguém usá-la por engano.
begin;

drop function private.safra_reminder_steps(timestamptz, timestamptz, timestamptz, timestamptz, timestamptz);

do $$
declare
  v_owner uuid;
begin
  select u.id into v_owner from auth.users u where lower(u.email) = 'kaue.pastrello@editoradobrasil.com.br';
  if v_owner is null then
    return;
  end if;

  update public.governance_issues
     set status = 'RESOLVED', resolved_by = v_owner,
         resolution_text = 'D-116 (02/10/2026): decisão final do owner, nada muda; a instância do banco fica no tamanho atual e o risco do pico de 400 pessoas no mesmo minuto é aceito.'
   where issue_key = 'GI-SAFRA-013' and status = 'OPEN';

  update public.governance_issues
     set status = 'RESOLVED', resolved_by = v_owner,
         resolution_text = 'D-116 (02/10/2026): decisão final do owner, nada muda; os dados ficam na AWS eu-west-2 (Londres).'
   where issue_key = 'GI-SAFRA-014' and status = 'OPEN';

  update public.governance_issues
     set status = 'RESOLVED', resolved_by = v_owner,
         resolution_text = 'D-116 (02/10/2026): decisão final do owner, nada muda; o Painel fica em painelsafra.lovable.app, sem domínio próprio nem cabeçalhos customizados.'
   where issue_key = 'GI-SAFRA-015' and status = 'OPEN';
end;
$$;

commit;
