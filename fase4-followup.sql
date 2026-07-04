-- ============================================================
-- ProspectAI — Fase 4: Cadência de follow-up por WhatsApp
-- Modelos de mensagem + mensagens agendadas (semi-automático agora,
-- 100% automático depois com Z-API via auto-sender-zapi.sql)
-- Supabase: SQL Editor > cole tudo > Run  (idempotente)
-- ============================================================

-- 1) Biblioteca de modelos de mensagem (por empresa). Ex: {NOME}, {EMPRESA}
alter table public.companies
  add column if not exists msg_templates jsonb not null default '[]'::jsonb;
-- Formato: [{ "name": "1º follow-up", "body": "Oi {NOME}, tudo bem? ..." }, ...]

-- 2) Mensagens agendadas (a cadência de follow-up)
create table if not exists public.scheduled_messages (
  id           uuid primary key default gen_random_uuid(),
  company_id   uuid not null references public.companies(id) on delete cascade,
  lead_id      uuid references public.leads(id) on delete cascade,
  wa_phone     text not null,               -- só dígitos
  contact_name text,
  body         text not null,
  send_at      timestamptz not null,
  auto         boolean not null default false, -- true = envia sozinho via Z-API (quando ligado)
  status       text not null default 'pending' check (status in ('pending','sent','failed','canceled')),
  created_by   uuid references auth.users(id),
  created_at   timestamptz not null default now(),
  sent_at      timestamptz
);
create index if not exists sched_due_idx on public.scheduled_messages (company_id, status, send_at);
create index if not exists sched_lead_idx on public.scheduled_messages (lead_id);

-- ---------- RLS ----------
alter table public.scheduled_messages enable row level security;

drop policy if exists sched_select on public.scheduled_messages;
create policy sched_select on public.scheduled_messages
  for select using (company_id = public.my_company_id());
drop policy if exists sched_insert on public.scheduled_messages;
create policy sched_insert on public.scheduled_messages
  for insert with check (company_id = public.my_company_id());
drop policy if exists sched_update on public.scheduled_messages;
create policy sched_update on public.scheduled_messages
  for update using (company_id = public.my_company_id());
drop policy if exists sched_delete on public.scheduled_messages;
create policy sched_delete on public.scheduled_messages
  for delete using (company_id = public.my_company_id());

-- ---------- Realtime ----------
alter publication supabase_realtime add table public.scheduled_messages;
