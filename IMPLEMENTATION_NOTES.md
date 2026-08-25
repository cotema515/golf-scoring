# Golf Scoring implementation notes

## Bundle ID

Current bundle identifier:

`com.mattcote.golfscoring`

You do not need to own `mattcote.com` for this. Reverse-domain bundle IDs are a naming convention. The important thing is that this ID is unique in the Apple Developer account/team you use for signing, TestFlight, or App Store distribution.

Before sending the app to anyone, open Xcode and select your Apple development team under:

`GolfScoring target > Signing & Capabilities > Team`

## Storage today

Supabase is the source of truth for trips, rounds, scores, players, handicaps,
course records, and profile-photo metadata. The app keeps the current
trip/round list in memory while it is open, but it does not load or save
trip/round history from `UserDefaults` and it does not write local JSON backups.

The selected local profile/login choice can still be remembered on-device so
each person does not have to choose their golfer every launch.

The cloud source of truth is the normalized Supabase schema:

- `golf_players`
- `golf_trips`
- `golf_rounds`
- `golf_round_players`
- `golf_round_holes`
- `golf_hole_scores`
- `golf_courses`
- `golf_course_tees`
- `golf_course_holes`
- `golf_profile_photos`
- `app_edit_log`

`app_edit_log` is the change log table. It records who edited data, which table
changed, what fields changed, before/after JSON, and a human-readable summary
such as “Matt Cote changed Shane Cote handicap index from 9.0 to 8.1.”

The app still reads one assembled family data object for convenience, but normal
writes are small mutation calls:

- player/profile/handicap updates
- trip edits
- one-round save/update
- completed-round inline hole-score edits
- one-round delete
- one-trip delete

The old whole-dataset replacement RPC is blocked in Supabase so stale installed
builds cannot overwrite current normalized data.

In the app, trip and round mutations are routed through `GolfMutationService` in
`GolfScoring/HomeNavigation.swift`. Keep future trip and round mutations there
so views do not drift back into scattered direct Supabase writes.

Current write split:

- In-progress rounds and final round submission send one complete round. This
  keeps live scoring checkpoints consistent while the app owns the score math.
- Post-round inline score edits send one edited hole plus the recalculated round
  totals/result. This avoids re-sending the entire round when someone fixes a
  completed scorecard.

Before important releases, run `SUPABASE_VERIFY.sql` in Supabase SQL Editor to
check for old snapshot tables, duplicate rounds, complete hole/score counts,
profile-photo metadata, and recent changelog entries.

## Course catalog

The course catalog is currently bundled in `GolfScoring/CourseCatalog.swift`. This is fine for the first family trip. Later, if you want courses to update without shipping a new app build, move the catalog to the backend.

## Scoring

Scoring formulas now live in `GolfScoring/ScoringEngine.swift`. UI screens should call the model/scoring helpers instead of duplicating math.
