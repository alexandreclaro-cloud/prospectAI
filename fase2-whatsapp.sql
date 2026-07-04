-- ============================================================
-- ProspectAI — Fase 2: Inbox de WhatsApp (Z-API), sem servidor separado
-- Recebe mensagens via webhook → RPC grava no banco e cria/vincula lead
-- Supabase: SQL Editor > cole tudo > Run  (idempotente)
-- ============================================================

-- 1) Configuração da instância Z-API por empresa
create table if not exists public.wa_settings (
  company_id   uuid primary key references public.companies(id) on delete cascade,
  instance     text,          -- Z-API instanceId (usado pra achar a empresa no webhook)
  token        text,          -- Z-API token
  client_token text,          -- Z-API Client-Token (Security Token)
  wa_number    text,          -- número conectado (só exibição)
  updated_at   timestamptz not null default now()
);
create index if not exists wa_settings_instance_idx on public.wa_settings (instance);

-- 2) Mensagens de WhatsApp
create table if not exists public.wa_messages (
  id             uuid primary key default gen_random_uuid(),
  company_id     uuid not null references public.companies(id) on delete cascade,
  lead_id        uuid references public.leads(id) on delete set null,
  wa_phone       text not null,                 -- telefone do contato (só dígitos)
  contact_name   text,
  direction      text not null check (direction in ('in','out')),
  body           text,
  wa_message_id  text,
  sent_by        uuid references auth.users(id),
  created_at     timestamptz not null default now()
);
create index if not exists wa_messages_conv_idx on public.wa_messages (company_id, wa_phone, created_at);
create index if not exists wa_messages_lead_idx on public.wa_messages (lead_id);

-- ---------- RLS ----------
alter table public.wa_settings enable row level security;
alter table public.wa_messages enable row level security;

-- wa_settings: membros da empresa leem; admin edita.
drop policy if exists wa_settings_select on public.wa_settings;
create policy wa_settings_select on public.wa_settings
  for select using (company_id = public.my_company_id());
drop policy if exists wa_settings_upsert on public.wa_settings;
create policy wa_settings_upsert on public.wa_settings
  for all using (company_id = public.my_company_id() and public.is_admin())
          with check (company_id = public.my_company_id() and public.is_admin());

-- wa_messages: membros da empresa veem/inserem (outbound).
drop policy if exists wa_messages_select on public.wa_messages;
create policy wa_messages_select on public.wa_messages
  for select using (company_id = public.my_company_id());
drop policy if exists wa_messages_insert on public.wa_messages;
create policy wa_messages_insert on public.wa_messages
  for insert with check (company_id = public.my_company_id());

-- ---------- Receptor do webhook (Z-API → PostgREST RPC) ----------
-- Z-API faz POST em: https://<ref>.supabase.co/rest/v1/rpc/wa_inbound?apikey=<ANON>
create or replace function public.wa_inbound(payload jsonb)
returns void language plpgsql security definer set search_path = public as $$
declare
  v_instance text; v_company uuid; v_phone text; v_digits text;
  v_name text; v_body text; v_msgid text; v_fromme boolean; v_dir text;
  v_lead uuid; v_seller uuid;
begin
  v_instance := payload->>'instanceId';
  if v_instance is null then return; end if;
  select company_id into v_company from public.wa_settings where instance = v_instance;
  if v_company is null then return; end if;

  v_fromme := coalesce((payload->>'fromMe')::boolean, false);
  v_phone  := coalesce(payload->>'phone', payload->>'from');
  v_digits := regexp_replace(coalesce(v_phone,''), '\D', '', 'g');
  v_name   := coalesce(payload->>'senderName', payload->>'chatName', payload->>'notifyName', v_phone);
  v_body   := coalesce(payload#>>'{text,message}', payload->>'body', payload->>'message',
                       payload#>>'{message,text}');
  v_msgid  := coalesce(payload->>'messageId', payload->>'id');
  if v_digits = '' or v_body is null then return; end if;
  v_dir := case when v_fromme then 'out' else 'in' end;

  -- vincula (ou cria) um lead por telefone; novos entram como fonte whatsapp e são distribuídos
  select id into v_lead
  from public.leads
  where company_id = v_company
    and regexp_replace(coalesce(phone,''),'\D','','g') like '%'||right(v_digits,8)
  order by created_at desc limit 1;

  if v_lead is null and not v_fromme then
    select public.next_seller(v_company) into v_seller;
    insert into public.leads (company_id, name, phone, source, status, assigned_to, assigned_at)
    values (v_company, v_name, v_phone, 'whatsapp', 'novo', v_seller, now())
    returning id into v_lead;
  end if;

  insert into public.wa_messages (company_id, lead_id, wa_phone, contact_name, direction, body, wa_message_id)
  values (v_company, v_lead, v_digits, v_name, v_dir, v_body, v_msgid);
end;
$$;

grant execute on function public.wa_inbound(jsonb) to anon;

-- ---------- Realtime ----------
alter publication supabase_realtime add table public.wa_messages;
