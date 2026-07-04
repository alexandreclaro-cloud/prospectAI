-- ============================================================
-- ProspectAI — Script de vendas (roteiro compartilhado da empresa)
-- Guarda o roteiro na própria empresa. Admin edita, todos leem.
-- Supabase: SQL Editor > cole tudo > Run  (idempotente)
-- ============================================================

alter table public.companies
  add column if not exists sales_script jsonb not null default '[]'::jsonb;
-- Formato: [{ "title": "Abertura", "body": "texto do passo..." }, ...]
