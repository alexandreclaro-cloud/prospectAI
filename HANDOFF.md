# HANDOFF.md — ProspectAI — Estado da última sessão

> Escrito em 2026-11-23 porque o Alexandre vai trocar de conta Claude e a
> conta nova não terá acesso ao histórico desta conversa. Ler junto com
> [`CLAUDE.md`](./CLAUDE.md).

## 🔴 BLOQUEIO ATUAL (resolver PRIMEIRO) — Supabase PAUSADO

**O CRM inteiro está offline agora.** Qualquer ação (login, busca, reset de
senha) falha com **"Failed to fetch"** / `ERR_BLOCKED_BY_CLIENT`.

**Causa confirmada ao vivo nesta sessão:** o projeto Supabase
(`buoaumgjjqtfavxfrwsz.supabase.co`) está **inacessível**, enquanto
`supabase.com` responde normal. Isso é o **plano grátis pausando o projeto
por inatividade** (criado em julho/2026, meses sem uso). Não é bug de
código, nem ad-blocker, nem a feature nova.

**FIX (só o Alexandre consegue — precisa do login do Supabase dele):**
1. Abrir `https://supabase.com/dashboard`
2. Login — provavelmente **"Continue with GitHub"** (conta
   `alexandreclaro-cloud`)
3. Abrir o projeto `buoaumgjjqtfavxfrwsz` → vai ter um aviso **"Paused"** e
   um botão **"Restore" / "Resume project"** → clicar → esperar ~2-5 min
4. Depois de religar, o CRM volta a funcionar normal.

**Pra não pausar de novo:** manter um "ping" automático (ex. cron que bate
na REST a cada poucos dias) ou subir pro plano pago (~US$25/mês). Decidir
isso DEPOIS de religar.

## O que foi feito nesta sessão

1. **Nova feature: "Esqueci minha senha"** (commit `0173d0c`, **no ar na
   Vercel**). A tela de login do `index.html` agora tem o link "Esqueci
   minha senha" → digita e-mail → recebe link por e-mail → cria senha nova
   (fluxo de recuperação do Supabase: `resetPasswordForEmail` +
   tratamento do evento `PASSWORD_RECOVERY` → `updateUser({password})`).
   Antes não existia nenhuma forma de reset. Validado com `node --check`
   (sem erro de sintaxe) e confirmado renderizando ao vivo no site.
2. **Motivo original da sessão:** o Alexandre **esqueceu o login/senha** do
   CRM. A senha **não tem como recuperar** (fica criptografada no Supabase).
   Por isso construímos o "Esqueci minha senha". O e-mail da conta dele é
   quase com certeza **alexandreclaro@pdnpro.com** (autor dos commits), ou
   `papodevendedor1@gmail.com` / `alexandreclarooficial@gmail.com`. O que
   **receber o e-mail de reset** é o correto.

## Próximos passos (em ordem)

1. **Religar o Supabase** (passo a passo acima). Sem isso nada funciona.
2. **Conferir Site URL do reset:** Supabase → Authentication → URL
   Configuration → **Site URL** deve ser
   `https://prospect-ai-rouge-one.vercel.app` (senão o link do e-mail de
   reset não volta certo). E-mails do Supabase podem cair no spam e têm
   limite de poucos por hora.
3. **Alexandre usa o "Esqueci minha senha"** no site pra recuperar o acesso
   (testar os e-mails prováveis até chegar o link).
4. Pendências antigas (do histórico, ainda válidas):
   - Rodar `lead-wa-click.sql` (fase "Foi pro WhatsApp") no SQL Editor.
   - Apagar lead(s) de teste do pool.
   - Plugar Z-API (criar instância, conectar número por QR, colar
     instanceId/token/Client-Token na aba WhatsApp + webhook).
   - Subdomínio `crm.recomendaleads.com.br` (quando migrar, atualizar o
     referrer da chave Google Places).

## O que está no ar

- Site: `https://prospect-ai-rouge-one.vercel.app` (Vercel, auto-deploy).
- Código no GitHub `alexandreclaro-cloud/prospectAI`, tudo em `main`,
  incluindo a feature de reset (`0173d0c`).
- **Porém o backend (Supabase) está pausado → app sem funcionar até o
  Restore.**

## Observação sobre este repo

- `config.js` tem só a anon key **pública** (seguro, no repo de propósito).
- A pasta `POSTAGENS /` tem imagens de marketing soltas (não rastreadas) —
  **não commitar** no repo; são material do Alexandre, não código.
