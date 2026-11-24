-- NMS 1.9.9 · Staff: atividades diárias da equipe NMS (só para pessoas autorizadas)
-- O que muda:
--   • Nova tabela nms_staff: uma linha por atividade (título, responsável, dia, pendente/feito, observação).
--   • Só quem está na lista nms_config.staff_uids lê ou grava (regra no banco, não só no menu).
--   • Nesta instalação a lista tem Nykollas e Kayan.
-- Pode rodar de novo sem problema.

-- 1) Lista de quem pode usar o Staff
alter table public.nms_config add column if not exists staff_uids uuid[] not null default '{}';

create or replace function public.nms_pode_staff() returns boolean
language sql stable security definer set search_path = public as $$
  select coalesce((select auth.uid() = any(staff_uids) from public.nms_config where id = 1), false)
$$;
revoke execute on function public.nms_pode_staff() from public, anon;
grant execute on function public.nms_pode_staff() to authenticated;

-- Nomes da equipe (para escolher o responsável); só quem é da equipe consegue ver
create or replace function public.nms_staff_equipe() returns table (id uuid, nome text)
language sql stable security definer set search_path = public as $$
  select p.id, p.nome from public.profiles p, public.nms_config c
  where c.id = 1 and p.id = any(c.staff_uids) and auth.uid() = any(c.staff_uids)
  order by p.nome
$$;
revoke execute on function public.nms_staff_equipe() from public, anon;
grant execute on function public.nms_staff_equipe() to authenticated;

-- 2) Atividades
create table if not exists public.nms_staff (
  id uuid primary key default gen_random_uuid(),
  titulo text not null check (length(trim(titulo)) between 1 and 200),
  responsavel uuid,                      -- vazio = os dois
  dia date not null default current_date,
  status text not null default 'pendente' check (status in ('pendente','feito')),
  obs text not null default '',
  criado_por uuid default auth.uid(),
  criado_em timestamptz not null default now(),
  feito_por uuid,
  feito_em timestamptz,
  updated_at timestamptz not null default now()
);
create index if not exists nms_staff_dia on public.nms_staff (dia);
alter table public.nms_staff enable row level security;
revoke all on public.nms_staff from anon;

drop policy if exists "staff: ler" on public.nms_staff;
drop policy if exists "staff: criar" on public.nms_staff;
drop policy if exists "staff: alterar" on public.nms_staff;
drop policy if exists "staff: excluir" on public.nms_staff;
create policy "staff: ler" on public.nms_staff for select to authenticated using ((select public.nms_pode_staff()));
create policy "staff: criar" on public.nms_staff for insert to authenticated with check ((select public.nms_pode_staff()));
create policy "staff: alterar" on public.nms_staff for update to authenticated using ((select public.nms_pode_staff())) with check ((select public.nms_pode_staff()));
create policy "staff: excluir" on public.nms_staff for delete to authenticated using ((select public.nms_pode_staff()));

-- 3) Atualização em tempo real entre os aparelhos
do $$ begin
  alter publication supabase_realtime add table public.nms_staff;
exception when duplicate_object then null; end $$;

-- 4) Configuração desta instalação: Nykollas e Kayan
update public.nms_config set staff_uids = array(
  select id from public.profiles where lower(nome) in ('nykollas','kayan') order by created_at
) where id = 1;

-- Para incluir outra pessoa depois (troque o nome):
-- update public.nms_config set staff_uids = array_append(staff_uids, (select id from public.profiles where lower(nome) = 'NOME')) where id = 1;
