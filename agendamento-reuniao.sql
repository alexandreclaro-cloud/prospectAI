-- ============================================================
-- ProspectAI — Agendou reunião (Google Agenda -> CRM)
-- Recebe do Google Apps Script quando alguém marca reunião pela
-- página de agendamento. Marca o lead existente (casando por
-- e-mail) OU cria um lead novo (source='agendamento').
-- Supabase: SQL Editor > cole tudo > Run  (idempotente)
-- ============================================================

alter table public.leads
  add column if not exists meeting_at timestamptz;

-- RPC pública (anon) chamada pelo Apps Script do Google
create or replace function public.record_meeting(
  p_code  text,
  p_name  text,
  p_email text default null,
  p_phone text default null,
  p_when  timestamptz default null
) returns uuid language plpgsql security definer set search_path = public as $$
declare v_company uuid; v_id uuid;
begin
  select id into v_company from public.companies
    where join_code = upper(p_code) or capture_code = upper(p_code);
  if v_company is null then raise exception 'empresa inválida'; end if;

  -- 1) tenta achar um lead existente pelo e-mail (quem agendou já veio do funil)
  if p_email is not null and trim(p_email) <> '' then
    select id into v_id from public.leads
      where company_id = v_company and lower(email) = lower(trim(p_email))
      order by created_at desc limit 1;
  end if;
  -- 2) se não achou por e-mail, tenta por telefone
  if v_id is null and p_phone is not null and trim(p_phone) <> '' then
    select id into v_id from public.leads
      where company_id = v_company and phone = trim(p_phone)
      order by created_at desc limit 1;
  end if;

  -- achou lead: carimba a reunião nele
  if v_id is not null then
    update public.leads
       set meeting_at = coalesce(p_when, now())
     where id = v_id;
    return v_id;
  end if;

  -- não achou: cria um lead novo de agendamento
  insert into public.leads
    (company_id, name, email, phone, source, status, meeting_at)
  values
    (v_company, coalesce(nullif(trim(p_name),''),'Reunião agendada'),
     p_email, p_phone, 'agendamento', 'novo', coalesce(p_when, now()))
  returning id into v_id;
  return v_id;
end;
$$;

grant execute on function public.record_meeting(text,text,text,text,timestamptz) to anon;
