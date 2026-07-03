-- ============================================================
-- ProspectAI — Multiusuário (multi-tenant por empresa)
-- Supabase: SQL Editor > cole tudo > Run
-- ============================================================

-- ---------- Tabelas ----------

-- Empresa / conta (tenant). Cada vendedor pertence a uma.
create table if not exists public.companies (
  id         uuid primary key default gen_random_uuid(),
  name       text not null,
  join_code  text not null unique,          -- código para vendedores entrarem
  owner_id   uuid references auth.users (id),
  created_at timestamptz not null default now()
);

-- Perfil do usuário (1:1 com auth.users).
-- role: 'admin' (dono, vê tudo) ou 'vendedor'.
create table if not exists public.profiles (
  id         uuid primary key references auth.users (id) on delete cascade,
  name       text,
  email      text,
  company_id uuid references public.companies (id) on delete set null,
  role       text not null default 'vendedor' check (role in ('admin', 'vendedor')),
  created_at timestamptz not null default now()
);

-- Leads — sempre presos a uma empresa. Compartilhados dentro dela.
create table if not exists public.leads (
  id            uuid primary key default gen_random_uuid(),
  company_id    uuid not null references public.companies (id) on delete cascade,
  external_id   text,                         -- id do Google Places (dedupe)
  name          text not null,
  address       text,
  phone         text,
  whatsapp      text,
  email         text,
  site          text,
  instagram     text,
  linkedin      text,
  decisor       text,
  decisor_cargo text,
  rating        numeric,
  total_ratings int,
  score         int not null default 0,
  status        text not null default 'novo',
  locked_by     uuid references auth.users (id),   -- vendedor que "pegou" o lead
  locked_at     timestamptz,
  created_by    uuid references auth.users (id),
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);

create index if not exists leads_company_idx on public.leads (company_id);
create index if not exists leads_external_idx on public.leads (company_id, external_id);
create index if not exists profiles_company_idx on public.profiles (company_id);

-- ---------- Helpers (SECURITY DEFINER = sem recursão de RLS) ----------

create or replace function public.my_company_id()
returns uuid
language sql stable security definer set search_path = public
as $$
  select company_id from public.profiles where id = auth.uid();
$$;

create or replace function public.is_admin()
returns boolean
language sql stable security definer set search_path = public
as $$
  select exists (
    select 1 from public.profiles
    where id = auth.uid() and role = 'admin'
  );
$$;

-- Cria a empresa e torna o usuário atual 'admin' dela. Retorna o join_code.
create or replace function public.create_company(p_name text)
returns text
language plpgsql security definer set search_path = public
as $$
declare
  v_code text;
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;

  -- gera um código curto único
  loop
    v_code := upper(substr(md5(random()::text), 1, 6));
    exit when not exists (select 1 from public.companies where join_code = v_code);
  end loop;

  insert into public.companies (name, join_code, owner_id)
  values (p_name, v_code, auth.uid());

  update public.profiles
  set company_id = (select id from public.companies where join_code = v_code),
      role = 'admin'
  where id = auth.uid();

  return v_code;
end;
$$;

-- Entra numa empresa existente pelo código, como 'vendedor'.
create or replace function public.join_company(p_code text)
returns uuid
language plpgsql security definer set search_path = public
as $$
declare
  v_company uuid;
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;

  select id into v_company from public.companies where join_code = upper(p_code);
  if v_company is null then raise exception 'código inválido'; end if;

  update public.profiles
  set company_id = v_company, role = 'vendedor'
  where id = auth.uid();

  return v_company;
end;
$$;

-- Cria o profile automaticamente quando um usuário é criado no auth.
create or replace function public.handle_new_user()
returns trigger
language plpgsql security definer set search_path = public
as $$
begin
  insert into public.profiles (id, name, email)
  values (new.id, coalesce(new.raw_user_meta_data ->> 'name', ''), new.email)
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- Mantém updated_at atualizado.
create or replace function public.touch_updated_at()
returns trigger language plpgsql as $$
begin new.updated_at = now(); return new; end;
$$;
drop trigger if exists leads_touch on public.leads;
create trigger leads_touch before update on public.leads
  for each row execute function public.touch_updated_at();

-- ---------- RLS ----------

alter table public.companies enable row level security;
alter table public.profiles  enable row level security;
alter table public.leads     enable row level security;

-- companies: membros veem a própria; admin edita.
drop policy if exists comp_select on public.companies;
create policy comp_select on public.companies
  for select using (id = public.my_company_id());
drop policy if exists comp_update on public.companies;
create policy comp_update on public.companies
  for update using (id = public.my_company_id() and public.is_admin());

-- profiles: vê o próprio e os colegas de empresa; edita o próprio; admin edita papéis.
drop policy if exists prof_select on public.profiles;
create policy prof_select on public.profiles
  for select using (id = auth.uid() or company_id = public.my_company_id());
drop policy if exists prof_update_own on public.profiles;
create policy prof_update_own on public.profiles
  for update using (id = auth.uid());
drop policy if exists prof_update_admin on public.profiles;
create policy prof_update_admin on public.profiles
  for update using (company_id = public.my_company_id() and public.is_admin());

-- leads: todos da empresa veem/inserem/atualizam; lead travado só o dono da trava
-- (ou admin) mexe; excluir só admin.
drop policy if exists leads_select on public.leads;
create policy leads_select on public.leads
  for select using (company_id = public.my_company_id());
drop policy if exists leads_insert on public.leads;
create policy leads_insert on public.leads
  for insert with check (company_id = public.my_company_id());
drop policy if exists leads_update on public.leads;
create policy leads_update on public.leads
  for update using (
    company_id = public.my_company_id()
    and (locked_by is null or locked_by = auth.uid() or public.is_admin())
  );
drop policy if exists leads_delete on public.leads;
create policy leads_delete on public.leads
  for delete using (company_id = public.my_company_id() and public.is_admin());

-- ---------- Realtime ----------
-- Habilita eventos em tempo real na tabela leads.
alter publication supabase_realtime add table public.leads;
