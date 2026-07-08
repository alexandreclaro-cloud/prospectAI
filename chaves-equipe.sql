-- ============================================================
-- ProspectAI — Chaves de API compartilhadas com a equipe
-- Admin salva 1x e todos os vendedores herdam (não precisam configurar).
-- Supabase: SQL Editor > cole tudo > Run  (idempotente)
-- ============================================================

alter table public.companies
  add column if not exists api_keys jsonb not null default '{}'::jsonb;
-- Formato: { "places": "...", "anthropic": "...", "search_key": "...", "search_cx": "..." }
-- (a chave do Google Places é protegida por restrição de domínio, então é segura de compartilhar)
