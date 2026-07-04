-- ============================================================
-- ProspectAI — Fase 1: CRM de Atendimento (inbound)
-- Origem/campanha + vendedor responsável + SLA + distribuição round-robin
-- + captura pública de lead (formulário/landing)
-- Supabase: SQL Editor > cole tudo > Run  (idempotente, pode rodar de novo)
-- ============================================================

-- 1) Novos campos no lead
alter table public.leads
  add column if not exists source            text default 'manual',   -- landing|meta|google|csv|whatsapp|manual
  add column if not exists campaign          text,                    -- nome/id da campanha
  add column if not exists assigned_to       uuid references auth.users(id),
  add column if not exists assigned_at       timestamptz,
  add column if not exists source_payload    jsonb,
  add column if not exists first_response_at timestamptz,             -- SLA: quando o vendedor deu o 1º retorno
  add column if not exists deal_setup        numeric,                 -- valor de entrada (setup), venda única
  add column if not exists deal_mrr          numeric;                 -- mensalidade (receita recorrente)

create index if not exists leads_assigned_idx on public.leads (company_id, assigned_to);

-- 2) Visibilidade: vendedor vê os que criou OU os atribuídos a ele; admin vê tudo.
drop policy if exists leads_select on public.leads;
create policy leads_select on public.leads for select using (
  company_id = public.my_company_id()
  and (public.is_admin() or created_by = auth.uid() or assigned_to = auth.uid())
);
drop policy if exists leads_update on public.leads;
create policy leads_update on public.leads for update using (
  company_id = public.my_company_id()
  and (public.is_admin() or created_by = auth.uid() or assigned_to = auth.uid())
);

-- 3) Round-robin por menor carga: próximo vendedor com menos leads em aberto.
create or replace function public.next_seller(p_company uuid)
returns uuid language sql stable security definer set search_path = public as $$
  select p.id
  from public.profiles p
  left join public.leads l
    on l.company_id = p_company
   and l.assigned_to = p.id
   and l.status not in ('ganho','perdido')
  where p.company_id = p_company
  group by p.id
  order by count(l.id) asc, random()
  limit 1;
$$;

-- 4) Captura pública de lead (formulário/landing/anúncio).
--    Recebe o CÓDIGO da empresa (join_code), insere e já distribui via round-robin.
create or replace function public.capture_lead(
  p_code     text,
  p_name     text,
  p_phone    text default null,
  p_email    text default null,
  p_campaign text default null,
  p_source   text default 'landing',
  p_payload  jsonb default null
) returns uuid language plpgsql security definer set search_path = public as $$
declare v_company uuid; v_seller uuid; v_id uuid;
begin
  select id into v_company from public.companies where join_code = upper(p_code);
  if v_company is null then raise exception 'empresa inválida'; end if;
  if coalesce(trim(p_name),'') = '' then raise exception 'nome obrigatório'; end if;

  select public.next_seller(v_company) into v_seller;

  insert into public.leads
    (company_id, name, phone, email, campaign, source, source_payload, status, assigned_to, assigned_at)
  values
    (v_company, trim(p_name), p_phone, p_email, p_campaign,
     coalesce(nullif(trim(p_source),''),'landing'), p_payload, 'novo', v_seller, now())
  returning id into v_id;

  return v_id;
end;
$$;

-- Permite que o formulário público (anon) chame a captura.
grant execute on function public.capture_lead(text,text,text,text,text,text,jsonb) to anon;
