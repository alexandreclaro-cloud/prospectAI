-- ============================================================
-- ProspectAI — Pool + Presença (quem está online assume o lead)
-- + código público de captação (para os funis)
-- Supabase: SQL Editor > cole tudo > Run  (idempotente)
-- ============================================================

-- 1) Presença dos vendedores
alter table public.profiles add column if not exists available  boolean not null default true;
alter table public.profiles add column if not exists last_seen  timestamptz;

-- 2) Código PÚBLICO de captação (para os funis). Diferente do código de convite
--    dos vendedores (join_code) — expor este não deixa ninguém entrar como vendedor.
alter table public.companies add column if not exists capture_code text;
update public.companies set capture_code = upper(substr(md5(random()::text),1,8)) where capture_code is null;
create unique index if not exists companies_capture_code_idx on public.companies (capture_code);

-- 3) POOL: o vendedor vê os leads DELE + os SEM DONO (disponíveis pra pegar);
--    o admin vê tudo. Quem pega vira dono.
drop policy if exists leads_select on public.leads;
create policy leads_select on public.leads for select using (
  company_id = public.my_company_id()
  and (public.is_admin() or created_by = auth.uid() or assigned_to = auth.uid() or assigned_to is null)
);
drop policy if exists leads_update on public.leads;
create policy leads_update on public.leads for update using (
  company_id = public.my_company_id()
  and (public.is_admin() or created_by = auth.uid() or assigned_to = auth.uid() or assigned_to is null)
);

-- 4) capture_lead: resolve a empresa por join_code OU capture_code, e deixa o lead
--    NO POOL (sem dono). Quem estiver online pega.
create or replace function public.capture_lead(
  p_code     text,
  p_name     text,
  p_phone    text default null,
  p_email    text default null,
  p_campaign text default null,
  p_source   text default 'landing',
  p_payload  jsonb default null
) returns uuid language plpgsql security definer set search_path = public as $$
declare v_company uuid; v_id uuid;
begin
  select id into v_company from public.companies
    where join_code = upper(p_code) or capture_code = upper(p_code);
  if v_company is null then raise exception 'empresa inválida'; end if;
  if coalesce(trim(p_name),'') = '' then raise exception 'nome obrigatório'; end if;

  insert into public.leads
    (company_id, name, phone, email, campaign, source, source_payload, status)
  values
    (v_company, trim(p_name), p_phone, p_email, p_campaign,
     coalesce(nullif(trim(p_source),''),'landing'), p_payload, 'novo')
  returning id into v_id;

  return v_id;
end;
$$;
grant execute on function public.capture_lead(text,text,text,text,text,text,jsonb) to anon;
