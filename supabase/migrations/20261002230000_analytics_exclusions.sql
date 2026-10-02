-- D-115 (02/10/2026) — protocolos fora do analytics.
-- Protocolo de demonstração ou teste não entra nos números da Safra. O protocolo continua
-- como está (é imutável depois de fechado); a exclusão é um registro à parte, com motivo e
-- autor, que o analytics (F01/F04) vai respeitar.
-- Primeiro caso: 03-0001, aberto pelo Kaue em 02/10/2026 para mostrar o Painel à liderança.
begin;

create table public.treatment_analytics_exclusions (
  treatment_id uuid primary key references public.treatments(id) on delete restrict,
  reason text not null,
  excluded_by uuid references auth.users(id) on delete restrict,
  excluded_at timestamptz not null default clock_timestamp(),
  constraint treatment_analytics_exclusions_reason_len check (length(btrim(reason)) between 10 and 500)
);

alter table public.treatment_analytics_exclusions enable row level security;
revoke all on public.treatment_analytics_exclusions from public, anon, authenticated;
create index idx_treatment_analytics_exclusions_excluded_by on public.treatment_analytics_exclusions(excluded_by);

comment on table public.treatment_analytics_exclusions is
  'D-115: protocols left out of analytics (demos/tests), with reason and author. The protocol itself is never changed.';

do $$
declare
  v_owner uuid;
  v_treatment uuid;
begin
  select u.id into v_owner from auth.users u where lower(u.email) = 'kaue.pastrello@editoradobrasil.com.br';
  select t.id into v_treatment from public.treatments t where t.protocol_number = '03-0001' and t.opened_by = v_owner;
  if v_owner is not null and v_treatment is not null then
    insert into public.treatment_analytics_exclusions(treatment_id, reason, excluded_by)
    values (v_treatment, 'Demonstração do Painel para a liderança (owner, 02/10/2026).', v_owner)
    on conflict (treatment_id) do nothing;
  end if;
end;
$$;

commit;
