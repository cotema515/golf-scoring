import SwiftUI

@MainActor
final class AccountStore: ObservableObject {
    @Published var isSignedIn = AppPersistence.loadIsSignedIn()
    @Published var hasSavedProfile = AppPersistence.loadHasSavedProfile()
    @Published var profile = AppPersistence.loadProfile()
    @Published private var groupPlayers = AppPersistence.loadGroupPlayers()
    @Published var friends: [FriendProfile] = []

    var allGroupPlayers: [FriendProfile] {
        groupPlayers
    }

    init() {
        if profile.playerKey == nil || profile.playerKey?.isEmpty == true {
            profile.playerKey = FriendProfile.inferredPlayerKey(firstName: profile.firstName, lastName: profile.lastName)
        }
        refreshGroupPlayers()
    }

    func signOut() {
        isSignedIn = false
        saveSession()
    }

    func saveProfile(replacing previousProfile: UserProfile? = nil) -> Bool {
        guard profile.isComplete else { return false }
        hasSavedProfile = true
        upsertCurrentProfileIntoGroupPlayers(replacing: previousProfile)
        refreshGroupPlayers()
        AppPersistence.saveProfile(profile)
        AppPersistence.saveHasSavedProfile(hasSavedProfile)
        AppPersistence.saveGroupPlayers(groupPlayers)
        return true
    }

    func applyPreloadedProfile(_ player: FriendProfile) {
        profile.firstName = player.firstName
        profile.lastName = player.lastName
        profile.handicapIndex = player.handicapIndex
        profile.profileImageData = player.profileImageData
        profile.playerKey = player.playerKey
        refreshGroupPlayers()
    }

    func signIn(as player: FriendProfile) {
        applyPreloadedProfile(player)
        profile.email = ""
        isSignedIn = true
        hasSavedProfile = true
        saveSession()
        AppPersistence.saveGroupPlayers(groupPlayers)
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
            AppPersistence.saveGroupPlayers(groupPlayers)
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
        AppPersistence.saveGroupPlayers(self.groupPlayers)
    }

    func applyCloudGroupPlayers(_ groupPlayers: [FriendProfile]) {
        guard !groupPlayers.isEmpty else { return }
        self.groupPlayers = groupPlayers.map { $0.withInferredPlayerKey() }

        if let matchingPlayer = self.groupPlayers.first(where: { $0.matches(profile) }) {
            profile.profileImageData = matchingPlayer.profileImageData
            profile.handicapIndex = matchingPlayer.handicapIndex
            profile.playerKey = matchingPlayer.playerKey
            AppPersistence.saveProfile(profile)
        }

        refreshGroupPlayers()
        AppPersistence.saveGroupPlayers(self.groupPlayers)
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
}
