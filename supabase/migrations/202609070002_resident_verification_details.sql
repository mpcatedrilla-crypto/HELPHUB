-- Make sign-up details available in the profile record administrators review.
alter table public.profiles
  add column if not exists email text,
  add column if not exists first_name text,
  add column if not exists middle_name text,
  add column if not exists last_name text,
  add column if not exists gender text,
  add column if not exists age integer,
  add column if not exists birthday date,
  add column if not exists avatar_url text;

-- Backfill existing accounts from the metadata collected during sign-up.
update public.profiles as profile
set
  email = coalesce(profile.email, auth_user.email),
  first_name = coalesce(profile.first_name, auth_user.raw_user_meta_data ->> 'first_name'),
  middle_name = coalesce(profile.middle_name, auth_user.raw_user_meta_data ->> 'middle_name'),
  last_name = coalesce(profile.last_name, auth_user.raw_user_meta_data ->> 'last_name'),
  gender = coalesce(profile.gender, auth_user.raw_user_meta_data ->> 'gender'),
  age = coalesce(
    profile.age,
    case
      when (auth_user.raw_user_meta_data ->> 'age') ~ '^[0-9]+$'
      then (auth_user.raw_user_meta_data ->> 'age')::integer
    end
  ),
  birthday = coalesce(
    profile.birthday,
    case
      when (auth_user.raw_user_meta_data ->> 'birthday') ~ '^\\d{4}-\\d{2}-\\d{2}$'
      then (auth_user.raw_user_meta_data ->> 'birthday')::date
    end
  ),
  avatar_url = coalesce(profile.avatar_url, auth_user.raw_user_meta_data ->> 'avatar_url')
from auth.users as auth_user
where profile.id = auth_user.id;
