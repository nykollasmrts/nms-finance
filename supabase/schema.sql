-- NMS Controle Financeiro · banco de dados
-- Cole tudo isto no Supabase em: SQL Editor > New query > Run.
-- Pode rodar de novo sem problema (ele só cria o que ainda não existe).

-- 1) Perfis de usuário (nome, tipo PF/PJ e papel: user ou master)
create table if not exists public.profiles (
  id uuid primary key references auth.users on delete cascade,
  nome text default '',
  tipo text default 'pf' check (tipo in ('pf','pj')),
  role text default 'user' check (role in ('user','master')),
  created_at timestamptz default now()
);

-- 2) Todos os dados do app (lançamentos, agenda, fornecedores, clientes, configurações)
create table if not exists public.docs (
  path text primary key,
  parent text not null,
  owner uuid not null,
  data jsonb not null default '{}'::jsonb,
  updated_at timestamptz default now()
);
create index if not exists docs_parent_idx on public.docs (parent);
create index if not exists docs_owner_idx on public.docs (owner);

-- 3) O dono de cada registro vem do próprio caminho (ninguém consegue gravar no espaço de outra pessoa)
create or replace function public.nms_doc_owner() returns trigger
language plpgsql as $$
begin
  if new.path like 'data/users/%' then new.owner := split_part(new.path, '/', 3)::uuid;
  elsif new.path like 'membros/%' then new.owner := split_part(new.path, '/', 2)::uuid;
  else raise exception 'caminho inválido: %', new.path;
  end if;
  new.parent := regexp_replace(new.path, '/[^/]+$', '');
  return new;
end $$;
drop trigger if exists nms_docs_owner on public.docs;
create trigger nms_docs_owner before insert or update on public.docs
  for each row execute function public.nms_doc_owner();

-- 4) Quem é Master
create or replace function public.nms_is_master() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.profiles where id = auth.uid() and role = 'master')
$$;

-- 5) Segurança: cada um vê e mexe só no que é seu; o Master pode ver tudo (sem alterar)
alter table public.docs enable row level security;
alter table public.profiles enable row level security;

drop policy if exists "docs: ler" on public.docs;
drop policy if exists "docs: criar" on public.docs;
drop policy if exists "docs: alterar" on public.docs;
drop policy if exists "docs: excluir" on public.docs;
create policy "docs: ler" on public.docs for select using (owner = auth.uid() or public.nms_is_master());
create policy "docs: criar" on public.docs for insert with check (owner = auth.uid());
create policy "docs: alterar" on public.docs for update using (owner = auth.uid()) with check (owner = auth.uid());
create policy "docs: excluir" on public.docs for delete using (owner = auth.uid());

drop policy if exists "perfis: ler" on public.profiles;
create policy "perfis: ler" on public.profiles for select using (id = auth.uid() or public.nms_is_master());

-- 6) Ao criar conta, já cria o perfil com o nome e o tipo escolhidos na tela de cadastro
create or replace function public.nms_novo_usuario() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, nome, tipo)
  values (new.id, coalesce(new.raw_user_meta_data->>'nome', ''), coalesce(nullif(new.raw_user_meta_data->>'tipo', ''), 'pf'))
  on conflict (id) do nothing;
  return new;
end $$;
drop trigger if exists nms_on_auth_user_created on auth.users;
create trigger nms_on_auth_user_created after insert on auth.users
  for each row execute function public.nms_novo_usuario();

-- 7) Atualização em tempo real entre computadores e celulares
do $$ begin
  alter publication supabase_realtime add table public.docs;
exception when duplicate_object then null; end $$;

-- 8) DEPOIS de criar a sua conta no app, rode só a linha abaixo trocando o e-mail
--    para virar Master (ver todos os usuários e alternar para a conta da empresa):
-- update public.profiles set role = 'master' where id = (select id from auth.users where email = 'SEU-EMAIL-AQUI');
