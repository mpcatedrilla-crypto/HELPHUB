-- Repair the live profile schema used by the administrator verification queue.
-- This migration is idempotent so it is safe to run on projects that already
-- received either of the earlier resident-verification migrations.
alter table public.profiles
  add column if not exists email text,
  add column if not exists first_name text,
  add column if not exists middle_name text,
  add column if not exists last_name text,
  add column if not exists gender text,
  add column if not exists age integer,
  add column if not exists birthday date,
  add column if not exists avatar_url text,
  add column if not exists verification_requested_at timestamptz;

-- Recover the information residents already supplied during registration and
-- profile editing. nullif/btrim also repairs legacy rows containing blanks.
update public.profiles as profile
set
  email = coalesce(
    nullif(btrim(profile.email), ''),
    nullif(btrim(auth_user.email), '')
  ),
  full_name = coalesce(
    nullif(btrim(profile.full_name), ''),
    nullif(btrim(auth_user.raw_user_meta_data ->> 'full_name'), '')
  ),
  first_name = coalesce(
    nullif(btrim(profile.first_name), ''),
    nullif(btrim(auth_user.raw_user_meta_data ->> 'first_name'), '')
  ),
  middle_name = coalesce(
    nullif(btrim(profile.middle_name), ''),
    nullif(btrim(auth_user.raw_user_meta_data ->> 'middle_name'), '')
  ),
  last_name = coalesce(
    nullif(btrim(profile.last_name), ''),
    nullif(btrim(auth_user.raw_user_meta_data ->> 'last_name'), '')
  ),
  gender = coalesce(
    nullif(btrim(profile.gender), ''),
    nullif(btrim(auth_user.raw_user_meta_data ->> 'gender'), '')
  ),
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
      when (auth_user.raw_user_meta_data ->> 'birthday') ~ '^\d{4}-\d{2}-\d{2}$'
      then (auth_user.raw_user_meta_data ->> 'birthday')::date
    end
  ),
  phone = coalesce(
    nullif(btrim(profile.phone), ''),
    nullif(btrim(auth_user.raw_user_meta_data ->> 'phone'), '')
  ),
  address = coalesce(
    nullif(btrim(profile.address), ''),
    nullif(btrim(auth_user.raw_user_meta_data ->> 'address'), '')
  ),
  avatar_url = coalesce(
    nullif(btrim(profile.avatar_url), ''),
    nullif(btrim(auth_user.raw_user_meta_data ->> 'avatar_url'), '')
  ),
  verification_requested_at = coalesce(
    profile.verification_requested_at,
    case
      when coalesce(
        auth_user.raw_user_meta_data ->> 'verification_submitted',
        'false'
      ) = 'true'
      then auth_user.updated_at
    end
  )
from auth.users as auth_user
where profile.id = auth_user.id;

create index if not exists profiles_pending_verification_idx
  on public.profiles (verification_requested_at desc)
  where status = 'pending';
