-- Golf Scoring Friday-ready cloud setup.
-- Paste this into Supabase Dashboard > SQL Editor > New query, then Run.
--
-- This intentionally stores the small Cote golf dataset as one shared JSON
-- snapshot. For four known golfers, this is simpler and more dependable than
-- a large normalized schema. The app can evolve to separate players/trips/
-- rounds/scores tables later without changing the weekend workflow.

create table if not exists public.app_snapshots (
    id text primary key,
    payload jsonb not null,
    updated_at timestamptz not null default now()
);

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
    new.updated_at = now();
    return new;
end;
$$;

drop trigger if exists app_snapshots_set_updated_at on public.app_snapshots;

create trigger app_snapshots_set_updated_at
before update on public.app_snapshots
for each row
execute function public.set_updated_at();

alter table public.app_snapshots enable row level security;

grant usage on schema public to anon;
grant select, insert, update on public.app_snapshots to anon;

-- Friday/private mode:
-- The app uses the public anon key. For a tiny private TestFlight group, this
-- allows the app to read and write the one shared score snapshot.
--
-- Important: only distribute this build to the five intended TestFlight users.
-- After the trip, replace this with real auth/user policies before going public.

drop policy if exists "Golf Scoring app can read snapshots" on public.app_snapshots;
create policy "Golf Scoring app can read snapshots"
on public.app_snapshots
for select
to anon
using (id = 'cote-family-golf-scoring');

drop policy if exists "Golf Scoring app can insert snapshots" on public.app_snapshots;
create policy "Golf Scoring app can insert snapshots"
on public.app_snapshots
for insert
to anon
with check (id = 'cote-family-golf-scoring');

drop policy if exists "Golf Scoring app can update snapshots" on public.app_snapshots;
create policy "Golf Scoring app can update snapshots"
on public.app_snapshots
for update
to anon
using (id = 'cote-family-golf-scoring')
with check (id = 'cote-family-golf-scoring');
