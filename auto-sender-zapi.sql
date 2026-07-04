-- ============================================================
-- ProspectAI — Envio AUTOMÁTICO de follow-up (rodar SÓ depois do Z-API ligado)
-- Usa pg_cron (agenda) + pg_net (HTTP do banco) pra disparar as mensagens
-- agendadas com auto=true, sozinho, 24h — sem servidor à parte.
-- Supabase: SQL Editor > cole tudo > Run
-- ============================================================

create extension if not exists pg_cron;
create extension if not exists pg_net;

-- Envia as mensagens automáticas vencidas via Z-API e marca como enviadas.
create or replace function public.wa_send_scheduled()
returns void language plpgsql security definer set search_path = public, extensions as $$
declare r record; s record;
begin
  for r in
    select * from public.scheduled_messages
    where auto = true and status = 'pending' and send_at <= now()
    order by send_at limit 30
  loop
    select * into s from public.wa_settings where company_id = r.company_id;
    if s.instance is null or s.token is null then
      continue; -- Z-API ainda não configurado pra essa empresa
    end if;

    perform net.http_post(
      url := 'https://api.z-api.io/instances/'||s.instance||'/token/'||s.token||'/send-text',
      headers := jsonb_build_object('Content-Type','application/json','Client-Token',coalesce(s.client_token,'')),
      body := jsonb_build_object('phone', r.wa_phone, 'message', r.body)
    );

    update public.scheduled_messages
      set status = 'sent', sent_at = now() where id = r.id;

    insert into public.wa_messages (company_id, lead_id, wa_phone, contact_name, direction, body, sent_by)
      values (r.company_id, r.lead_id, r.wa_phone, r.contact_name, 'out', r.body, r.created_by);
  end loop;
end;
$$;

-- Roda a cada minuto.
select cron.schedule('wa-followup-sender', '* * * * *', $$ select public.wa_send_scheduled(); $$);
