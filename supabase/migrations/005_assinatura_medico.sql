-- Assinatura do consultório. Paciente não tem linha aqui.
-- O aplicativo não grava status: só a função com service_role ativa o plano.

create table if not exists public.doctor_subscriptions (
  user_id uuid primary key references auth.users (id) on delete cascade,
  status text not null default 'inactive',
  source text,
  current_period_end timestamptz,
  updated_at timestamptz not null default now(),
  constraint doctor_subscriptions_status_check
    check (status in ('inactive', 'active', 'past_due', 'canceled')),
  constraint doctor_subscriptions_source_check
    check (source is null or source in ('web', 'play'))
);

alter table public.doctor_subscriptions enable row level security;

revoke all on public.doctor_subscriptions from public, anon;
grant select on public.doctor_subscriptions to authenticated;

drop policy if exists doctor_subscriptions_select_own on public.doctor_subscriptions;
create policy doctor_subscriptions_select_own
  on public.doctor_subscriptions
  for select
  to authenticated
  using (user_id = (select auth.uid()));

create or replace function private.doctor_plan_active(doctor uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select (select auth.uid()) is not null
    and exists (
      select 1
      from public.doctor_subscriptions
      where user_id = doctor
        and status = 'active'
        and (
          current_period_end is null
          or current_period_end > now()
        )
    );
$$;

revoke all on function private.doctor_plan_active(uuid) from public, anon;
grant execute on function private.doctor_plan_active(uuid) to authenticated;

create or replace function private.create_doctor_subscription()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.role = 'doctor' then
    insert into public.doctor_subscriptions (user_id, status)
    values (new.id, 'inactive')
    on conflict (user_id) do nothing;
  end if;
  return new;
end;
$$;

revoke all on function private.create_doctor_subscription() from public, anon, authenticated;

drop trigger if exists profiles_create_doctor_subscription on public.profiles;
create trigger profiles_create_doctor_subscription
  after insert on public.profiles
  for each row execute function private.create_doctor_subscription();

-- Quem já era médico antes da cobrança continua com o consultório aberto.
insert into public.doctor_subscriptions (user_id, status, source)
select id, 'active', 'web'
from public.profiles
where role = 'doctor'
on conflict (user_id) do nothing;

drop policy if exists care_grants_doctor_select on public.care_grants;
create policy care_grants_doctor_select
  on public.care_grants
  for select
  to authenticated
  using (
    doctor_id = (select auth.uid())
    and (select private.doctor_plan_active((select auth.uid())))
  );

drop policy if exists care_grants_doctor_update on public.care_grants;
create policy care_grants_doctor_update
  on public.care_grants
  for update
  to authenticated
  using (
    doctor_id = (select auth.uid())
    and status = 'pending'
    and (select private.doctor_plan_active((select auth.uid())))
  )
  with check (
    doctor_id = (select auth.uid())
    and status in ('accepted', 'revoked')
    and (select private.doctor_plan_active((select auth.uid())))
  );

drop policy if exists care_grants_patient_insert on public.care_grants;
create policy care_grants_patient_insert
  on public.care_grants
  for insert
  to authenticated
  with check (
    patient_id = (select auth.uid())
    and status = 'pending'
    and (select private.is_doctor(doctor_id))
    and (select private.doctor_plan_active(doctor_id))
  );

drop policy if exists granted_read_exam_reports on public.exam_reports;
create policy granted_read_exam_reports
  on public.exam_reports
  for select
  to authenticated
  using (
    exists (
      select 1
      from public.care_grants g
      where g.patient_id = exam_reports.user_id
        and g.doctor_id = (select auth.uid())
        and g.status = 'accepted'
        and (select private.doctor_plan_active((select auth.uid())))
    )
  );

drop policy if exists granted_read_exam_results on public.exam_results;
create policy granted_read_exam_results
  on public.exam_results
  for select
  to authenticated
  using (
    exists (
      select 1
      from public.care_grants g
      where g.patient_id = exam_results.user_id
        and g.doctor_id = (select auth.uid())
        and g.status = 'accepted'
        and (select private.doctor_plan_active((select auth.uid())))
    )
  );

create or replace view public.doctor_directory
with (security_invoker = false, security_barrier = true) as
select p.id, p.display_name, p.crm_uf, p.crm_number
from public.profiles p
join public.doctor_subscriptions s on s.user_id = p.id
where p.role = 'doctor'
  and p.crm_uf is not null
  and p.crm_number is not null
  and s.status = 'active'
  and (
    s.current_period_end is null
    or s.current_period_end > now()
  );

revoke all on public.doctor_directory from public, anon;
grant select on public.doctor_directory to authenticated;
