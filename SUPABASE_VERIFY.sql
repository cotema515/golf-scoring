-- Golf Scoring normalized-backend verification checklist.
-- Run these in Supabase SQL Editor before an important TestFlight/App Store push.

-- 1) Legacy snapshot storage should not exist anymore.
select table_name
from information_schema.tables
where table_schema = 'public'
  and table_name ilike '%snapshot%';

-- Expected: zero rows.

-- 2) Round data should be structurally complete.
select
  (select count(*) from public.golf_rounds) as rounds,
  (select count(*) from public.golf_round_holes) as round_holes,
  (select count(*) from public.golf_hole_scores) as hole_scores,
  (select count(*) from public.golf_rounds) * 18 as expected_round_holes,
  (select count(*) from public.golf_rounds) * 18 * 4 as expected_hole_scores;

-- Expected for the current family archive: 11 rounds, 198 round_holes, 792 hole_scores.

-- 3) Find accidentally duplicated rounds by trip/course/date.
select
  t.name as trip_name,
  r.course_name,
  r.played_at::date as played_date,
  count(*) as round_count
from public.golf_rounds r
join public.golf_trips t on t.id = r.trip_id
group by t.name, r.course_name, r.played_at::date
having count(*) > 1
order by played_date, course_name;

-- Expected: Pacific Dunes can appear twice only if the played dates are different.

-- 4) Confirm profile-photo metadata exists separately from score payloads.
select player_key, storage_bucket, storage_path, updated_at
from public.golf_profile_photos
order by player_key;

-- Expected: rows for matt, josh, shane, and jeff.

-- 5) Review the most recent edit log entries.
select created_at, actor_name, entity_type, action, summary
from public.app_edit_log
order by created_at desc
limit 25;

-- Expected: human-readable summaries such as "Matt Cote changed Shane Cote handicap index..."
