-- D-139 (03/10/2026, owner): a M11 (fontes reais / detecção automática) está cancelada. O Painel não
-- terá detecção automática: todo protocolo é aberto por uma pessoa. Os limites dos cenários 2, 4, 10
-- e 11 (GI-SAFRA-002) e a fonte do mínimo da curva A do cenário 9 (GI-SAFRA-003) só serviam à
-- detecção automática e deixam de ser necessários.
-- Só onde o login do owner existe (como na GI-SAFRA-007): o banco descartável do CI não muda.
begin;

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
         resolution_text = 'D-139 (03/10/2026): sem detecção automática (M11 cancelada). Todo protocolo é aberto manualmente; os limites dos cenários 2, 4, 10 e 11 não são necessários.'
   where issue_key = 'GI-SAFRA-002' and status = 'OPEN';
  update public.governance_issues
     set status = 'RESOLVED', resolved_by = v_owner,
         resolution_text = 'D-139 (03/10/2026): sem detecção automática (M11 cancelada). SAFRA-09 segue com abertura manual; a fonte do mínimo da curva A não é necessária.'
   where issue_key = 'GI-SAFRA-003' and status = 'OPEN';
end;
$$;

commit;
