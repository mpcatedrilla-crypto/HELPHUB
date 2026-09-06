insert into storage.buckets (id, name, public)
values ('avatars', 'avatars', true)
on conflict (id) do update set public = excluded.public;

drop policy if exists "Residents can upload their avatar" on storage.objects;
create policy "Residents can upload their avatar"
on storage.objects for insert to authenticated
with check (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);

drop policy if exists "Residents can update their avatar" on storage.objects;
create policy "Residents can update their avatar"
on storage.objects for update to authenticated
using (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text)
with check (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);

drop policy if exists "Public avatars are viewable" on storage.objects;
create policy "Public avatars are viewable"
on storage.objects for select to public
using (bucket_id = 'avatars');
