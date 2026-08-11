import Foundation

struct AppSnapshot: Codable, Hashable {
    var profile: UserProfile
    var trips: [GolfTrip]
    var groupPlayers: [FriendProfile]
    var isSignedIn: Bool
    var hasSavedProfile: Bool
    var savedAt: Date = Date()
}

enum BackendChoice: String, Codable, CaseIterable {
    case localOnly
    case supabase
}

enum BackendConfiguration {
    static let snapshotID = "cote-family-golf-scoring"

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

struct SupabaseSnapshotClient {
    private struct SnapshotRow: Codable {
        var id: String
        var payload: AppSnapshot
        var updatedAt: Date?

        enum CodingKeys: String, CodingKey {
            case id
            case payload
            case updatedAt = "updated_at"
        }
    }

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetchSnapshot() async throws -> AppSnapshot? {
        guard SupabaseConfiguration.isConfigured else { throw CloudSyncError.notConfigured }
        guard var components = URLComponents(string: "\(SupabaseConfiguration.urlString)/rest/v1/app_snapshots") else {
            throw CloudSyncError.invalidURL
        }

        components.queryItems = [
            URLQueryItem(name: "id", value: "eq.\(BackendConfiguration.snapshotID)"),
            URLQueryItem(name: "select", value: "id,payload,updated_at")
        ]

        guard let url = components.url else { throw CloudSyncError.invalidURL }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        addHeaders(to: &request)

        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)
        return try JSONDecoder.cloud.decode([SnapshotRow].self, from: data).first?.payload
    }

    func upsertSnapshot(_ snapshot: AppSnapshot) async throws {
        guard SupabaseConfiguration.isConfigured else { throw CloudSyncError.notConfigured }
        guard let url = URL(string: "\(SupabaseConfiguration.urlString)/rest/v1/app_snapshots") else {
            throw CloudSyncError.invalidURL
        }

        let row = SnapshotRow(id: BackendConfiguration.snapshotID, payload: snapshot, updatedAt: nil)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        addHeaders(to: &request)
        request.setValue("resolution=merge-duplicates,return=minimal", forHTTPHeaderField: "Prefer")
        request.httpBody = try JSONEncoder.cloud.encode(row)

        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)
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
