-- Repair pending applications whose avatar URL was stored as an empty string.
update public.profiles as profile
set avatar_url = nullif(
  btrim(auth_user.raw_user_meta_data ->> 'avatar_url'),
  ''
)
from auth.users as auth_user
where profile.id = auth_user.id
  and profile.status = 'pending'
  and nullif(btrim(profile.avatar_url), '') is null
  and nullif(btrim(auth_user.raw_user_meta_data ->> 'avatar_url'), '') is not null;
