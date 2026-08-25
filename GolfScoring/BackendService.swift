import Foundation

struct FamilyGolfData: Codable, Hashable {
    var profile: UserProfile
    var trips: [GolfTrip]
    var groupPlayers: [FriendProfile]
    var isSignedIn: Bool
    var hasSavedProfile: Bool
    var savedAt: Date = Date()
}

struct AuthSession: Codable, Hashable {
    var accessToken: String
    var refreshToken: String?
    var userID: String
    var email: String

    var isValid: Bool {
        !accessToken.isEmpty && !userID.isEmpty
    }
}

enum BackendChoice: String, Codable, CaseIterable {
    case localOnly
    case supabase
}

enum BackendConfiguration {
    static let groupID = "cote-family-golf-scoring"

    static var current: BackendChoice {
        SupabaseConfiguration.isConfigured ? .supabase : .localOnly
    }
}

enum SupabaseConfiguration {
    private static let missingPlaceholder = "PASTE_SUPABASE"

    static var urlString: String {
        Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String ?? ""
    }

    static var anonKey: String {
        Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String ?? ""
    }

    static var isConfigured: Bool {
        urlString.hasPrefix("https://") &&
        !urlString.contains(missingPlaceholder) &&
        anonKey.count > 20 &&
        !anonKey.contains(missingPlaceholder)
    }
}

enum CloudSyncError: LocalizedError {
    case notConfigured
    case invalidURL
    case requestFailed(Int, String)

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Supabase is not configured yet."
        case .invalidURL:
            return "The Supabase URL is invalid."
        case .requestFailed(let statusCode, let message):
            return "Cloud request failed (\(statusCode)): \(message)"
        }
    }
}

struct SupabaseAuthClient {
    private struct AuthProfileMetadata: Codable {
        var username: String?
        var firstName: String
        var lastName: String
        var handicapIndex: Double
        var playerKey: String?
        var profileType: ProfileType

        enum CodingKeys: String, CodingKey {
            case username
            case firstName = "first_name"
            case lastName = "last_name"
            case handicapIndex = "handicap_index"
            case playerKey = "player_key"
            case profileType = "profile_type"
        }
    }

    private struct SignUpBody: Codable {
        var email: String
        var password: String
        var data: AuthProfileMetadata
    }

    private struct SignInBody: Codable {
        var email: String
        var password: String
    }

    private struct UsernameLookupBody: Codable {
        var pUsername: String

        enum CodingKeys: String, CodingKey {
            case pUsername = "p_username"
        }
    }

    private struct UsernameLookupRow: Codable {
        var email: String
    }

    private struct UpsertAppUserProfileBody: Codable {
        var pAuthUserId: String
        var pUsername: String
        var pEmail: String
        var pFirstName: String
        var pLastName: String
        var pHandicapIndex: Double
        var pPlayerKey: String?
        var pProfileType: ProfileType

        enum CodingKeys: String, CodingKey {
            case pAuthUserId = "p_auth_user_id"
            case pUsername = "p_username"
            case pEmail = "p_email"
            case pFirstName = "p_first_name"
            case pLastName = "p_last_name"
            case pHandicapIndex = "p_handicap_index"
            case pPlayerKey = "p_player_key"
            case pProfileType = "p_profile_type"
        }
    }

    private struct AuthUser: Codable {
        var id: String
        var email: String?
        var userMetadata: AuthProfileMetadata?

        enum CodingKeys: String, CodingKey {
            case id
            case email
            case userMetadata = "user_metadata"
        }
    }

    private struct AuthResponse: Codable {
        var accessToken: String?
        var refreshToken: String?
        var user: AuthUser

        enum CodingKeys: String, CodingKey {
            case accessToken = "access_token"
            case refreshToken = "refresh_token"
            case user
        }
    }

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func signUp(profile: UserProfile, password: String) async throws -> (UserProfile, AuthSession?) {
        guard SupabaseConfiguration.isConfigured else { throw CloudSyncError.notConfigured }
        guard let url = URL(string: "\(SupabaseConfiguration.urlString)/auth/v1/signup") else {
            throw CloudSyncError.invalidURL
        }

        let metadata = AuthProfileMetadata(
            username: profile.username,
            firstName: profile.firstName,
            lastName: profile.lastName,
            handicapIndex: profile.handicapIndex ?? 0,
            playerKey: profile.playerKey,
            profileType: profile.profileType
        )
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        addHeaders(to: &request)
        request.httpBody = try JSONEncoder.cloud.encode(SignUpBody(email: profile.email, password: password, data: metadata))

        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)
        let authResponse = try JSONDecoder.cloud.decode(AuthResponse.self, from: data)
        let result = profileAndSession(from: authResponse, fallbackProfile: profile)
        if let authSession = result.1 {
            try await upsertAppUserProfile(result.0, authSession: authSession)
        }
        return result
    }

    func signIn(loginIdentifier: String, password: String) async throws -> (UserProfile, AuthSession) {
        guard SupabaseConfiguration.isConfigured else { throw CloudSyncError.notConfigured }
        let email = try await resolvedEmail(for: loginIdentifier)
        guard let url = URL(string: "\(SupabaseConfiguration.urlString)/auth/v1/token?grant_type=password") else {
            throw CloudSyncError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        addHeaders(to: &request)
        request.httpBody = try JSONEncoder.cloud.encode(SignInBody(email: email, password: password))

        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)
        let authResponse = try JSONDecoder.cloud.decode(AuthResponse.self, from: data)
        let result = profileAndSession(from: authResponse, fallbackProfile: UserProfile(email: email))
        guard let authSession = result.1 else {
            throw CloudSyncError.requestFailed(401, "Login succeeded but no auth session was returned.")
        }
        return (result.0, authSession)
    }

    private func resolvedEmail(for loginIdentifier: String) async throws -> String {
        let cleanIdentifier = loginIdentifier.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !cleanIdentifier.isEmpty else {
            throw CloudSyncError.requestFailed(400, "Enter your email or username.")
        }
        if cleanIdentifier.contains("@") {
            return cleanIdentifier
        }

        guard let url = URL(string: "\(SupabaseConfiguration.urlString)/rest/v1/rpc/get_auth_email_for_username") else {
            throw CloudSyncError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        addHeaders(to: &request)
        request.httpBody = try JSONEncoder.cloud.encode(UsernameLookupBody(pUsername: cleanIdentifier))

        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)

        if let email = try? JSONDecoder.cloud.decode(String.self, from: data) {
            return email
        }
        if let row = try? JSONDecoder.cloud.decode(UsernameLookupRow.self, from: data) {
            return row.email
        }
        throw CloudSyncError.requestFailed(404, "No account exists for username \(cleanIdentifier).")
    }

    private func profileAndSession(from response: AuthResponse, fallbackProfile: UserProfile) -> (UserProfile, AuthSession?) {
        var profile = fallbackProfile
        profile.email = response.user.email ?? fallbackProfile.email
        if let metadata = response.user.userMetadata {
            profile.username = metadata.username ?? fallbackProfile.username
            profile.firstName = metadata.firstName
            profile.lastName = metadata.lastName
            profile.handicapIndex = metadata.handicapIndex
            profile.playerKey = metadata.playerKey
            profile.profileType = metadata.profileType
        }

        let authSession = response.accessToken.map {
            AuthSession(
                accessToken: $0,
                refreshToken: response.refreshToken,
                userID: response.user.id,
                email: response.user.email ?? profile.email
            )
        }
        return (profile, authSession)
    }

    private func upsertAppUserProfile(_ profile: UserProfile, authSession: AuthSession) async throws {
        guard !profile.username.isEmpty else { return }
        guard let url = URL(string: "\(SupabaseConfiguration.urlString)/rest/v1/rpc/upsert_app_user_profile") else {
            throw CloudSyncError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        addHeaders(to: &request, bearerToken: authSession.accessToken)
        request.setValue("return=minimal", forHTTPHeaderField: "Prefer")
        request.httpBody = try JSONEncoder.cloud.encode(
            UpsertAppUserProfileBody(
                pAuthUserId: authSession.userID,
                pUsername: profile.username,
                pEmail: profile.email,
                pFirstName: profile.firstName,
                pLastName: profile.lastName,
                pHandicapIndex: profile.handicapIndex ?? 0,
                pPlayerKey: profile.playerKey,
                pProfileType: profile.profileType
            )
        )

        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)
    }

    private func addHeaders(to request: inout URLRequest, bearerToken: String? = nil) {
        request.setValue(SupabaseConfiguration.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(bearerToken ?? SupabaseConfiguration.anonKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    }

    private func validate(response: URLResponse, data: Data) throws {
        guard let httpResponse = response as? HTTPURLResponse else { return }
        guard (200..<300).contains(httpResponse.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw CloudSyncError.requestFailed(httpResponse.statusCode, message)
        }
    }
}

struct SupabaseFamilyGolfClient {
    private struct FamilyGolfVersionRow: Codable {
        var updatedAt: Date?

        enum CodingKeys: String, CodingKey {
            case updatedAt = "updated_at"
        }
    }

    private struct FetchFamilyGolfBody: Codable {
        var pGroupId: String

        enum CodingKeys: String, CodingKey {
            case pGroupId = "p_group_id"
        }
    }

    private struct UpsertPlayersBody: Codable {
        var pGroupId: String
        var pActorKey: String?
        var pActorName: String?
        var pPlayers: [FriendProfile]

        enum CodingKeys: String, CodingKey {
            case pGroupId = "p_group_id"
            case pActorKey = "p_actor_key"
            case pActorName = "p_actor_name"
            case pPlayers = "p_players"
        }
    }

    private struct UpsertTripBody: Codable {
        var pGroupId: String
        var pActorKey: String?
        var pActorName: String?
        var pTripId: UUID
        var pTripName: String
        var pTripDate: Date

        enum CodingKeys: String, CodingKey {
            case pGroupId = "p_group_id"
            case pActorKey = "p_actor_key"
            case pActorName = "p_actor_name"
            case pTripId = "p_trip_id"
            case pTripName = "p_trip_name"
            case pTripDate = "p_trip_date"
        }
    }

    private struct UpsertRoundBody: Codable {
        var pGroupId: String
        var pActorKey: String?
        var pActorName: String?
        var pTripId: UUID
        var pTripName: String
        var pTripDate: Date
        var pRound: RoundSummary

        enum CodingKeys: String, CodingKey {
            case pGroupId = "p_group_id"
            case pActorKey = "p_actor_key"
            case pActorName = "p_actor_name"
            case pTripId = "p_trip_id"
            case pTripName = "p_trip_name"
            case pTripDate = "p_trip_date"
            case pRound = "p_round"
        }
    }

    private struct DeleteRoundBody: Codable {
        var pGroupId: String
        var pActorKey: String?
        var pActorName: String?
        var pRoundId: UUID

        enum CodingKeys: String, CodingKey {
            case pGroupId = "p_group_id"
            case pActorKey = "p_actor_key"
            case pActorName = "p_actor_name"
            case pRoundId = "p_round_id"
        }
    }

    private struct DeleteTripBody: Codable {
        var pGroupId: String
        var pActorKey: String?
        var pActorName: String?
        var pTripId: UUID

        enum CodingKeys: String, CodingKey {
            case pGroupId = "p_group_id"
            case pActorKey = "p_actor_key"
            case pActorName = "p_actor_name"
            case pTripId = "p_trip_id"
        }
    }

    private struct UpdateCompletedHoleScoresBody: Codable {
        var pGroupId: String
        var pActorKey: String?
        var pActorName: String?
        var pRoundId: UUID
        var pHole: HoleSummary
        var pRoundPlayers: [PlayerRoundSummary]
        var pTeamResult: String

        enum CodingKeys: String, CodingKey {
            case pGroupId = "p_group_id"
            case pActorKey = "p_actor_key"
            case pActorName = "p_actor_name"
            case pRoundId = "p_round_id"
            case pHole = "p_hole"
            case pRoundPlayers = "p_round_players"
            case pTeamResult = "p_team_result"
        }
    }

    private let photoClient = SupabaseProfilePhotoClient()
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetchFamilyGolfData() async throws -> FamilyGolfData? {
        guard SupabaseConfiguration.isConfigured else { throw CloudSyncError.notConfigured }
        guard let url = URL(string: "\(SupabaseConfiguration.urlString)/rest/v1/rpc/get_family_golf_data") else {
            throw CloudSyncError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        addHeaders(to: &request)
        request.httpBody = try JSONEncoder.cloud.encode(FetchFamilyGolfBody(pGroupId: BackendConfiguration.groupID))

        let (responseData, response) = try await session.data(for: request)
        try validate(response: response, data: responseData)
        let familyData = try JSONDecoder.cloud.decode(FamilyGolfData.self, from: responseData)
        return await photoClient.hydrateProfileImages(in: familyData)
    }

    func fetchFamilyGolfUpdatedAt() async throws -> Date? {
        guard SupabaseConfiguration.isConfigured else { throw CloudSyncError.notConfigured }
        guard var components = URLComponents(string: "\(SupabaseConfiguration.urlString)/rest/v1/family_golf_last_updated") else {
            throw CloudSyncError.invalidURL
        }

        components.queryItems = [
            URLQueryItem(name: "select", value: "updated_at")
        ]

        guard let url = components.url else { throw CloudSyncError.invalidURL }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        addHeaders(to: &request)

        let (responseData, response) = try await session.data(for: request)
        try validate(response: response, data: responseData)
        return try JSONDecoder.cloud.decode([FamilyGolfVersionRow].self, from: responseData).first?.updatedAt
    }

    func upsertGroupPlayers(_ players: [FriendProfile], actor: UserProfile) async throws {
        guard SupabaseConfiguration.isConfigured else { throw CloudSyncError.notConfigured }
        guard let url = URL(string: "\(SupabaseConfiguration.urlString)/rest/v1/rpc/upsert_family_golf_players") else {
            throw CloudSyncError.invalidURL
        }

        let familyData = FamilyGolfData(
            profile: actor,
            trips: [],
            groupPlayers: players,
            isSignedIn: true,
            hasSavedProfile: true
        )
        let uploadedData = try await photoClient.uploadProfileImages(from: familyData)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        addHeaders(to: &request)
        request.setValue("return=minimal", forHTTPHeaderField: "Prefer")
        request.httpBody = try JSONEncoder.cloud.encode(
            UpsertPlayersBody(
                pGroupId: BackendConfiguration.groupID,
                pActorKey: actor.playerKey,
                pActorName: actor.fullName.isEmpty ? nil : actor.fullName,
                pPlayers: uploadedData.groupPlayers.map { player in
                    var stripped = player
                    stripped.profileImageData = nil
                    return stripped
                }
            )
        )

        let (responseData, response) = try await session.data(for: request)
        try validate(response: response, data: responseData)
    }

    func upsertTrip(_ trip: GolfTrip, actor: UserProfile) async throws {
        guard SupabaseConfiguration.isConfigured else { throw CloudSyncError.notConfigured }
        guard let url = URL(string: "\(SupabaseConfiguration.urlString)/rest/v1/rpc/upsert_family_golf_trip") else {
            throw CloudSyncError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        addHeaders(to: &request)
        request.setValue("return=minimal", forHTTPHeaderField: "Prefer")
        request.httpBody = try JSONEncoder.cloud.encode(
            UpsertTripBody(
                pGroupId: BackendConfiguration.groupID,
                pActorKey: actor.playerKey,
                pActorName: actor.fullName.isEmpty ? nil : actor.fullName,
                pTripId: trip.id,
                pTripName: trip.name,
                pTripDate: trip.date
            )
        )

        let (responseData, response) = try await session.data(for: request)
        try validate(response: response, data: responseData)
    }

    func upsertRound(_ round: RoundSummary, in trip: GolfTrip, actor: UserProfile) async throws {
        guard SupabaseConfiguration.isConfigured else { throw CloudSyncError.notConfigured }
        guard let url = URL(string: "\(SupabaseConfiguration.urlString)/rest/v1/rpc/upsert_family_golf_round") else {
            throw CloudSyncError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        addHeaders(to: &request)
        request.setValue("return=minimal", forHTTPHeaderField: "Prefer")
        request.httpBody = try JSONEncoder.cloud.encode(
            UpsertRoundBody(
                pGroupId: BackendConfiguration.groupID,
                pActorKey: actor.playerKey,
                pActorName: actor.fullName.isEmpty ? nil : actor.fullName,
                pTripId: trip.id,
                pTripName: trip.name,
                pTripDate: trip.date,
                pRound: round
            )
        )

        let (responseData, response) = try await session.data(for: request)
        try validate(response: response, data: responseData)
    }

    func deleteRound(_ roundID: UUID, actor: UserProfile) async throws {
        guard SupabaseConfiguration.isConfigured else { throw CloudSyncError.notConfigured }
        guard let url = URL(string: "\(SupabaseConfiguration.urlString)/rest/v1/rpc/delete_family_golf_round") else {
            throw CloudSyncError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        addHeaders(to: &request)
        request.setValue("return=minimal", forHTTPHeaderField: "Prefer")
        request.httpBody = try JSONEncoder.cloud.encode(
            DeleteRoundBody(
                pGroupId: BackendConfiguration.groupID,
                pActorKey: actor.playerKey,
                pActorName: actor.fullName.isEmpty ? nil : actor.fullName,
                pRoundId: roundID
            )
        )

        let (responseData, response) = try await session.data(for: request)
        try validate(response: response, data: responseData)
    }

    func deleteTrip(_ tripID: UUID, actor: UserProfile) async throws {
        guard SupabaseConfiguration.isConfigured else { throw CloudSyncError.notConfigured }
        guard let url = URL(string: "\(SupabaseConfiguration.urlString)/rest/v1/rpc/delete_family_golf_trip") else {
            throw CloudSyncError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        addHeaders(to: &request)
        request.setValue("return=minimal", forHTTPHeaderField: "Prefer")
        request.httpBody = try JSONEncoder.cloud.encode(
            DeleteTripBody(
                pGroupId: BackendConfiguration.groupID,
                pActorKey: actor.playerKey,
                pActorName: actor.fullName.isEmpty ? nil : actor.fullName,
                pTripId: tripID
            )
        )

        let (responseData, response) = try await session.data(for: request)
        try validate(response: response, data: responseData)
    }

    func updateCompletedHoleScores(round: RoundSummary, holeNumber: Int, actor: UserProfile) async throws {
        guard SupabaseConfiguration.isConfigured else { throw CloudSyncError.notConfigured }
        guard let hole = round.holes.first(where: { $0.number == holeNumber }) else { return }
        guard let url = URL(string: "\(SupabaseConfiguration.urlString)/rest/v1/rpc/update_family_golf_completed_hole_scores") else {
            throw CloudSyncError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        addHeaders(to: &request)
        request.setValue("return=minimal", forHTTPHeaderField: "Prefer")
        request.httpBody = try JSONEncoder.cloud.encode(
            UpdateCompletedHoleScoresBody(
                pGroupId: BackendConfiguration.groupID,
                pActorKey: actor.playerKey,
                pActorName: actor.fullName.isEmpty ? nil : actor.fullName,
                pRoundId: round.id,
                pHole: hole,
                pRoundPlayers: round.players,
                pTeamResult: round.teamResult
            )
        )

        let (responseData, response) = try await session.data(for: request)
        try validate(response: response, data: responseData)
    }

    private func addHeaders(to request: inout URLRequest) {
        request.setValue(SupabaseConfiguration.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(SupabaseConfiguration.anonKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    }

    private func validate(response: URLResponse, data: Data) throws {
        guard let httpResponse = response as? HTTPURLResponse else { return }
        guard (200..<300).contains(httpResponse.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw CloudSyncError.requestFailed(httpResponse.statusCode, message)
        }
    }
}

struct SupabaseGolfAppClient {
    private struct SearchProfilesBody: Codable {
        var pQuery: String

        enum CodingKeys: String, CodingKey {
            case pQuery = "p_query"
        }
    }

    private struct AddFriendBody: Codable {
        var pFriendUserID: String

        enum CodingKeys: String, CodingKey {
            case pFriendUserID = "p_friend_user_id"
        }
    }

    private struct CreateGameBody: Codable {
        var pName: String
        var pFormat: String
        var pPlayerIDs: [String]
        var pCourseName: String?
        var pCourseLocation: String?
        var pTeeName: String?
        var pCourseSetup: [String: String]
        var pTeamAssignments: [String: String]
        var pTeeTimeAssignments: [String: String]

        enum CodingKeys: String, CodingKey {
            case pName = "p_name"
            case pFormat = "p_format"
            case pPlayerIDs = "p_player_ids"
            case pCourseName = "p_course_name"
            case pCourseLocation = "p_course_location"
            case pTeeName = "p_tee_name"
            case pCourseSetup = "p_course_setup"
            case pTeamAssignments = "p_team_assignments"
            case pTeeTimeAssignments = "p_tee_time_assignments"
        }
    }

    private struct FetchGameScoresBody: Codable {
        var pGameID: UUID

        enum CodingKeys: String, CodingKey {
            case pGameID = "p_game_id"
        }
    }

    private struct UpsertHoleScoreBody: Codable {
        var pGameID: UUID
        var pPlayerUserID: String
        var pHoleNumber: Int
        var pGrossScore: Int

        enum CodingKeys: String, CodingKey {
            case pGameID = "p_game_id"
            case pPlayerUserID = "p_player_user_id"
            case pHoleNumber = "p_hole_number"
            case pGrossScore = "p_gross_score"
        }
    }

    private struct UserRow: Codable {
        var authUserID: String
        var username: String?
        var email: String?
        var firstName: String?
        var lastName: String?
        var handicapIndex: Double?
        var playerKey: String?
        var profileType: ProfileType?
        var isFriend: Bool?

        enum CodingKeys: String, CodingKey {
            case authUserID = "auth_user_id"
            case username
            case email
            case firstName = "first_name"
            case lastName = "last_name"
            case handicapIndex = "handicap_index"
            case playerKey = "player_key"
            case profileType = "profile_type"
            case isFriend = "is_friend"
        }

        var user: GolfAppUser {
            GolfAppUser(
                authUserID: authUserID,
                username: username ?? "",
                email: email ?? "",
                firstName: firstName ?? "",
                lastName: lastName ?? "",
                handicapIndex: handicapIndex,
                playerKey: playerKey,
                profileType: profileType ?? .general,
                isFriend: isFriend ?? false
            )
        }
    }

    private struct GamePlayerRow: Codable {
        var authUserID: String
        var displayName: String
        var username: String?
        var handicapIndex: Double?
        var teamName: String?
        var teeTimeGroup: String?

        enum CodingKeys: String, CodingKey {
            case authUserID = "auth_user_id"
            case displayName = "display_name"
            case username
            case handicapIndex = "handicap_index"
            case teamName = "team_name"
            case teeTimeGroup = "tee_time_group"
        }

        var player: GolfAppGame.Player {
            GolfAppGame.Player(
                authUserID: authUserID,
                displayName: displayName,
                username: username,
                handicapIndex: handicapIndex,
                teamName: teamName,
                teeTimeGroup: teeTimeGroup
            )
        }
    }

    private struct GameRow: Codable {
        var id: UUID
        var name: String
        var format: String
        var status: String
        var createdAt: Date
        var courseName: String?
        var courseLocation: String?
        var teeName: String?
        var players: [GamePlayerRow]

        enum CodingKeys: String, CodingKey {
            case id
            case name
            case format
            case status
            case createdAt = "created_at"
            case courseName = "course_name"
            case courseLocation = "course_location"
            case teeName = "tee_name"
            case players
        }

        var game: GolfAppGame {
            GolfAppGame(
                id: id,
                name: name,
                format: format,
                status: status,
                createdAt: createdAt,
                courseName: courseName,
                courseLocation: courseLocation,
                teeName: teeName,
                players: players.map(\.player)
            )
        }
    }

    private struct HoleScoreRow: Codable {
        var gameID: UUID
        var playerUserID: String
        var holeNumber: Int
        var grossScore: Int
        var updatedAt: Date?

        enum CodingKeys: String, CodingKey {
            case gameID = "game_id"
            case playerUserID = "player_user_id"
            case holeNumber = "hole_number"
            case grossScore = "gross_score"
            case updatedAt = "updated_at"
        }

        var score: GolfAppHoleScore {
            GolfAppHoleScore(
                gameID: gameID,
                playerUserID: playerUserID,
                holeNumber: holeNumber,
                grossScore: grossScore,
                updatedAt: updatedAt
            )
        }
    }

    func searchProfiles(query: String, authSession: AuthSession?) async throws -> [GolfAppUser] {
        guard let authSession, authSession.isValid else { return [] }
        return try await postRPC(
            "search_golf_app_profiles",
            body: SearchProfilesBody(pQuery: query),
            authSession: authSession,
            decode: [UserRow].self
        ).map(\.user)
    }

    func fetchFriends(authSession: AuthSession?) async throws -> [GolfAppUser] {
        guard let authSession, authSession.isValid else { return [] }
        return try await postRPC(
            "get_golf_app_friends",
            body: EmptyBody(),
            authSession: authSession,
            decode: [UserRow].self
        ).map(\.user)
    }

    func addFriend(_ user: GolfAppUser, authSession: AuthSession?) async throws {
        guard let authSession, authSession.isValid else { return }
        _ = try await postRPC(
            "add_golf_app_friend",
            body: AddFriendBody(pFriendUserID: user.authUserID),
            authSession: authSession,
            decode: EmptyResponse.self
        )
    }

    func fetchGames(authSession: AuthSession?) async throws -> [GolfAppGame] {
        guard let authSession, authSession.isValid else { return [] }
        return try await postRPC(
            "get_golf_app_games",
            body: EmptyBody(),
            authSession: authSession,
            decode: [GameRow].self
        ).map(\.game)
    }

    func createGame(
        name: String,
        format: String,
        playerIDs: [String],
        course: CourseCatalogEntry?,
        tee: CourseTee?,
        teamAssignments: [String: String],
        teeTimeAssignments: [String: String],
        authSession: AuthSession?
    ) async throws {
        guard let authSession, authSession.isValid else { return }
        _ = try await postRPC(
            "create_golf_app_game",
            body: CreateGameBody(
                pName: name,
                pFormat: format,
                pPlayerIDs: playerIDs,
                pCourseName: course?.name,
                pCourseLocation: course?.location,
                pTeeName: tee?.name,
                pCourseSetup: tee.map {
                    [
                        "tee_name": $0.name,
                        "yardage": "\($0.yardage)",
                        "rating": "\($0.rating)",
                        "slope": "\($0.slope)",
                        "par": "\($0.par)"
                    ]
                } ?? [:],
                pTeamAssignments: teamAssignments,
                pTeeTimeAssignments: teeTimeAssignments
            ),
            authSession: authSession,
            decode: UUID.self
        )
    }

    func fetchScores(for game: GolfAppGame, authSession: AuthSession?) async throws -> [GolfAppHoleScore] {
        guard let authSession, authSession.isValid else { return [] }
        return try await postRPC(
            "get_golf_app_game_scores",
            body: FetchGameScoresBody(pGameID: game.id),
            authSession: authSession,
            decode: [HoleScoreRow].self
        ).map(\.score)
    }

    func updateScore(
        game: GolfAppGame,
        player: GolfAppGame.Player,
        holeNumber: Int,
        grossScore: Int,
        authSession: AuthSession?
    ) async throws {
        guard let authSession, authSession.isValid else { return }
        _ = try await postRPC(
            "upsert_golf_app_hole_score",
            body: UpsertHoleScoreBody(
                pGameID: game.id,
                pPlayerUserID: player.authUserID,
                pHoleNumber: holeNumber,
                pGrossScore: grossScore
            ),
            authSession: authSession,
            decode: EmptyResponse.self
        )
    }

    private struct EmptyBody: Codable {}
    private struct EmptyResponse: Codable {}

    private func postRPC<Body: Encodable, Response: Decodable>(
        _ functionName: String,
        body: Body,
        authSession: AuthSession,
        decode type: Response.Type
    ) async throws -> Response {
        guard SupabaseConfiguration.isConfigured else { throw CloudSyncError.notConfigured }
        guard let url = URL(string: "\(SupabaseConfiguration.urlString)/rest/v1/rpc/\(functionName)") else {
            throw CloudSyncError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(SupabaseConfiguration.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(authSession.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder.cloud.encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw CloudSyncError.invalidURL
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw CloudSyncError.requestFailed(httpResponse.statusCode, String(data: data, encoding: .utf8) ?? "Unknown error")
        }
        if Response.self == EmptyResponse.self {
            return EmptyResponse() as! Response
        }
        return try JSONDecoder.cloud.decode(Response.self, from: data)
    }
}

struct SupabaseProfilePhotoClient {
    private struct ProfilePhotoRow: Codable {
        var pGroupId: String
        var pPlayerKey: String
        var pObjectPath: String
        var pPublicURL: String
        var pContentType: String
        var pByteSize: Int
        var pActorKey: String?
        var pActorName: String?

        enum CodingKeys: String, CodingKey {
            case pGroupId = "p_group_id"
            case pPlayerKey = "p_player_key"
            case pObjectPath = "p_object_path"
            case pPublicURL = "p_public_url"
            case pContentType = "p_content_type"
            case pByteSize = "p_byte_size"
            case pActorKey = "p_actor_key"
            case pActorName = "p_actor_name"
        }
    }

    private struct DeleteProfilePhotoBody: Codable {
        var pGroupId: String
        var pPlayerKey: String
        var pActorKey: String?
        var pActorName: String?

        enum CodingKeys: String, CodingKey {
            case pGroupId = "p_group_id"
            case pPlayerKey = "p_player_key"
            case pActorKey = "p_actor_key"
            case pActorName = "p_actor_name"
        }
    }

    private struct ProfilePhotoStorageRow: Codable {
        var dataId: String
        var playerKey: String
        var bucketId: String
        var objectPath: String
        var publicURL: String
        var contentType: String
        var byteSize: Int
        var uploadedByKey: String?
        var uploadedByName: String?

        enum CodingKeys: String, CodingKey {
            case dataId = "data_id"
            case playerKey = "player_key"
            case bucketId = "bucket_id"
            case objectPath = "object_path"
            case publicURL = "public_url"
            case contentType = "content_type"
            case byteSize = "byte_size"
            case uploadedByKey = "uploaded_by_key"
            case uploadedByName = "uploaded_by_name"
        }
    }

    private let session: URLSession
    private let bucketID = "profile-photos"

    init(session: URLSession = .shared) {
        self.session = session
    }

    func uploadProfileImages(from data: FamilyGolfData) async throws -> FamilyGolfData {
        guard SupabaseConfiguration.isConfigured else { return data }
        var updatedData = data

        for index in updatedData.groupPlayers.indices {
            guard
                let imageData = updatedData.groupPlayers[index].profileImageData,
                let playerKey = updatedData.groupPlayers[index].playerKey,
                !playerKey.isEmpty
            else { continue }

            let path = "\(playerKey)/profile.jpg"
            let publicURL = try await uploadProfileImage(
                imageData,
                path: path,
                playerKey: playerKey,
                actorKey: data.profile.playerKey,
                actorName: data.profile.fullName.isEmpty ? nil : data.profile.fullName
            )
            updatedData.groupPlayers[index].profileImagePath = path
            updatedData.groupPlayers[index].profileImageURL = publicURL

            if updatedData.profile.playerKey == playerKey {
                updatedData.profile.profileImagePath = path
                updatedData.profile.profileImageURL = publicURL
            }
        }

        return updatedData
    }

    func hydrateProfileImages(in data: FamilyGolfData) async -> FamilyGolfData {
        guard SupabaseConfiguration.isConfigured else { return data }
        var hydratedData = data

        for index in hydratedData.groupPlayers.indices {
            guard hydratedData.groupPlayers[index].profileImageData == nil else { continue }
            guard let publicURL = hydratedData.groupPlayers[index].profileImageURL else { continue }
            hydratedData.groupPlayers[index].profileImageData = await downloadImageData(from: publicURL)
        }

        if let playerKey = hydratedData.profile.playerKey,
           let matchingPlayer = hydratedData.groupPlayers.first(where: { $0.playerKey == playerKey }) {
            hydratedData.profile.profileImagePath = matchingPlayer.profileImagePath
            hydratedData.profile.profileImageURL = matchingPlayer.profileImageURL
            hydratedData.profile.profileImageData = matchingPlayer.profileImageData
        }

        return hydratedData
    }

    func deleteProfilePhoto(playerKey: String, actorKey: String?, actorName: String?) async throws {
        guard SupabaseConfiguration.isConfigured else { return }
        let path = "\(playerKey)/profile.jpg"

        if let encodedPath = path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
           let objectURL = URL(string: "\(SupabaseConfiguration.urlString)/storage/v1/object/\(bucketID)/\(encodedPath)") {
            var deleteObjectRequest = URLRequest(url: objectURL)
            deleteObjectRequest.httpMethod = "DELETE"
            addHeaders(to: &deleteObjectRequest)
            let (objectData, objectResponse) = try await session.data(for: deleteObjectRequest)
            try validate(objectResponse, data: objectData, allowingNotFound: true)
        }

        guard let metadataURL = URL(string: "\(SupabaseConfiguration.urlString)/rest/v1/rpc/delete_profile_photo_metadata") else {
            throw CloudSyncError.invalidURL
        }
        var metadataRequest = URLRequest(url: metadataURL)
        metadataRequest.httpMethod = "POST"
        addHeaders(to: &metadataRequest)
        metadataRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        metadataRequest.httpBody = try JSONEncoder.cloud.encode(
            DeleteProfilePhotoBody(
                pGroupId: BackendConfiguration.groupID,
                pPlayerKey: playerKey,
                pActorKey: actorKey,
                pActorName: actorName
            )
        )

        let (metadataData, metadataResponse) = try await session.data(for: metadataRequest)
        try validate(metadataResponse, data: metadataData, allowingNotFound: true)
    }

    private func uploadProfileImage(
        _ data: Data,
        path: String,
        playerKey: String,
        actorKey: String?,
        actorName: String?
    ) async throws -> String {
        guard let encodedPath = path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              let uploadURL = URL(string: "\(SupabaseConfiguration.urlString)/storage/v1/object/\(bucketID)/\(encodedPath)") else {
            throw CloudSyncError.invalidURL
        }

        var uploadRequest = URLRequest(url: uploadURL)
        uploadRequest.httpMethod = "POST"
        addHeaders(to: &uploadRequest)
        uploadRequest.setValue("image/jpeg", forHTTPHeaderField: "Content-Type")
        uploadRequest.setValue("true", forHTTPHeaderField: "x-upsert")
        uploadRequest.httpBody = data

        let (uploadResponseData, uploadResponse) = try await session.data(for: uploadRequest)
        try validate(uploadResponse, data: uploadResponseData)

        let publicURL = "\(SupabaseConfiguration.urlString)/storage/v1/object/public/\(bucketID)/\(encodedPath)"
        try await upsertProfilePhotoMetadata(
            playerKey: playerKey,
            path: path,
            publicURL: publicURL,
            byteSize: data.count,
            actorKey: actorKey,
            actorName: actorName
        )
        return publicURL
    }

    private func upsertProfilePhotoMetadata(
        playerKey: String,
        path: String,
        publicURL: String,
        byteSize: Int,
        actorKey: String?,
        actorName: String?
    ) async throws {
        guard let metadataURL = URL(string: "\(SupabaseConfiguration.urlString)/rest/v1/rpc/upsert_profile_photo_metadata") else {
            throw CloudSyncError.invalidURL
        }

        let row = ProfilePhotoRow(
            pGroupId: BackendConfiguration.groupID,
            pPlayerKey: playerKey,
            pObjectPath: path,
            pPublicURL: publicURL,
            pContentType: "image/jpeg",
            pByteSize: byteSize,
            pActorKey: actorKey,
            pActorName: actorName
        )

        var request = URLRequest(url: metadataURL)
        request.httpMethod = "POST"
        addHeaders(to: &request)
        request.setValue("return=minimal", forHTTPHeaderField: "Prefer")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder.cloud.encode(row)

        let (data, response) = try await session.data(for: request)
        try validate(response, data: data)
    }

    private func downloadImageData(from publicURL: String) async -> Data? {
        guard let url = URL(string: publicURL) else { return nil }
        do {
            let (data, response) = try await session.data(from: url)
            try validate(response, data: data)
            return data
        } catch {
            return nil
        }
    }

    private func addHeaders(to request: inout URLRequest) {
        request.setValue(SupabaseConfiguration.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(SupabaseConfiguration.anonKey)", forHTTPHeaderField: "Authorization")
    }

    private func validate(_ response: URLResponse, data: Data, allowingNotFound: Bool = false) throws {
        guard let httpResponse = response as? HTTPURLResponse else { return }
        if allowingNotFound, httpResponse.statusCode == 404 { return }
        guard (200..<300).contains(httpResponse.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw CloudSyncError.requestFailed(httpResponse.statusCode, message)
        }
    }
}

extension JSONEncoder {
    static var cloud: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

extension JSONDecoder {
    static var cloud: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
