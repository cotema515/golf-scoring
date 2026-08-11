# Golf Scoring implementation notes

## Bundle ID

Current bundle identifier:

`com.mattcote.golfscoring`

You do not need to own `mattcote.com` for this. Reverse-domain bundle IDs are a naming convention. The important thing is that this ID is unique in the Apple Developer account/team you use for signing, TestFlight, or App Store distribution.

Before sending the app to anyone, open Xcode and select your Apple development team under:

`GolfScoring target > Signing & Capabilities > Team`

## Storage today

The app is currently local-first. It saves profile/session/trip data into iOS `UserDefaults` through `GolfScoring/AppPersistence.swift`.

That means:

- Simulator data stays on the simulator.
- Phone data stays on that phone.
- Reinstalling the app can clear data.
- Brothers will not automatically share rounds yet.

## Backend plan

`GolfScoring/BackendService.swift` now defines the future backend seam:

- `SignInProviding` for Google sign-in
- `AppDataProviding` for loading/saving user and trip data
- `AppSnapshot` for the data bundle we will sync

Recommended next backend choice: Firebase, because it pairs naturally with Google sign-in and gives us authentication plus a hosted database in one ecosystem.

To actually enable Google sign-in/cloud sync later, we will need:

1. A Firebase project.
2. iOS app registered in Firebase using `com.mattcote.golfscoring`.
3. The generated `GoogleService-Info.plist` added to Xcode.
4. Firebase Auth and Firestore packages added in Xcode.
5. The local stores wired to the Firebase implementation.

## Course catalog

The course catalog is currently bundled in `GolfScoring/CourseCatalog.swift`. This is fine for the first family trip. Later, if you want courses to update without shipping a new app build, move the catalog to the backend.

## Scoring

Scoring formulas now live in `GolfScoring/ScoringEngine.swift`. UI screens should call the model/scoring helpers instead of duplicating math.
