import Foundation

enum AppPersistence {
    private static let profileKey = "golfScoring.profile.v1"
    private static let isSignedInKey = "golfScoring.isSignedIn.v1"
    private static let hasSavedProfileKey = "golfScoring.hasSavedProfile.v1"
    private static let authSessionKey = "golfScoring.authSession.v1"
    private static let activeGameModeKey = "golfScoring.activeGameMode.v1"

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

    static func loadAuthSession() -> AuthSession? {
        load(AuthSession.self, forKey: authSessionKey)
    }

    static func saveAuthSession(_ session: AuthSession?) {
        if let session {
            save(session, forKey: authSessionKey)
        } else {
            UserDefaults.standard.removeObject(forKey: authSessionKey)
        }
    }

    static func loadActiveGameMode() -> AppGameMode? {
        load(AppGameMode.self, forKey: activeGameModeKey)
    }

    static func saveActiveGameMode(_ mode: AppGameMode?) {
        if let mode {
            save(mode, forKey: activeGameModeKey)
        } else {
            UserDefaults.standard.removeObject(forKey: activeGameModeKey)
        }
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
