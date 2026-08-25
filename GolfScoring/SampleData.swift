import Foundation

extension FriendProfile {
    static let coteGroupPlayers = [
        FriendProfile(firstName: "Matt", lastName: "Cote", handicapIndex: 9.4, playerKey: "matt"),
        FriendProfile(firstName: "Josh", lastName: "Cote", handicapIndex: 13.0, playerKey: "josh"),
        FriendProfile(firstName: "Shane", lastName: "Cote", handicapIndex: 9.0, playerKey: "shane"),
        FriendProfile(firstName: "Jeff", lastName: "Cote", handicapIndex: 18.7, playerKey: "jeff")
    ]

    static let dummyFriends = coteGroupPlayers.filter { $0.firstName != "Matt" }

    static func groupPlayers(excluding profile: UserProfile) -> [FriendProfile] {
        let currentFirstName = profile.firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        let currentLastName = profile.lastName.trimmingCharacters(in: .whitespacesAndNewlines)

        return coteGroupPlayers.filter { player in
            !(player.firstName.localizedCaseInsensitiveCompare(currentFirstName) == .orderedSame &&
              player.lastName.localizedCaseInsensitiveCompare(currentLastName) == .orderedSame)
        }
    }

    func matches(_ other: FriendProfile) -> Bool {
        if let playerKey, let otherKey = other.playerKey, !playerKey.isEmpty, !otherKey.isEmpty {
            return playerKey == otherKey
        }

        return firstName.localizedCaseInsensitiveCompare(other.firstName) == .orderedSame &&
        lastName.localizedCaseInsensitiveCompare(other.lastName) == .orderedSame
    }

    func matches(_ profile: UserProfile) -> Bool {
        if let playerKey, let profileKey = profile.playerKey, !playerKey.isEmpty, !profileKey.isEmpty {
            return playerKey == profileKey
        }

        return firstName.localizedCaseInsensitiveCompare(profile.firstName) == .orderedSame &&
        lastName.localizedCaseInsensitiveCompare(profile.lastName) == .orderedSame
    }

    func withInferredPlayerKey() -> FriendProfile {
        guard playerKey == nil || playerKey?.isEmpty == true else { return self }
        var copy = self
        copy.playerKey = Self.inferredPlayerKey(firstName: firstName, lastName: lastName)
        return copy
    }

    static func inferredPlayerKey(firstName: String, lastName: String) -> String? {
        guard lastName.localizedCaseInsensitiveCompare("Cote") == .orderedSame else { return nil }
        switch firstName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "matt":
            return "matt"
        case "josh":
            return "josh"
        case "shane":
            return "shane"
        case "jeff", "dad":
            return "jeff"
        default:
            return nil
        }
    }
}
