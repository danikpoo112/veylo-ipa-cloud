
-- VEYLO IPA CLOUD
-- Private storage and user profiles

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  used_bytes bigint not null default 0,
  quota_bytes bigint not null default 10737418240,
  created_at timestamptz not null default now()
);

alter table public.profiles enable row level security;

create policy "Users read own profile"
on public.profiles
for select
to authenticated
using (auth.uid() = id);

create or replace function public.veylo_create_profile()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id)
  values (new.id)
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists veylo_auth_user_created on auth.users;

create trigger veylo_auth_user_created
after insert on auth.users
for each row
execute procedure public.veylo_create_profile();

insert into public.profiles (id)
select id from auth.users
on conflict (id) do nothing;

insert into storage.buckets
(id, name, public, file_size_limit, allowed_mime_types)
values (
  'ipa-files',
  'ipa-files',
  false,
  1073741824,
  array['application/octet-stream','application/zip']
)
on conflict (id) do update
set public = false;

create policy "VEYLO read own files"
on storage.objects
for select
to authenticated
using (
  bucket_id = 'ipa-files'
  and (storage.foldername(name))[1] = auth.uid()::text
);

create policy "VEYLO upload own files"
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'ipa-files'
  and (storage.foldername(name))[1] = auth.uid()::text
);

create policy "VEYLO delete own files"
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'ipa-files'
  and (storage.foldername(name))[1] = auth.uid()::text
);
