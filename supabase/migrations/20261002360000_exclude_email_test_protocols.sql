-- D-115 (02/10/2026): os 11 protocolos do teste real de e-mail (um por card, abertos pelo Kaue
-- às 19:04 e cancelados em seguida) ficam fora dos Indicadores. O protocolo em si não muda.
-- Só onde o login do owner existe (no banco do CI não há esses protocolos: nada acontece).
begin;

do $$
declare
  v_owner uuid;
begin
  select u.id into v_owner from auth.users u where lower(u.email) = 'kaue.pastrello@editoradobrasil.com.br';
  if v_owner is null then
    return;
  end if;
  insert into public.treatment_analytics_exclusions(treatment_id, reason, excluded_by)
  select t.id, 'Teste real do envio de e-mails (02/10/2026): um protocolo por card, cancelado em seguida.', v_owner
  from public.treatments t
  where t.opened_by = v_owner
    and t.impact_summary like 'TESTE do envio de e-mails do Painel Safra%'
  on conflict (treatment_id) do nothing;
end;
$$;

commit;
