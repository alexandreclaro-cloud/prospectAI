-- ============================================================
-- ProspectAI — Atualização: base por vendedor + observações + agendamento
-- Supabase: SQL Editor > cole tudo > Run
-- (Roda por cima do schema já existente. Pode rodar mais de uma vez sem problema.)
-- ============================================================

-- 1) Base separada por vendedor: cada um vê só os leads dele; o admin vê tudo.
drop policy if exists leads_select on public.leads;
create policy leads_select on public.leads
  for select using (
    company_id = public.my_company_id()
    and (public.is_admin() or created_by = auth.uid())
  );

drop policy if exists leads_update on public.leads;
create policy leads_update on public.leads
  for update using (
    company_id = public.my_company_id()
    and (public.is_admin() or created_by = auth.uid())
  );

-- 2) Observação e agendamento por lead.
alter table public.leads add column if not exists notes        text;
alter table public.leads add column if not exists follow_up_at timestamptz;
