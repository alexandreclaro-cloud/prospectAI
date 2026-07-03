# ProspectAI — Contexto do Projeto

## O que é
CRM de prospecção B2B com agente de IA. Arquivo HTML standalone que roda direto no browser.

## Stack atual
- **Frontend:** HTML + CSS + JS puro (arquivo único `prospectai.html`)
- **Google Places API v1** — busca empresas por segmento e cidade
- **Anthropic Claude Haiku** — interpreta comandos em linguagem natural e extrai decisores
- **localStorage** — salva leads e configurações no browser

## Funcionalidades prontas
- Agente IA com dois campos: segmento + cidade/estado
- Busca real no Google Places API v1 (sem CORS)
- Varredura automática de sites (e-mail, WhatsApp, Instagram, LinkedIn)
- Pipeline Kanban com colunas editáveis (renomear, adicionar, remover)
- Drag and drop entre colunas
- WhatsApp, e-mail e Instagram clicáveis
- Exportar CSV
- Score de qualidade do lead (0-100)

## APIs configuradas pelo usuário
- `GOOGLE_PLACES_KEY` — salvo no localStorage do browser
- `ANTHROPIC_KEY` — salvo no localStorage do browser

## Próxima fase — Multiusuário
Objetivo: múltiplos vendedores (2-5) acessam o mesmo CRM online.

### Requisitos
1. **Login** — cada vendedor tem e-mail e senha
2. **Lead travado** — quando um vendedor pega um lead, os outros veem "Travado por João"
3. **Tempo real** — atualização instantânea para todos
4. **Admin** — dono pode ver todos os leads e todos os vendedores

### Stack planejado para multiusuário
- **Supabase** — banco de dados PostgreSQL + autenticação + realtime (grátis)
- **Vercel** — hospedagem do frontend (grátis)
- **React ou HTML puro** — manter simples

### Tabelas necessárias no Supabase
```sql
-- Leads compartilhados
CREATE TABLE leads (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text,
  address text,
  phone text,
  whatsapp text,
  email text,
  site text,
  instagram text,
  linkedin text,
  decisor text,
  decisor_cargo text,
  score int DEFAULT 0,
  status text DEFAULT 'novo',
  locked_by uuid REFERENCES auth.users(id),
  locked_at timestamptz,
  created_by uuid REFERENCES auth.users(id),
  created_at timestamptz DEFAULT now()
);

-- Perfis dos vendedores
CREATE TABLE profiles (
  id uuid PRIMARY KEY REFERENCES auth.users(id),
  name text,
  role text DEFAULT 'vendedor', -- 'admin' ou 'vendedor'
  created_at timestamptz DEFAULT now()
);
```

## Instruções para o Claude Code
1. Leia o arquivo `prospectai.html` para entender a estrutura atual
2. A próxima tarefa é migrar para Supabase + Vercel com multiusuário
3. Mantenha o visual e UX igual — só adicionar login e sincronização
4. Use Supabase JS SDK v2
5. Comece criando o `index.html` com tela de login e depois migre o CRM
