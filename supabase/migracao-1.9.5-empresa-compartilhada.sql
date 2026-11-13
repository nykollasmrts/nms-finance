-- NMS 1.9.5 · papel "admin" com acesso à conta da empresa (NMS)
-- O que muda:
--   • Novo papel "admin": vê e edita a própria conta pessoal e a conta NMS (empresa).
--     Não vê nem altera a conta pessoal de ninguém e não tem Painel Master.
--   • O Master continua como era (vê tudo).
-- Pode rodar de novo sem problema.

-- 1) Aceitar o papel "admin"
alter table public.profiles drop constraint if exists profiles_role_check;
alter table public.profiles add constraint profiles_role_check check (role in ('user','admin','master'));

-- 2) Quem é o dono da conta da empresa (uma linha só)
create table if not exists public.nms_config (
  id int primary key default 1 check (id = 1),
  empresa_uid uuid references auth.users on delete set null
);
alter table public.nms_config enable row level security;
-- sem políticas: ninguém lê nem grava direto; só pelas funções abaixo

create or replace function public.nms_empresa_uid() returns uuid
language sql stable security definer set search_path = public as $$
  select empresa_uid from public.nms_config where id = 1
$$;

create or replace function public.nms_is_admin() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.profiles where id = auth.uid() and role in ('admin','master'))
$$;

-- o caminho pertence à conta da empresa?
create or replace function public.nms_caminho_empresa(p text) returns boolean
language sql stable security definer set search_path = public as $$
  select e is not null and (
    p = 'data/users/' || e || '/nms' or p like 'data/users/' || e || '/nms/%'
    or p = 'membros/' || e || '/perfis/nms'
  ) from (select public.nms_empresa_uid()::text as e) x
$$;

revoke execute on function public.nms_empresa_uid() from public, anon;
revoke execute on function public.nms_is_admin() from public, anon;
revoke execute on function public.nms_caminho_empresa(text) from public, anon;
grant execute on function public.nms_empresa_uid() to authenticated;
grant execute on function public.nms_is_admin() to authenticated;
grant execute on function public.nms_caminho_empresa(text) to authenticated;

-- 3) Regras de acesso aos dados
drop policy if exists "docs: ler" on public.docs;
drop policy if exists "docs: criar" on public.docs;
drop policy if exists "docs: alterar" on public.docs;
drop policy if exists "docs: excluir" on public.docs;

create policy "docs: ler" on public.docs for select to authenticated using (
  owner = (select auth.uid())
  or (select public.nms_is_master())
  or ((select public.nms_is_admin()) and public.nms_caminho_empresa(path))
);
create policy "docs: criar" on public.docs for insert to authenticated with check (
  owner = (select auth.uid()) or ((select public.nms_is_admin()) and public.nms_caminho_empresa(path))
);
create policy "docs: alterar" on public.docs for update to authenticated
  using (owner = (select auth.uid()) or ((select public.nms_is_admin()) and public.nms_caminho_empresa(path)))
  with check (owner = (select auth.uid()) or ((select public.nms_is_admin()) and public.nms_caminho_empresa(path)));
create policy "docs: excluir" on public.docs for delete to authenticated using (
  owner = (select auth.uid()) or ((select public.nms_is_admin()) and public.nms_caminho_empresa(path))
);

-- 4) Configuração desta instalação
--    A conta da empresa (NMS) é a do Nykollas (Master). Kayan vira Admin.
insert into public.nms_config (id, empresa_uid)
  values (1, (select id from public.profiles where lower(nome) = 'nykollas' and role = 'master' order by created_at limit 1))
  on conflict (id) do update set empresa_uid = excluded.empresa_uid;
update public.profiles set role = 'admin' where lower(nome) = 'kayan';
