import SwiftUI

@MainActor
final class AccountStore: ObservableObject {
    @Published var isSignedIn = AppPersistence.loadIsSignedIn()
    @Published var hasSavedProfile = AppPersistence.loadHasSavedProfile()
    @Published var profile = AppPersistence.loadProfile()
    @Published private(set) var authSession = AppPersistence.loadAuthSession()
    @Published var activeGameMode = AppPersistence.loadActiveGameMode()
    @Published private(set) var groupPlayersRevision = UUID()
    @Published private var groupPlayers = FriendProfile.coteGroupPlayers
    @Published var friends: [FriendProfile] = []
    @Published var authErrorMessage: String?

    private let authClient = SupabaseAuthClient()

    var allGroupPlayers: [FriendProfile] {
        groupPlayers
    }

    var needsGameModeChoice: Bool {
        isSignedIn && hasSavedProfile && profile.isCoteCupProfile && activeGameMode == nil
    }

    init() {
        if profile.playerKey == nil || profile.playerKey?.isEmpty == true {
            profile.playerKey = FriendProfile.inferredPlayerKey(firstName: profile.firstName, lastName: profile.lastName)
        }
        refreshGroupPlayers()
    }

    func signOut() {
        isSignedIn = false
        authSession = nil
        activeGameMode = nil
        AppPersistence.saveAuthSession(nil)
        AppPersistence.saveActiveGameMode(nil)
        saveSession()
    }

    func createProfile(username: String, firstName: String, lastName: String, email: String, password: String, handicapIndex: Double) async -> Bool {
        let cleanEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let cleanUsername = username.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        var newProfile = UserProfile(
            username: cleanUsername,
            email: cleanEmail,
            firstName: firstName.trimmingCharacters(in: .whitespacesAndNewlines),
            lastName: lastName.trimmingCharacters(in: .whitespacesAndNewlines),
            handicapIndex: handicapIndex,
            playerKey: FriendProfile.inferredPlayerKey(firstName: firstName, lastName: lastName),
            profileType: FriendProfile.inferredPlayerKey(firstName: firstName, lastName: lastName) == nil ? .general : .coteCup
        )

        guard newProfile.isComplete, !cleanUsername.isEmpty, !cleanEmail.isEmpty, password.count >= 6 else {
            authErrorMessage = "Enter your username, name, email, password, and Handicap Index. Password must be at least 6 characters."
            return false
        }

        do {
            let result = try await authClient.signUp(profile: newProfile, password: password)
            newProfile = result.0
            profile = newProfile
            authSession = result.1
            isSignedIn = true
            hasSavedProfile = true
            activeGameMode = profile.isCoteCupProfile ? nil : .general
            if profile.isCoteCupProfile {
                upsertCurrentProfileIntoGroupPlayers()
                refreshGroupPlayers()
                groupPlayersRevision = UUID()
            }
            persistAuthState()
            authErrorMessage = authSession == nil ? "Profile created. Check your email if Supabase asks for confirmation before logging in." : nil
            return true
        } catch {
            authErrorMessage = error.localizedDescription
            return false
        }
    }

    func login(loginIdentifier: String, password: String) async -> Bool {
        let cleanIdentifier = loginIdentifier.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !cleanIdentifier.isEmpty, !password.isEmpty else {
            authErrorMessage = "Enter your email or username and password."
            return false
        }

        do {
            let result = try await authClient.signIn(loginIdentifier: cleanIdentifier, password: password)
            profile = result.0
            authSession = result.1
            isSignedIn = true
            hasSavedProfile = profile.isComplete
            activeGameMode = profile.isCoteCupProfile ? nil : .general
            if profile.isCoteCupProfile {
                upsertCurrentProfileIntoGroupPlayers()
                refreshGroupPlayers()
                groupPlayersRevision = UUID()
            }
            persistAuthState()
            authErrorMessage = nil
            return true
        } catch {
            authErrorMessage = error.localizedDescription
            return false
        }
    }

    func startNewGeneralProfile() {
        profile = UserProfile(profileType: .general)
        isSignedIn = false
        hasSavedProfile = false
        refreshGroupPlayers()
        saveSession()
    }

    func chooseGameMode(_ mode: AppGameMode) {
        activeGameMode = mode
        AppPersistence.saveActiveGameMode(mode)
    }

    func returnToGameModeChoice() {
        guard profile.isCoteCupProfile else { return }
        activeGameMode = nil
        AppPersistence.saveActiveGameMode(nil)
    }

    func saveProfile(replacing previousProfile: UserProfile? = nil) -> Bool {
        guard profile.isComplete else { return false }
        hasSavedProfile = true
        if profile.isCoteCupProfile {
            upsertCurrentProfileIntoGroupPlayers(replacing: previousProfile)
            refreshGroupPlayers()
            groupPlayersRevision = UUID()
        }
        AppPersistence.saveProfile(profile)
        AppPersistence.saveHasSavedProfile(hasSavedProfile)
        return true
    }

    func applyPreloadedProfile(_ player: FriendProfile) {
        profile.firstName = player.firstName
        profile.lastName = player.lastName
        profile.handicapIndex = player.handicapIndex
        profile.profileImageData = player.profileImageData
        profile.playerKey = player.playerKey
        profile.username = player.playerKey ?? player.firstName.lowercased()
        profile.profileType = .coteCup
        refreshGroupPlayers()
    }

    func signIn(as player: FriendProfile) {
        applyPreloadedProfile(player)
        profile.email = ""
        isSignedIn = true
        hasSavedProfile = true
        saveSession()
    }

    func profileImageData(for playerName: String) -> Data? {
        groupPlayer(named: playerName)?.profileImageData
    }

    func handicapIndex(for playerName: String) -> Double? {
        groupPlayer(named: playerName)?.handicapIndex
    }

    func updateHandicapIndex(for playerName: String, to handicapIndex: Double) {
        let cleanName = playerName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else { return }

        if profile.fullName.localizedCaseInsensitiveCompare(cleanName) == .orderedSame {
            profile.handicapIndex = handicapIndex
            _ = saveProfile()
            return
        }

        if let index = groupPlayers.firstIndex(where: {
            $0.fullName.localizedCaseInsensitiveCompare(cleanName) == .orderedSame
        }) {
            groupPlayers[index].handicapIndex = handicapIndex
            refreshGroupPlayers()
            groupPlayersRevision = UUID()
        }
    }

    func groupPlayer(named playerName: String) -> FriendProfile? {
        if profile.fullName.localizedCaseInsensitiveCompare(playerName) == .orderedSame {
            return FriendProfile(
                firstName: profile.firstName,
                lastName: profile.lastName,
                handicapIndex: profile.handicapIndex ?? 0,
                profileImageData: profile.profileImageData,
                playerKey: profile.playerKey
            )
        }

        return groupPlayers.first {
            $0.fullName.localizedCaseInsensitiveCompare(playerName) == .orderedSame
        }
    }

    func applyCloudProfile(_ profile: UserProfile, groupPlayers: [FriendProfile], isSignedIn: Bool, hasSavedProfile: Bool) {
        self.profile = profile
        self.groupPlayers = groupPlayers.isEmpty ? FriendProfile.coteGroupPlayers : groupPlayers.map { $0.withInferredPlayerKey() }
        self.isSignedIn = isSignedIn
        self.hasSavedProfile = hasSavedProfile
        refreshGroupPlayers()
        saveSession()
    }

    func applyCloudGroupPlayers(_ groupPlayers: [FriendProfile]) {
        guard !groupPlayers.isEmpty else { return }
        let cloudPlayers = groupPlayers.map { $0.withInferredPlayerKey() }
        self.groupPlayers = mergeGroupPlayersPreservingImages(localPlayers: self.groupPlayers, cloudPlayers: cloudPlayers)

        if let matchingPlayer = self.groupPlayers.first(where: { $0.matches(profile) }) {
            if matchingPlayer.profileImageData != nil || profile.profileImageData == nil {
                profile.profileImageData = matchingPlayer.profileImageData
            }
            profile.handicapIndex = matchingPlayer.handicapIndex
            profile.playerKey = matchingPlayer.playerKey
            AppPersistence.saveProfile(profile)
        }

        refreshGroupPlayers()
    }

    private func mergeGroupPlayersPreservingImages(localPlayers: [FriendProfile], cloudPlayers: [FriendProfile]) -> [FriendProfile] {
        var mergedPlayers = cloudPlayers

        for localPlayer in localPlayers.map({ $0.withInferredPlayerKey() }) {
            guard let localImage = localPlayer.profileImageData else { continue }
            if let index = mergedPlayers.firstIndex(where: { $0.matches(localPlayer) }),
               mergedPlayers[index].profileImageData == nil {
                mergedPlayers[index].profileImageData = localImage
            }
        }

        for index in mergedPlayers.indices {
            if mergedPlayers[index].profileImageData == nil,
               let currentImage = profile.playerKey == mergedPlayers[index].playerKey ? profile.profileImageData : nil {
                mergedPlayers[index].profileImageData = currentImage
            }
        }

        return mergedPlayers
    }

    private func refreshGroupPlayers() {
        friends = groupPlayers.filter { player in
            !player.matches(profile)
        }
    }

    private func upsertCurrentProfileIntoGroupPlayers(replacing previousProfile: UserProfile? = nil) {
        guard profile.isComplete else { return }
        if profile.playerKey == nil || profile.playerKey?.isEmpty == true {
            profile.playerKey = previousProfile?.playerKey ?? FriendProfile.inferredPlayerKey(firstName: profile.firstName, lastName: profile.lastName)
        }

        let updatedPlayer = FriendProfile(
            firstName: profile.firstName,
            lastName: profile.lastName,
            handicapIndex: profile.handicapIndex ?? 0,
            profileImageData: profile.profileImageData,
            playerKey: profile.playerKey ?? FriendProfile.inferredPlayerKey(firstName: profile.firstName, lastName: profile.lastName)
        )

        if let previousProfile,
           let index = groupPlayers.firstIndex(where: { $0.matches(previousProfile) }) {
            groupPlayers[index].firstName = updatedPlayer.firstName
            groupPlayers[index].lastName = updatedPlayer.lastName
            groupPlayers[index].handicapIndex = updatedPlayer.handicapIndex
            groupPlayers[index].profileImageData = updatedPlayer.profileImageData
        } else if let index = groupPlayers.firstIndex(where: { $0.matches(profile) }) {
            groupPlayers[index].firstName = updatedPlayer.firstName
            groupPlayers[index].lastName = updatedPlayer.lastName
            groupPlayers[index].handicapIndex = updatedPlayer.handicapIndex
            groupPlayers[index].profileImageData = updatedPlayer.profileImageData
        } else {
            groupPlayers.append(updatedPlayer)
        }
    }

    private func saveSession() {
        AppPersistence.saveIsSignedIn(isSignedIn)
        AppPersistence.saveHasSavedProfile(hasSavedProfile)
        AppPersistence.saveProfile(profile)
    }

    private func persistAuthState() {
        AppPersistence.saveAuthSession(authSession)
        AppPersistence.saveActiveGameMode(activeGameMode)
        saveSession()
    }
}
