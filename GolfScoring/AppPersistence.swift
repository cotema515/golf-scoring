import Foundation

enum AppPersistence {
    private static let profileKey = "golfScoring.profile.v1"
    private static let isSignedInKey = "golfScoring.isSignedIn.v1"
    private static let hasSavedProfileKey = "golfScoring.hasSavedProfile.v1"
    private static let tripsKey = "golfScoring.trips.v1"
    private static let groupPlayersKey = "golfScoring.groupPlayers.v1"

    static func loadProfile() -> UserProfile {
        var profile = load(UserProfile.self, forKey: profileKey) ?? UserProfile()
        if profile.playerKey == nil || profile.playerKey?.isEmpty == true {
            profile.playerKey = FriendProfile.inferredPlayerKey(firstName: profile.firstName, lastName: profile.lastName)
        }
        return profile
    }

    static func saveProfile(_ profile: UserProfile) {
        save(profile, forKey: profileKey)
    }

    static func loadIsSignedIn() -> Bool {
        UserDefaults.standard.bool(forKey: isSignedInKey)
    }

    static func saveIsSignedIn(_ isSignedIn: Bool) {
        UserDefaults.standard.set(isSignedIn, forKey: isSignedInKey)
    }

    static func loadHasSavedProfile() -> Bool {
        UserDefaults.standard.bool(forKey: hasSavedProfileKey)
    }

    static func saveHasSavedProfile(_ hasSavedProfile: Bool) {
        UserDefaults.standard.set(hasSavedProfile, forKey: hasSavedProfileKey)
    }

    static func loadTrips() -> [GolfTrip] {
        if let savedTrips = load([GolfTrip].self, forKey: tripsKey) {
            return GolfTrip.mergedWithCurrentSamples(savedTrips)
        }

        return GolfTrip.sampleTrips
    }

    static func saveTrips(_ trips: [GolfTrip]) {
        save(trips, forKey: tripsKey)
    }

    static func loadGroupPlayers() -> [FriendProfile] {
        guard let savedPlayers = load([FriendProfile].self, forKey: groupPlayersKey) else {
            return FriendProfile.coteGroupPlayers
        }

        let normalizedSavedPlayers = savedPlayers.map { $0.withInferredPlayerKey() }
        var mergedPlayers = FriendProfile.coteGroupPlayers.map { seededPlayer in
            normalizedSavedPlayers.first { $0.matches(seededPlayer) } ?? seededPlayer
        }

        for savedPlayer in normalizedSavedPlayers
        where !mergedPlayers.contains(where: { $0.matches(savedPlayer) }) {
            mergedPlayers.append(savedPlayer)
        }

        return mergedPlayers
    }

    static func saveGroupPlayers(_ players: [FriendProfile]) {
        save(players, forKey: groupPlayersKey)
    }

    static func currentSnapshot(profile: UserProfile, trips: [GolfTrip], groupPlayers: [FriendProfile], isSignedIn: Bool, hasSavedProfile: Bool) -> AppSnapshot {
        AppSnapshot(
            profile: profile,
            trips: trips,
            groupPlayers: groupPlayers,
            isSignedIn: isSignedIn,
            hasSavedProfile: hasSavedProfile,
            savedAt: Date()
        )
    }

    static func applySnapshot(_ snapshot: AppSnapshot) {
        saveProfile(snapshot.profile)
        saveTrips(snapshot.trips)
        saveGroupPlayers(snapshot.groupPlayers)
        saveIsSignedIn(snapshot.isSignedIn)
        saveHasSavedProfile(snapshot.hasSavedProfile)
    }

    private static func load<T: Decodable>(_ type: T.Type, forKey key: String) -> T? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    private static func save<T: Encodable>(_ value: T, forKey key: String) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}
