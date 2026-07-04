-- ============================================================
-- ProspectAI — Cadência configurável pelo admin
-- A "régua" de lembretes que o vendedor segue pra chamar o cliente.
-- Supabase: SQL Editor > cole tudo > Run  (idempotente)
-- ============================================================

alter table public.companies
  add column if not exists cadence jsonb not null default '[]'::jsonb;
-- Formato: [{ "dias": 0, "texto": "Ligar agora — 1º contato" },
--           { "dias": 1, "texto": "Ligar de novo se não respondeu" },
--           { "dias": 3, "texto": "Mandar WhatsApp com proposta" }, ...]
