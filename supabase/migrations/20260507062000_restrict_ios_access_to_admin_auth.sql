-- Restrict IchigoDB iOS access to Supabase Auth users listed in public.app_users as admin.
-- The app now sends the signed-in user's JWT. The legacy anon key remains public,
-- but anon can no longer read or write app data or storage objects.

create table if not exists public.app_users (
    user_id uuid primary key references auth.users(id) on delete cascade,
    email text,
    role text not null check (role in ('admin')),
    created_at timestamptz not null default now()
);

insert into public.app_users (user_id, email, role)
select id, email, 'admin'
from auth.users
where lower(email) = 'jankendo14@gmail.com'
on conflict (user_id) do update
set email = excluded.email,
    role = 'admin';

create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
    select exists (
        select 1
        from public.app_users
        where user_id = auth.uid()
          and role = 'admin'
    );
$$;

revoke all on public.app_users from anon;
revoke all on public.app_users from authenticated;

alter table public.varieties enable row level security;
alter table public.reviews enable row level security;
alter table public.variety_parent_links enable row level security;
alter table public.variety_images enable row level security;
alter table public.review_images enable row level security;

drop policy if exists public_all_varieties on public.varieties;
drop policy if exists public_all_reviews on public.reviews;
drop policy if exists public_all_variety_parent_links on public.variety_parent_links;
drop policy if exists public_all_variety_images on public.variety_images;
drop policy if exists public_all_review_images on public.review_images;

drop policy if exists admin_all_varieties on public.varieties;
drop policy if exists admin_all_reviews on public.reviews;
drop policy if exists admin_all_variety_parent_links on public.variety_parent_links;
drop policy if exists admin_all_variety_images on public.variety_images;
drop policy if exists admin_all_review_images on public.review_images;

create policy admin_all_varieties
on public.varieties
for all
to authenticated
using (public.is_admin())
with check (public.is_admin());

create policy admin_all_reviews
on public.reviews
for all
to authenticated
using (public.is_admin())
with check (public.is_admin());

create policy admin_all_variety_parent_links
on public.variety_parent_links
for all
to authenticated
using (public.is_admin())
with check (public.is_admin());

create policy admin_all_variety_images
on public.variety_images
for all
to authenticated
using (public.is_admin())
with check (public.is_admin());

create policy admin_all_review_images
on public.review_images
for all
to authenticated
using (public.is_admin())
with check (public.is_admin());

alter view if exists public.variety_library_cards set (security_invoker = true);
alter view if exists public.review_analysis_cards set (security_invoker = true);

revoke select on public.variety_library_cards from anon;
revoke select on public.review_analysis_cards from anon;
grant select on public.variety_library_cards to authenticated;
grant select on public.review_analysis_cards to authenticated;

revoke execute on function public.get_analysis_snapshot() from anon;
grant execute on function public.get_analysis_snapshot() to authenticated;

drop policy if exists public_select_variety_images on storage.objects;
drop policy if exists public_select_review_images on storage.objects;
drop policy if exists public_write_variety_images on storage.objects;
drop policy if exists public_write_review_images on storage.objects;

drop policy if exists admin_select_variety_images on storage.objects;
drop policy if exists admin_select_review_images on storage.objects;
drop policy if exists admin_write_variety_images on storage.objects;
drop policy if exists admin_write_review_images on storage.objects;

create policy admin_select_variety_images
on storage.objects
for select
to authenticated
using (bucket_id = 'variety-images' and public.is_admin());

create policy admin_select_review_images
on storage.objects
for select
to authenticated
using (bucket_id = 'review-images' and public.is_admin());

create policy admin_write_variety_images
on storage.objects
for all
to authenticated
using (bucket_id = 'variety-images' and public.is_admin())
with check (bucket_id = 'variety-images' and public.is_admin());

create policy admin_write_review_images
on storage.objects
for all
to authenticated
using (bucket_id = 'review-images' and public.is_admin())
with check (bucket_id = 'review-images' and public.is_admin());
