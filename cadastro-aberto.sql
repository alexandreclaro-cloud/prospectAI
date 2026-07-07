-- ============================================================
-- ProspectAI — Auto-cadastro (vendedor entra só com email+senha)
-- Novo cadastro cai automático na empresa aberta. Sem código, sem link.
-- Supabase: SQL Editor > cole tudo > Run  (idempotente)
-- ============================================================

-- Empresa "aberta pra cadastro". Por padrão só a mais antiga (a sua, Matriz).
alter table public.companies add column if not exists open_signup boolean not null default false;
update public.companies set open_signup = true
  where id = (select id from public.companies order by created_at asc limit 1)
    and not exists (select 1 from public.companies where open_signup = true);

-- Coloca o usuário recém-criado (sem empresa) na empresa aberta, como vendedor.
create or replace function public.auto_join()
returns uuid language plpgsql security definer set search_path = public as $$
declare v_company uuid;
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  select company_id into v_company from public.profiles where id = auth.uid();
  if v_company is not null then return v_company; end if;   -- já tem empresa
  select id into v_company from public.companies where open_signup = true order by created_at asc limit 1;
  if v_company is null then return null; end if;            -- cadastro fechado
  update public.profiles set company_id = v_company, role = 'vendedor' where id = auth.uid();
  return v_company;
end;
$$;
grant execute on function public.auto_join() to authenticated;
