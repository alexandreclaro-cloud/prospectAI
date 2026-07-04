# ProspectAI — Nova Fase: CRM de ATENDIMENTO (leads de campanha → vendedores)

> Documento de contexto pra continuar o trabalho NESTA pasta (`prospectai-project`).
> Abra o Claude Code aqui e mande ele **ler este arquivo** antes de começar.

## De onde partimos (estado atual do ProspectAI)
- App **HTML único** (`index.html`, ~86KB) que fala **direto com o Supabase** (SDK JS v2). Config em `config.js` (URL + anon key públicas, protegidas por RLS). Deploy na **Vercel**.
- Já pronto (fluxo de PROSPECÇÃO / outbound):
  - Login/signup, **empresas** multi-tenant (`companies` com `join_code`), papéis **admin/vendedor** (`profiles.role`).
  - **Leads por empresa**, com **lead travado** (`locked_by`/`locked_at` + funções `pegar`/`liberar`), **realtime** e **Kanban** editável.
  - Prospecção via **Google Places API** + enriquecimento com **IA (Claude Haiku)**.
- Schema atual (ver `schema.txt`): tabelas `companies`, `profiles`, `leads`; funções `my_company_id()`, `is_admin()`, `create_company()`, `join_company()`, `handle_new_user()`; **RLS** de isolamento por empresa; `realtime` na tabela `leads`.

## Objetivo desta nova fase
Um **CRM de ATENDIMENTO (inbound)**: leads **qualificados vindos de CAMPANHAS** entram no sistema e são **distribuídos aos vendedores** pra atender rápido. É um caso de uso DIFERENTE da prospecção (aquele é outbound; este é inbound), mas reaproveita a mesma base (empresas, papéis, trava, realtime).
- **Fontes de lead desejadas (todas):** Anúncios **Meta/Google (Lead Ads/formulário)**, **landing/formulário próprio**, **planilha (CSV)** e **WhatsApp direto**.

## O que um bom CRM de atendimento SaaS precisa ter (checklist)
1. **Velocidade / SLA de 1ª resposta** — lead de campanha esfria em minutos. Distribuir na hora + alertar lead parado. (fator nº1)
2. **Distribuição** — automática (round-robin ou por regra), pool (vendedor pega) ou admin na mão.
3. **Dono único + trava** — nunca dois vendedores no mesmo lead. ✅ já existe.
4. **Origem/campanha rastreada** — de qual anúncio/UTM veio (pra medir ROI).
5. **Timeline de atividades** — cada contato/nota/ligação/mensagem registrado.
6. **WhatsApp dentro do CRM** — coração do atendimento no Brasil.
7. **Follow-up / tarefas / lembretes** — cadência de retomada, próxima ação.
8. **Funil visual (Kanban)** — estágios editáveis. ✅ já existe.
9. **Painéis** — conversão, tempo de resposta, receita **por campanha** e **por vendedor**.
10. **Notificação de lead novo** (som/realtime) + **mobile-friendly**.
11. **Papéis/permissões** admin/vendedor. ✅ já existe.
12. **Automação** — auto-atribuir, auto-mensagem de boas-vindas, mudança de status.
13. **Lead scoring / qualificação**. ✅ parcial (campo score).
14. **LGPD/auditoria** — dados do lead são sensíveis.

## Marcas de referência (foco: Brasil, WhatsApp, inbound)
- **Kommo (ex-amoCRM)** — CRM WhatsApp-first com funil + distribuição. A referência mais próxima do produto.
- **RD Station CRM** — BR, forte em distribuição de lead + integração com anúncios.
- **Pipedrive** — referência de UX de funil simples pro vendedor.
- **HubSpot** — referência de automação, captura e lead scoring.
- (Suporte/ticket: Zendesk/Freshdesk — menos aderente ao caso.)

## Plano em fases (proposto)
**Fase 1 — Fundação inbound**
- Estender `leads` com: `source` (meta/google/landing/csv/whatsapp/manual), `campaign` (nome), `assigned_to` (vendedor responsável), `source_payload` (jsonb com o que veio do form).
- Aba **"Atendimento"** separada da prospecção: vendedor vê os leads DELE; admin vê todos + distribui.
- **1 fonte primeiro** pra validar ponta a ponta.

**Fase 2 — Entradas automáticas (webhooks)**
- **Supabase Edge Function** (Deno) recebendo Meta/Google Lead Ads e WhatsApp → insere o lead com origem/campanha. Usa a `service_role key` **no env da função** (secreta — NUNCA no `config.js`).

**Fase 3 — Atendimento + métricas**
- Histórico/notas, status (novo → atendendo → ganho/perdido), follow-up, e painel de desempenho por campanha e por vendedor.

## Decisões em aberto (definir com o Alexandre antes da Fase 1)
1. **Distribuição:** automática (round-robin) vs pool (vendedor pega) vs admin na mão.
   - *Recomendação:* round-robin — lead de campanha precisa de atendimento rápido; não pode ficar solto.
2. **Por qual fonte começar:** formulário/landing próprio (mais simples, valida o fluxo todo) vs CSV vs Meta/Google (mais poderoso, mais complexo).
   - *Recomendação:* começar pelo **formulário/landing próprio** — valida distribuição + atendimento sem depender de app da Meta.

## Extensões de schema propostas (Fase 1) — rascunho
```sql
alter table public.leads
  add column if not exists source        text default 'manual',   -- meta|google|landing|csv|whatsapp|manual
  add column if not exists campaign       text,                    -- nome/id da campanha
  add column if not exists assigned_to    uuid references auth.users(id),  -- vendedor responsável (distinto da trava)
  add column if not exists assigned_at    timestamptz,
  add column if not exists source_payload jsonb;                   -- dados crus do formulário

create index if not exists leads_assigned_idx on public.leads (company_id, assigned_to);

-- Round-robin: função que pega o próximo vendedor da empresa e atribui o lead
-- (a definir na Fase 1). Alternativa simples: contador por empresa.
```

## Observações técnicas
- **Manter o app HTML único** e o visual atual — só adicionar a aba de atendimento e a lógica inbound.
- Webhooks (Meta/WhatsApp) → **Supabase Edge Functions** (mesmo ecossistema, sem servidor à parte).
- Landing/CSV → insert direto via Supabase (anon + RLS) ou via Edge Function.
- Este projeto é **SEPARADO do recomendaleads-bot** (aquele é Node/Firebase/Render). Não misturar.

---
*Gerado a partir da conversa de planejamento (2026-07). Referências do RecomendaLeads: naquele produto já existe follow-up, atendimento pós-fluxo com IA e anti-ban — pode inspirar features aqui, mas o código não é reaproveitável (stack diferente).*
