-- NMS 1.9.8 · Diagnóstico e precificação dentro do app (só para pessoas autorizadas da NMS)
-- O que muda:
--   • Nova tabela nms_diagnostico: clientes do diagnóstico e configurações da ferramenta.
--   • Só quem está na lista nms_config.diagnostico_uids lê ou grava (regra no banco, não só no menu).
--   • Nesta instalação a lista tem Nykollas e Kayan.
-- Pode rodar de novo sem problema.

-- 1) Lista de quem pode usar o diagnóstico
alter table public.nms_config add column if not exists diagnostico_uids uuid[] not null default '{}';

create or replace function public.nms_pode_diagnostico() returns boolean
language sql stable security definer set search_path = public as $$
  select coalesce((select auth.uid() = any(diagnostico_uids) from public.nms_config where id = 1), false)
$$;
revoke execute on function public.nms_pode_diagnostico() from public, anon;
grant execute on function public.nms_pode_diagnostico() to authenticated;

-- 2) Dados do diagnóstico (um registro por cliente e um de configurações)
create table if not exists public.nms_diagnostico (
  id text primary key,
  tipo text not null check (tipo in ('cliente','config')),
  data jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now(),
  updated_by uuid default auth.uid()
);
alter table public.nms_diagnostico enable row level security;
revoke all on public.nms_diagnostico from anon;

drop policy if exists "diagnostico: ler" on public.nms_diagnostico;
drop policy if exists "diagnostico: criar" on public.nms_diagnostico;
drop policy if exists "diagnostico: alterar" on public.nms_diagnostico;
drop policy if exists "diagnostico: excluir" on public.nms_diagnostico;
create policy "diagnostico: ler" on public.nms_diagnostico for select to authenticated using ((select public.nms_pode_diagnostico()));
create policy "diagnostico: criar" on public.nms_diagnostico for insert to authenticated with check ((select public.nms_pode_diagnostico()));
create policy "diagnostico: alterar" on public.nms_diagnostico for update to authenticated using ((select public.nms_pode_diagnostico())) with check ((select public.nms_pode_diagnostico()));
create policy "diagnostico: excluir" on public.nms_diagnostico for delete to authenticated using ((select public.nms_pode_diagnostico()));

-- 3) Atualização em tempo real entre os aparelhos
do $$ begin
  alter publication supabase_realtime add table public.nms_diagnostico;
exception when duplicate_object then null; end $$;

-- 4) Configuração desta instalação: Nykollas e Kayan
update public.nms_config set diagnostico_uids = array(
  select id from public.profiles where lower(nome) in ('nykollas','kayan') order by created_at
) where id = 1;

-- Para incluir outra pessoa depois (troque o nome):
-- update public.nms_config set diagnostico_uids = array_append(diagnostico_uids, (select id from public.profiles where lower(nome) = 'NOME')) where id = 1;
