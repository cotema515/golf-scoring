import Foundation

@MainActor
final class GolfAppStore: ObservableObject {
    @Published private(set) var friends: [GolfAppUser] = []
    @Published private(set) var searchResults: [GolfAppUser] = []
    @Published private(set) var games: [GolfAppGame] = []
    @Published private(set) var scoresByGameID: [UUID: [GolfAppHoleScore]] = [:]
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private let client = SupabaseGolfAppClient()

    func refresh(authSession: AuthSession?) async {
        isLoading = true
        defer { isLoading = false }

        do {
            async let friendsResult = client.fetchFriends(authSession: authSession)
            async let gamesResult = client.fetchGames(authSession: authSession)
            friends = try await friendsResult
            games = try await gamesResult
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func search(_ query: String, authSession: AuthSession?) async {
        let cleanQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard cleanQuery.count >= 2 else {
            searchResults = []
            return
        }

        do {
            searchResults = try await client.searchProfiles(query: cleanQuery, authSession: authSession)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func addFriend(_ user: GolfAppUser, authSession: AuthSession?) async {
        do {
            try await client.addFriend(user, authSession: authSession)
            searchResults = searchResults.map { result in
                guard result.id == user.id else { return result }
                var updated = result
                updated.isFriend = true
                return updated
            }
            friends = try await client.fetchFriends(authSession: authSession)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func createGame(
        name: String,
        format: String,
        selectedFriends: [GolfAppUser],
        course: CourseCatalogEntry?,
        tee: CourseTee?,
        teamAssignments: [String: String],
        teeTimeAssignments: [String: String],
        authSession: AuthSession?
    ) async -> Bool {
        do {
            try await client.createGame(
                name: name,
                format: format,
                playerIDs: selectedFriends.map(\.authUserID),
                course: course,
                tee: tee,
                teamAssignments: teamAssignments,
                teeTimeAssignments: teeTimeAssignments,
                authSession: authSession
            )
            games = try await client.fetchGames(authSession: authSession)
            errorMessage = nil
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func scores(for game: GolfAppGame) -> [GolfAppHoleScore] {
        scoresByGameID[game.id] ?? []
    }

    func refreshScores(for game: GolfAppGame, authSession: AuthSession?) async {
        do {
            scoresByGameID[game.id] = try await client.fetchScores(for: game, authSession: authSession)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func updateScore(
        game: GolfAppGame,
        player: GolfAppGame.Player,
        holeNumber: Int,
        grossScore: Int,
        authSession: AuthSession?
    ) async {
        do {
            try await client.updateScore(
                game: game,
                player: player,
                holeNumber: holeNumber,
                grossScore: grossScore,
                authSession: authSession
            )
            var currentScores = scoresByGameID[game.id] ?? []
            let updatedScore = GolfAppHoleScore(
                gameID: game.id,
                playerUserID: player.authUserID,
                holeNumber: holeNumber,
                grossScore: grossScore,
                updatedAt: Date()
            )
            if let index = currentScores.firstIndex(where: { $0.playerUserID == player.authUserID && $0.holeNumber == holeNumber }) {
                currentScores[index] = updatedScore
            } else {
                currentScores.append(updatedScore)
            }
            scoresByGameID[game.id] = currentScores
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
