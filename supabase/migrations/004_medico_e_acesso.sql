-- Papel do usuário, CRM e convite para o médico ler a Evolução.
-- O médico não lista pacientes. Só vê o convite que recebeu.
-- A leitura do laudo existe só com status accepted.
-- Não reaplicar schema.sql: a política aberta de lá já foi substituída.

alter table public.profiles
  add column if not exists role text not null default 'patient';

alter table public.profiles
  add column if not exists crm_uf text;

alter table public.profiles
  add column if not exists crm_number text;

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'profiles_role_check'
      and conrelid = 'public.profiles'::regclass
  ) then
    alter table public.profiles
      add constraint profiles_role_check
      check (role in ('patient', 'doctor'));
  end if;
end $$;

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'profiles_doctor_crm_check'
      and conrelid = 'public.profiles'::regclass
  ) then
    alter table public.profiles
      add constraint profiles_doctor_crm_check
      check (
        role <> 'doctor'
        or (
          crm_uf in (
            'AC', 'AL', 'AP', 'AM', 'BA', 'CE', 'DF', 'ES', 'GO', 'MA',
            'MT', 'MS', 'MG', 'PA', 'PB', 'PR', 'PE', 'PI', 'RJ', 'RN',
            'RS', 'RO', 'RR', 'SC', 'SP', 'SE', 'TO'
          )
          and crm_number ~ '^[0-9]{4,7}$'
        )
      );
  end if;
end $$;

create unique index if not exists profiles_crm_unique
  on public.profiles (crm_uf, crm_number)
  where role = 'doctor';

create index if not exists profiles_doctors_idx
  on public.profiles (role)
  where role = 'doctor';

-- Conta antiga continua paciente. O papel não sai do JWT: user_metadata é
-- editável. Esta função só grava o papel na criação da conta.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  meta jsonb := coalesce(new.raw_user_meta_data, '{}'::jsonb);
  new_role text := case
    when meta->>'role' = 'doctor' then 'doctor'
    else 'patient'
  end;
  new_crm_uf text := nullif(upper(btrim(meta->>'crm_uf')), '');
  new_crm_number text := nullif(btrim(meta->>'crm_number'), '');
  birth_text text := nullif(meta->>'birth_date', '');
begin
  insert into public.profiles (
    id, email, display_name, sex, birth_date, role, crm_uf, crm_number
  )
  values (
    new.id,
    coalesce(new.email, ''),
    coalesce(
      nullif(btrim(meta->>'display_name'), ''),
      split_part(coalesce(new.email, ''), '@', 1)
    ),
    nullif(meta->>'sex', ''),
    case when birth_text is null then null else birth_text::date end,
    new_role,
    case when new_role = 'doctor' then new_crm_uf else null end,
    case when new_role = 'doctor' then new_crm_number else null end
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

revoke all on function public.handle_new_user() from public, anon, authenticated;
grant execute on function public.handle_new_user() to supabase_auth_admin;

create schema if not exists private;

revoke all on schema private from public;
grant usage on schema private to authenticated;

create or replace function private.protect_profile_role()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  if new.id is distinct from old.id
     or new.role is distinct from old.role
     or new.crm_uf is distinct from old.crm_uf
     or new.crm_number is distinct from old.crm_number then
    raise exception 'Papel e CRM não podem ser alterados por aqui.';
  end if;
  return new;
end;
$$;

revoke all on function private.protect_profile_role() from public, anon;
grant execute on function private.protect_profile_role() to authenticated;

drop trigger if exists profiles_protect_role on public.profiles;
create trigger profiles_protect_role
  before update on public.profiles
  for each row execute function private.protect_profile_role();

create or replace function private.is_doctor(doctor uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select (select auth.uid()) is not null
    and exists (
      select 1
      from public.profiles
      where id = doctor
        and role = 'doctor'
    );
$$;

revoke all on function private.is_doctor(uuid) from public, anon;
grant execute on function private.is_doctor(uuid) to authenticated;

create table if not exists public.care_grants (
  id uuid primary key default gen_random_uuid(),
  patient_id uuid not null references auth.users (id) on delete cascade,
  doctor_id uuid not null references auth.users (id) on delete cascade,
  status text not null default 'pending',
  patient_name text not null default '',
  doctor_name text not null default '',
  doctor_crm_uf text not null default '',
  doctor_crm_number text not null default '',
  created_at timestamptz not null default now(),
  responded_at timestamptz,
  unique (patient_id, doctor_id),
  constraint care_grants_status_check
    check (status in ('pending', 'accepted', 'revoked')),
  constraint care_grants_distinct_people
    check (patient_id <> doctor_id)
);

create index if not exists care_grants_patient_id_idx
  on public.care_grants (patient_id);

create index if not exists care_grants_doctor_id_idx
  on public.care_grants (doctor_id);

create index if not exists care_grants_doctor_accepted_idx
  on public.care_grants (doctor_id, patient_id)
  where status = 'accepted';

create or replace function private.guard_care_grant()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor uuid := (select auth.uid());
  patient_label text;
  doctor_label text;
  crm_state text;
  crm_num text;
begin
  if actor is null then
    raise exception 'Entre na conta.';
  end if;

  if tg_op = 'INSERT' then
    if actor is distinct from new.patient_id then
      raise exception 'Só o paciente cria o convite.';
    end if;
    if new.status is distinct from 'pending' then
      raise exception 'O convite começa pendente.';
    end if;
    if new.patient_id = new.doctor_id then
      raise exception 'Escolha outro médico.';
    end if;
    if not private.is_doctor(new.doctor_id) then
      raise exception 'Este usuário não é médico.';
    end if;
  else
    if actor is distinct from old.patient_id
       and actor is distinct from old.doctor_id then
      raise exception 'Sem permissão.';
    end if;

    new.id := old.id;
    new.patient_id := old.patient_id;
    new.doctor_id := old.doctor_id;
    new.created_at := old.created_at;

    if actor = old.patient_id then
      if new.status = 'accepted' then
        raise exception 'Só o médico aceita o convite.';
      end if;
      if new.status = 'pending' and old.status = 'accepted' then
        raise exception 'Revogue o acesso antes de convidar de novo.';
      end if;
      if new.status not in ('pending', 'revoked') then
        raise exception 'Status inválido.';
      end if;
    else
      if old.status is distinct from 'pending' then
        raise exception 'Este convite já foi respondido.';
      end if;
      if new.status not in ('accepted', 'revoked') then
        raise exception 'Aceite ou recuse o convite.';
      end if;
    end if;

    if new.status is distinct from old.status
       and new.status in ('accepted', 'revoked') then
      new.responded_at := now();
    elsif new.status = 'pending' then
      new.responded_at := null;
    end if;
  end if;

  select display_name into patient_label
  from public.profiles
  where id = new.patient_id;

  select display_name, crm_uf, crm_number
    into doctor_label, crm_state, crm_num
  from public.profiles
  where id = new.doctor_id
    and role = 'doctor';

  if patient_label is null or doctor_label is null then
    raise exception 'Não foi possível identificar as pessoas do convite.';
  end if;

  new.patient_name := patient_label;
  new.doctor_name := doctor_label;
  new.doctor_crm_uf := crm_state;
  new.doctor_crm_number := crm_num;
  return new;
end;
$$;

revoke all on function private.guard_care_grant() from public, anon;
grant execute on function private.guard_care_grant() to authenticated;

drop trigger if exists care_grants_guard on public.care_grants;
create trigger care_grants_guard
  before insert or update on public.care_grants
  for each row execute function private.guard_care_grant();

alter table public.care_grants enable row level security;

revoke all on public.care_grants from anon;
grant select, insert, update on public.care_grants to authenticated;

drop policy if exists care_grants_patient_select on public.care_grants;
create policy care_grants_patient_select
  on public.care_grants
  for select
  to authenticated
  using (patient_id = (select auth.uid()));

drop policy if exists care_grants_doctor_select on public.care_grants;
create policy care_grants_doctor_select
  on public.care_grants
  for select
  to authenticated
  using (doctor_id = (select auth.uid()));

drop policy if exists care_grants_patient_insert on public.care_grants;
create policy care_grants_patient_insert
  on public.care_grants
  for insert
  to authenticated
  with check (
    patient_id = (select auth.uid())
    and status = 'pending'
    and (select private.is_doctor(doctor_id))
  );

drop policy if exists care_grants_patient_update on public.care_grants;
create policy care_grants_patient_update
  on public.care_grants
  for update
  to authenticated
  using (patient_id = (select auth.uid()))
  with check (
    patient_id = (select auth.uid())
    and status in ('pending', 'revoked')
  );

drop policy if exists care_grants_doctor_update on public.care_grants;
create policy care_grants_doctor_update
  on public.care_grants
  for update
  to authenticated
  using (
    doctor_id = (select auth.uid())
    and status = 'pending'
  )
  with check (
    doctor_id = (select auth.uid())
    and status in ('accepted', 'revoked')
  );

-- A view não usa security_invoker de propósito: a política de profiles só
-- devolve a própria linha. Aqui saem só nome e CRM de quem é médico.
drop view if exists public.doctor_directory;
create view public.doctor_directory
with (security_invoker = false, security_barrier = true) as
select id, display_name, crm_uf, crm_number
from public.profiles
where role = 'doctor'
  and crm_uf is not null
  and crm_number is not null;

revoke all on public.doctor_directory from public, anon;
grant select on public.doctor_directory to authenticated;

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
    )
  );
