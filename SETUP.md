# ProspectAI — Multiusuário (Supabase + Vercel)

Migração do CRM para online com **login por vendedor**, **leads compartilhados por empresa**,
**lead travado** ("Travado por João"), **tempo real** e **admin**. Continua sendo HTML puro.

## Arquivos

- `index.html` — o app (novo, multiusuário). É o que vai pro ar.
- `config.js` — onde você cola a URL e a chave do Supabase.
- `supabase-schema.sql` — cria tabelas, segurança (RLS) e tempo real.
- `prospectai.html` — versão antiga single-user (localStorage). Fica de referência.

---

## 1. Criar o projeto no Supabase (grátis)

1. Entre em https://supabase.com → **New project**. Guarde a senha do banco.
2. No menu **SQL Editor** → **New query** → cole todo o `supabase-schema.sql` → **Run**.
   Isso cria as tabelas `companies`, `profiles`, `leads`, as regras de segurança e o tempo real.
3. Em **Project Settings → API**, copie:
   - **Project URL** (ex: `https://abcd.supabase.co`)
   - **anon public** key
4. Abra `config.js` e cole os dois valores.

> Autenticação por e-mail já vem ligada. Para testar mais rápido, em
> **Authentication → Providers → Email**, desligue "Confirm email" durante os testes.
> Em produção, deixe ligado.

---

## 2. Testar localmente

Como o `index.html` carrega `config.js`, abra por um servidor local (não pelo `file://`):

```bash
cd prospectai-project
python3 -m http.server 5173
# abra http://localhost:5173
```

Fluxo:
1. **Criar conta** (nome, e-mail, senha).
2. **Criar empresa** → você vira **admin** e recebe um **código da empresa**.
3. Na aba **Equipe**, copie o código e passe para os vendedores.
4. O vendedor **cria conta** → escolhe **"Entrar com código"** → vira vendedor da sua empresa.
5. Na aba **Configurações**, cada um cola as chaves do Google Places e da Anthropic (ficam no navegador).

**Lead travado:** na lista de Leads, clique no ícone de "mãozinha" para *pegar* o lead.
Os outros passam a ver "🔒 Seu Nome" e não conseguem mexer. O admin pode liberar qualquer um.
As mudanças aparecem **em tempo real** para todo mundo.

---

## 3. Publicar na Vercel (grátis)

1. Suba a pasta num repositório no GitHub.
2. Em https://vercel.com → **Add New → Project** → importe o repositório.
3. Framework preset: **Other** (é site estático, sem build). Deploy.
4. Copie a URL final (ex: `https://prospectai.vercel.app`).
5. Na **chave do Google Places** (Google Cloud → Credenciais → sua chave →
   Restrições de aplicativo → Referenciadores HTTP), adicione:
   - `https://SEU-APP.vercel.app/*`
   - `http://localhost:*` (para testes)
6. No Supabase → **Authentication → URL Configuration**, coloque a URL da Vercel em **Site URL**.

> ⚠️ O `config.js` só tem a **anon key** (pública, protegida por RLS) — pode ir para o GitHub sem risco.
> Nunca coloque a *service_role* key no front-end.

---

## Papéis

| Ação                              | Admin | Vendedor |
|-----------------------------------|:-----:|:--------:|
| Ver/adicionar leads da empresa    |  ✓    |    ✓     |
| Pegar (travar) um lead            |  ✓    |    ✓     |
| Mexer em lead travado por outro   |  ✓    |    ✗     |
| Excluir lead                      |  ✓    |    ✗     |
| Ver equipe / código / trocar papel|  ✓    |    ✗     |

Tudo é reforçado no banco por **RLS** — não depende só da tela.

## Próximos passos sugeridos

- Colunas do Kanban compartilhadas por empresa (hoje ficam por navegador).
- Convite por e-mail (em vez de código).
- Histórico de quem mexeu em cada lead.
