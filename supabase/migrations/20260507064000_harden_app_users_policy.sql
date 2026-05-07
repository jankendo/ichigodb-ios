alter table public.app_users enable row level security;

drop policy if exists public_all_app_users on public.app_users;
drop policy if exists admin_read_app_users on public.app_users;

create policy admin_read_app_users
on public.app_users
for select
to authenticated
using (public.is_admin());

revoke all on public.app_users from anon;
revoke all on public.app_users from authenticated;

revoke execute on function public.is_admin() from anon;
grant execute on function public.is_admin() to authenticated;
