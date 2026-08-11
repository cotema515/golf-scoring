# Golf Scoring cloud setup

This is the no-monthly-cost Friday setup.

## 1. Create the free Supabase project

1. Go to Supabase and create a free project.
2. Open the project.
3. Go to SQL Editor.
4. Paste and run `SUPABASE_SETUP.sql`.

## 2. Copy the app keys

In Supabase, go to Project Settings > API.

Copy:

- Project URL
- anon public key

## 3. Paste into Xcode

Open `Info.plist` and replace:

- `PASTE_SUPABASE_URL_HERE`
- `PASTE_SUPABASE_ANON_KEY_HERE`

The anon key is okay to ship in the app for this private TestFlight setup.

## 4. First run

Run the app once after the keys are pasted. The app will:

- keep saving locally on the phone
- push the shared trip/round data to Supabase
- refresh from Supabase every 20 seconds
- let anyone tap Refresh or Back Up Now on Home

## Friday behavior

Each person picks their golfer box on first launch. Everyone sees the same shared trips and scorecards after cloud sync is configured.

For this private version, concurrent edits are last-write-wins. That is acceptable for the weekend if one person is mainly entering scores. For the public/real app, replace this with authenticated users and per-hole score writes.
