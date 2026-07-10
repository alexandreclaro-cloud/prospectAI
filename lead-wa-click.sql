-- ============================================================
-- ProspectAI — Fase do lead: "Foi pro WhatsApp"
-- Marca quando o lead (que veio de um funil) clica pra ir pro
-- WhatsApp depois de preencher o formulário. Assim, no CRM, dá
-- pra saber se ele só preencheu (😐) ou preencheu E foi pro
-- contato (🔥).
-- Supabase: SQL Editor > cole tudo > Run  (idempotente)
-- ============================================================

alter table public.leads
  add column if not exists wa_clicked_at timestamptz;

-- Chamada pública (anon) da página do funil quando o lead clica
-- no botão de WhatsApp. Só carimba a hora do 1º clique (não sobrescreve).
create or replace function public.mark_wa_click(p_lead_id uuid)
returns void language plpgsql security definer set search_path = public as $$
begin
  update public.leads
     set wa_clicked_at = coalesce(wa_clicked_at, now())
   where id = p_lead_id;
end;
$$;

grant execute on function public.mark_wa_click(uuid) to anon;
