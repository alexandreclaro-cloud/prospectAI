# CLAUDE.md — ProspectAI

> Instruções pra qualquer IA (Claude Code ou outra) que for trabalhar neste
> projeto. Escrito pra sobreviver a troca de conta/sessão sem perder contexto.
> **Leia também [`HANDOFF.md`](./HANDOFF.md)** — é o estado da última sessão
> (o que está no ar, o que está quebrado agora, próximos passos).
> Mais contexto histórico também em `CONTEXT.md` e `SETUP.md`.

## 1. O que é o projeto

**ProspectAI** é um **CRM de prospecção B2B + atendimento inbound** para
pequenas empresas (barbearias, estética, etc.). Dono: **Alexandre Claro**.
É um **projeto SEPARADO do RecomendaLeads** (outro repo/pasta) — não
compartilha código, só o dono.

Funções principais: busca empresas no **Google Places API** por
segmento+cidade, varre sites atrás de e-mail/WhatsApp/Instagram, score de
lead, **Pipeline/Kanban**, **pool de leads** (lead sem dono que qualquer
vendedor pode "Pegar"), **lead travado** em tempo real, alarme de
agendamento, inbox de WhatsApp via **Z-API** (sem servidor próprio) e
captação automática a partir dos funis de nicho do RecomendaLeads.

## 2. Quem usa

- **Alexandre** — dono/admin da plataforma (vê tudo, gerencia equipe).
- **Vendedores** — logam, buscam empresas, pegam leads do pool, atendem.
- Modelo **multi-tenant POR EMPRESA**: cada empresa isola seus leads;
  papéis **admin** (dono) vs **vendedor**.

## 3. Stack e estrutura

- **HTML puro, arquivo único** `index.html` (~160 KB, um `<script>` inline
  grande). **NÃO é Next.js / sem build / sem framework.** Manter simples e
  o mesmo visual — é regra do `CONTEXT.md`.
- **Supabase** (Postgres + Auth + Realtime), project ref
  `buoaumgjjqtfavxfrwsz` (região São Paulo). Tabelas: `companies`,
  `profiles`, `leads`, `wa_settings`, `wa_messages`, `scheduled_messages`,
  etc. RLS ativa (isolamento por empresa / por `assigned_to`).
- **Vercel** — hospedagem do front, deploy automático a cada push em `main`.
- `config.js` — só `url` + `anonKey` do Supabase (chave **pública** anon,
  feita pra rodar no browser, protegida por RLS — **não é segredo**).
- Arquivos `.sql` na raiz — migrações idempotentes rodadas no SQL Editor do
  Supabase (ex. `funil-pool.sql`, `fase1-atendimento.sql`,
  `lead-wa-click.sql`). Os `copiar-*.html` são helpers que copiam cada SQL
  pro clipboard do browser (o `pbcopy` do sandbox não chega no Mac dele).
- `diag-chaves.html` — página de diagnóstico (loga e mostra
  profile/empresa/api_keys) pra depurar chave compartilhada da equipe.
- `prospectai.html` — versão ANTIGA single-file (localStorage), legado.

## 4. Como rodar, testar e fazer deploy

- **Rodar local**: é arquivo estático. Servir a pasta com
  `python3 -m http.server 8766` e abrir `http://localhost:8766/index.html`.
  (Precisa de internet pro Supabase responder.)
- **Testar**: sem suíte automatizada. Validação =
  - `node --check` no `<script>` inline extraído do `index.html` depois de
    qualquer edição de JS (pega erro de sintaxe que quebraria o app todo).
  - Preview no navegador + console (erros) + testar o fluxo na mão.
- **Deploy**: `git push origin main` → **Vercel** faz o deploy sozinho (~1
  min). Não há staging; `main` é produção. Confirmar com o Alexandre antes
  de dar push (ele quer ver/aprovar).

## 5. Onde ficam configuração e segredos (nomes só — nunca o valor)

- `config.js` (no repo) — `url` + `anonKey` do Supabase. **Público/seguro.**
- **Chave do Google Places** — NÃO fica no repo. Fica no Supabase, na
  coluna `companies.api_keys` (campo `places`), compartilhada com a equipe
  (admin salva em "Configurações → Salvar chaves"). Está **restrita ao
  referrer** `https://prospect-ai-rouge-one.vercel.app/*` — se mudar de
  domínio, liberar o novo no Google Cloud senão a busca para.
- **Service role key / segredos do Supabase** — ficam no painel do
  Supabase (dashboard), nunca no front.
- **Credenciais Z-API por empresa** (instanceId/token/Client-Token) —
  salvas na tabela `wa_settings` no Supabase, por empresa.
- Não há `.env` neste projeto (o front só usa a anon key pública).

## 6. Decisões importantes e porquês

- **HTML puro, sem build** — decisão firmada no `CONTEXT.md`. Um scaffold
  Next.js foi criado por engano uma vez e **descartado**. Não reintroduzir.
- **Multi-tenant por empresa** (não workspace único) — cada empresa só vê
  seus leads.
- **Pool de leads** — leads de funil/captação entram sem dono; vendedor
  "Pega" (vira dono + trava pros outros). Admin vê tudo.
- **Copy sempre "recomendar", nunca "indicar"** (igual RecomendaLeads).
- **Supabase plano grátis PAUSA o projeto** após inatividade — ver
  HANDOFF.md (isso já derrubou o CRM inteiro uma vez).

## 7. Como o Alexandre gosta de trabalhar

- **Responder sempre em português.**
- Manda prints de tela pra mostrar bug — analisar a imagem antes do fix.
- **1 funcionalidade por vez.**
- **Nunca `git push` sem confirmação explícita dele.**
- Não é programador de formação — explicar de forma simples e direta, e
  quando algo depende de login/painel dele (Supabase, Google, Meta), dar o
  passo a passo e pedir o print, em vez de assumir.
- Backup em pen drive: existe automação própria em
  `/Volumes/Lexar/BACKUP-ALEXANDRE/backup-claude/atualizar-pendrive.sh` —
  usar ela, e **conferir o log** depois (o script não usa `set -e`, loga
  "ok" mesmo se o rsync falhar no meio).

## 8. Links

- Repo: `github.com/alexandreclaro-cloud/prospectAI` (branch `main`)
- Site: `https://prospect-ai-rouge-one.vercel.app`
- Supabase dashboard: `https://supabase.com/dashboard` (projeto
  `buoaumgjjqtfavxfrwsz`; login provável via GitHub `alexandreclaro-cloud`)
