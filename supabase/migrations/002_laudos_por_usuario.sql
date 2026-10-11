-- Cada laudo passa a pertencer à conta que o importou.
-- Rodar uma vez no SQL Editor do projeto xdzognwurazkbmckzldf.
-- O app não precisa mudar: user_id é preenchido pelo banco com auth.uid().

alter table public.exam_reports
  add column if not exists user_id uuid references auth.users (id) on delete cascade;
alter table public.exam_reports
  alter column user_id set default auth.uid();

alter table public.exam_results
  add column if not exists user_id uuid references auth.users (id) on delete cascade;
alter table public.exam_results
  alter column user_id set default auth.uid();

-- Laudos antigos sem dono: se só existe uma conta, eles passam a ser dela.
-- Com mais de uma conta ficam sem dono e somem do app (apague ou atribua à mão).
do $$
begin
  if (select count(*) from auth.users) = 1 then
    update public.exam_reports
      set user_id = (select id from auth.users limit 1)
      where user_id is null;
    update public.exam_results
      set user_id = (select id from auth.users limit 1)
      where user_id is null;
  end if;
end $$;

update public.exam_results r
  set user_id = p.user_id
  from public.exam_reports p
  where r.report_id = p.id and r.user_id is null and p.user_id is not null;

create index if not exists exam_reports_user_idx on public.exam_reports (user_id);
create index if not exists exam_results_user_idx on public.exam_results (user_id);

revoke all on public.exam_reports from anon;
revoke all on public.exam_results from anon;

drop policy if exists anon_all_exam_reports on public.exam_reports;
drop policy if exists anon_all_exam_results on public.exam_results;

drop policy if exists own_exam_reports on public.exam_reports;
create policy own_exam_reports
  on public.exam_reports
  for all
  to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

drop policy if exists own_exam_results on public.exam_results;
create policy own_exam_results
  on public.exam_results
  for all
  to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());
