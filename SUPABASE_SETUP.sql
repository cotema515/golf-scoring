-- Golf Scoring Supabase setup
--
-- Current architecture:
-- - The app uses normalized public tables for players, trips, rounds, holes,
--   scores, course catalog records, and profile photo metadata.
-- - The family dataset is identified by group_id = 'cote-family-golf-scoring'.
-- - The app reads through an assembled RPC:
--     public.get_family_golf_data(p_group_id text)
-- - The app writes through small mutation RPCs:
--     public.upsert_family_golf_players(...)
--     public.upsert_family_golf_trip(...)
--     public.upsert_family_golf_round(...)
--     public.update_family_golf_completed_hole_scores(...)
--     public.delete_family_golf_round(...)
--     public.delete_family_golf_trip(...)
--     public.upsert_profile_photo_metadata(...)
--     public.delete_profile_photo_metadata(...)
--     public.get_auth_email_for_username(...)
--     public.upsert_app_user_profile(...)
-- - The legacy whole-dataset write RPC is blocked server-side.
-- - Edit history is stored in public.app_edit_log with human-readable summaries.
--
-- Auth username support:
-- The iOS app signs in through Supabase Auth with email/password. To also allow
-- username login, this table maps app usernames to Supabase Auth users and to
-- existing golf player records such as player_key = 'matt'.

create table if not exists public.app_user_profiles (
  auth_user_id uuid primary key references auth.users(id) on delete cascade,
  username text not null,
  email text not null,
  first_name text,
  last_name text,
  handicap_index numeric,
  player_key text,
  profile_type text not null default 'general',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index if not exists app_user_profiles_username_lower_key
on public.app_user_profiles (lower(username));

create unique index if not exists app_user_profiles_email_lower_key
on public.app_user_profiles (lower(email));

alter table public.app_user_profiles enable row level security;

revoke all on public.app_user_profiles from anon, authenticated;

drop policy if exists app_user_profiles_select_own on public.app_user_profiles;
create policy app_user_profiles_select_own
on public.app_user_profiles
for select
to authenticated
using ((select auth.uid()) = auth_user_id);

drop policy if exists app_user_profiles_update_own on public.app_user_profiles;
create policy app_user_profiles_update_own
on public.app_user_profiles
for update
to authenticated
using ((select auth.uid()) = auth_user_id)
with check ((select auth.uid()) = auth_user_id);

create or replace function public.get_auth_email_for_username(p_username text)
returns text
language sql
stable
security definer
set search_path = public
as $$
  select email
  from public.app_user_profiles
  where lower(username) = lower(trim(p_username))
  limit 1
$$;

revoke all on function public.get_auth_email_for_username(text) from public;
grant execute on function public.get_auth_email_for_username(text) to anon, authenticated;

create or replace function public.upsert_app_user_profile(
  p_auth_user_id uuid,
  p_username text,
  p_email text,
  p_first_name text,
  p_last_name text,
  p_handicap_index numeric,
  p_player_key text,
  p_profile_type text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if (select auth.uid()) is null or (select auth.uid()) <> p_auth_user_id then
    raise exception 'Not allowed to update another user profile';
  end if;

  insert into public.app_user_profiles (
    auth_user_id, username, email, first_name, last_name, handicap_index,
    player_key, profile_type, updated_at
  )
  values (
    p_auth_user_id, lower(trim(p_username)), lower(trim(p_email)), p_first_name,
    p_last_name, p_handicap_index, p_player_key, p_profile_type, now()
  )
  on conflict (auth_user_id) do update set
    username = excluded.username,
    email = excluded.email,
    first_name = excluded.first_name,
    last_name = excluded.last_name,
    handicap_index = excluded.handicap_index,
    player_key = excluded.player_key,
    profile_type = excluded.profile_type,
    updated_at = now();
end;
$$;

revoke all on function public.upsert_app_user_profile(uuid, text, text, text, text, numeric, text, text) from public;
revoke execute on function public.upsert_app_user_profile(uuid, text, text, text, text, numeric, text, text) from anon;
grant execute on function public.upsert_app_user_profile(uuid, text, text, text, text, numeric, text, text) to authenticated;

-- Golf App social/games support:
-- This side is intentionally separate from the Cote family game data. The live
-- Supabase project includes these normalized public tables:
--
--   public.app_friendships
--     user_id, friend_user_id, status, created_at
--
--   public.app_games
--     id, owner_user_id, name, format, status, course_name,
--     course_location, tee_name, course_setup, created_at, updated_at
--
--   public.app_game_players
--     game_id, user_id, display_name, username, handicap_index, team_name,
--     tee_time_group, created_at
--
--   public.app_game_hole_scores
--     game_id, player_user_id, hole_number, gross_score, updated_by, updated_at
--
-- The iOS app talks to this area through RPCs only:
--
--   public.search_golf_app_profiles(p_query text)
--   public.add_golf_app_friend(p_friend_user_id uuid)
--   public.get_golf_app_friends()
--   public.create_golf_app_game(
--     p_name text,
--     p_format text,
--     p_player_ids uuid[],
--     p_course_name text,
--     p_course_location text,
--     p_tee_name text,
--     p_course_setup jsonb,
--     p_team_assignments jsonb,
--     p_tee_time_assignments jsonb
--   )
--   public.get_golf_app_games()
--   public.get_golf_app_game_scores(p_game_id uuid)
--   public.upsert_golf_app_hole_score(
--     p_game_id uuid,
--     p_player_user_id uuid,
--     p_hole_number integer,
--     p_gross_score integer
--   )
--
-- General Golf App scoring model:
-- Score edits are intentionally small per-player/per-hole writes. Any player in
-- a game can update any score in that game, which supports groups split across
-- multiple tee times. The app then computes gross, net, course handicap, and
-- team standings from those hole-score rows.
--
-- Important design rule:
-- Do not reuse golf_trips/golf_rounds/golf_players for the general Golf App.
-- Those are the Cote family game tables. The general Golf App gets its own
-- tables/RPCs so games, permissions, and future formats can evolve cleanly.
--
-- Important:
-- The old single-row JSON setup is deprecated and should not be used for new
-- builds. Keep this file as a pointer to the current normalized setup so we do
-- not accidentally recreate the old structure later.
