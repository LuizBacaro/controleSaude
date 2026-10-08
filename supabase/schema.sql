-- ProjetoExames (xdzognwurazkbmckzldf)
-- Laudos importados e cada resultado, com a data da coleta.

create table if not exists public.exam_reports (
  id uuid primary key,
  collected_at timestamptz not null,
  imported_at timestamptz not null default now(),
  patient_name text,
  lab_name text,
  source_file_name text,
  notes text
);

create table if not exists public.exam_results (
  id uuid primary key default gen_random_uuid(),
  report_id uuid not null references public.exam_reports (id) on delete cascade,
  marker_id uuid not null,
  marker_name text not null,
  value double precision not null,
  unit text not null default '',
  collected_at timestamptz not null,
  category text not null default 'Geral',
  reference_text text,
  reference_min double precision,
  reference_max double precision,
  origin text not null default 'imported',
  is_current boolean not null default true
);

create index if not exists exam_results_name_date_idx
  on public.exam_results (marker_name, collected_at);

create index if not exists exam_results_report_idx
  on public.exam_results (report_id);

alter table public.exam_reports enable row level security;
alter table public.exam_results enable row level security;

grant usage on schema public to anon, authenticated;
grant select, insert, update, delete on public.exam_reports to anon, authenticated, service_role;
grant select, insert, update, delete on public.exam_results to anon, authenticated, service_role;

drop policy if exists anon_all_exam_reports on public.exam_reports;
create policy anon_all_exam_reports
  on public.exam_reports
  for all
  to anon, authenticated
  using (true)
  with check (true);

drop policy if exists anon_all_exam_results on public.exam_results;
create policy anon_all_exam_results
  on public.exam_results
  for all
  to anon, authenticated
  using (true)
  with check (true);

-- Conta do app. A senha fica no Auth do Supabase, não nesta tabela.
create table if not exists public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  email text not null,
  display_name text not null,
  sex text,
  birth_date date
);

alter table public.profiles enable row level security;

grant select, insert, update on public.profiles to authenticated;

drop policy if exists profiles_select_own on public.profiles;
create policy profiles_select_own
  on public.profiles
  for select
  to authenticated
  using (auth.uid() = id);

drop policy if exists profiles_insert_own on public.profiles;
create policy profiles_insert_own
  on public.profiles
  for insert
  to authenticated
  with check (auth.uid() = id);

drop policy if exists profiles_update_own on public.profiles;
create policy profiles_update_own
  on public.profiles
  for update
  to authenticated
  using (auth.uid() = id)
  with check (auth.uid() = id);

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, email, display_name, sex)
  values (
    new.id,
    coalesce(new.email, ''),
    coalesce(new.raw_user_meta_data->>'display_name', split_part(coalesce(new.email, ''), '@', 1)),
    nullif(new.raw_user_meta_data->>'sex', '')
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();
