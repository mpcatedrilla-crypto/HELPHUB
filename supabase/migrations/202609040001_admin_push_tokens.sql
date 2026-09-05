create table if not exists public.admin_push_tokens (
  token text primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  platform text not null default 'android',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint admin_push_tokens_platform_check
    check (platform in ('android', 'ios', 'web'))
);

create index if not exists admin_push_tokens_user_id_idx
  on public.admin_push_tokens(user_id);

alter table public.admin_push_tokens enable row level security;

drop policy if exists "Admins can read their push tokens" on public.admin_push_tokens;
create policy "Admins can read their push tokens"
  on public.admin_push_tokens for select to authenticated
  using (
    user_id = auth.uid() and exists (
      select 1 from public.profiles
      where profiles.id = auth.uid()
        and profiles.role = 'admin'
        and profiles.status = 'approved'
    )
  );

drop policy if exists "Admins can register their push tokens" on public.admin_push_tokens;
create policy "Admins can register their push tokens"
  on public.admin_push_tokens for insert to authenticated
  with check (
    user_id = auth.uid() and exists (
      select 1 from public.profiles
      where profiles.id = auth.uid()
        and profiles.role = 'admin'
        and profiles.status = 'approved'
    )
  );

drop policy if exists "Admins can refresh their push tokens" on public.admin_push_tokens;
create policy "Admins can refresh their push tokens"
  on public.admin_push_tokens for update to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

drop policy if exists "Admins can remove their push tokens" on public.admin_push_tokens;
create policy "Admins can remove their push tokens"
  on public.admin_push_tokens for delete to authenticated
  using (user_id = auth.uid());
