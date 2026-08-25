import Foundation

@MainActor
final class CloudSyncStore: ObservableObject {
    enum SyncState: Equatable {
        case localOnly
        case idle
        case syncing
        case synced(Date)
        case failed(String)

        var title: String {
            switch self {
            case .localOnly:
                return "Local Only"
            case .idle:
                return "Cloud Ready"
            case .syncing:
                return "Syncing"
            case .synced:
                return "Synced"
            case .failed:
                return "Sync Issue"
            }
        }

        var detail: String {
            switch self {
            case .localOnly:
                return "Supabase is not configured yet. Scores save on this phone."
            case .idle:
                return "Cloud is configured and ready."
            case .syncing:
                return "Updating shared golf data."
            case .synced(let date):
                return "Last synced \(date.formatted(.dateTime.hour().minute()))."
            case .failed(let message):
                return message
            }
        }
    }

    @Published private(set) var state: SyncState = SupabaseConfiguration.isConfigured ? .idle : .localOnly

    private let client = SupabaseFamilyGolfClient()
    private var lastKnownCloudUpdatedAt: Date?

    var isConfigured: Bool {
        SupabaseConfiguration.isConfigured
    }

    func fetchCloudData() async -> FamilyGolfData? {
        guard isConfigured else {
            state = .localOnly
            return nil
        }

        state = .syncing
        do {
            let data = try await client.fetchFamilyGolfData()
            lastKnownCloudUpdatedAt = data?.savedAt
            state = .synced(Date())
            return data
        } catch {
            state = .failed(error.localizedDescription)
            return nil
        }
    }

    func fetchCloudDataIfChanged() async -> FamilyGolfData? {
        guard isConfigured else {
            state = .localOnly
            return nil
        }

        do {
            let cloudUpdatedAt = try await client.fetchFamilyGolfUpdatedAt()
            guard cloudUpdatedAt != lastKnownCloudUpdatedAt else { return nil }
            lastKnownCloudUpdatedAt = cloudUpdatedAt
            return await fetchCloudData()
        } catch {
            state = .failed(error.localizedDescription)
            return nil
        }
    }

    func syncGroupPlayers(_ players: [FriendProfile], actor: UserProfile) async {
        guard isConfigured else {
            state = .localOnly
            return
        }

        state = .syncing
        do {
            try await client.upsertGroupPlayers(players, actor: actor)
            let syncDate = Date()
            lastKnownCloudUpdatedAt = syncDate
            state = .synced(syncDate)
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    func syncTrip(_ trip: GolfTrip, actor: UserProfile) async {
        guard isConfigured else {
            state = .localOnly
            return
        }

        state = .syncing
        do {
            try await client.upsertTrip(trip, actor: actor)
            let syncDate = Date()
            lastKnownCloudUpdatedAt = syncDate
            state = .synced(syncDate)
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    func syncRound(_ round: RoundSummary, in trip: GolfTrip, actor: UserProfile) async {
        guard isConfigured else {
            state = .localOnly
            return
        }

        state = .syncing
        do {
            try await client.upsertRound(round, in: trip, actor: actor)
            let syncDate = Date()
            lastKnownCloudUpdatedAt = syncDate
            state = .synced(syncDate)
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    func deleteRound(_ roundID: UUID, actor: UserProfile) async {
        guard isConfigured else {
            state = .localOnly
            return
        }

        state = .syncing
        do {
            try await client.deleteRound(roundID, actor: actor)
            let syncDate = Date()
            lastKnownCloudUpdatedAt = syncDate
            state = .synced(syncDate)
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    func deleteTrip(_ tripID: UUID, actor: UserProfile) async {
        guard isConfigured else {
            state = .localOnly
            return
        }

        state = .syncing
        do {
            try await client.deleteTrip(tripID, actor: actor)
            let syncDate = Date()
            lastKnownCloudUpdatedAt = syncDate
            state = .synced(syncDate)
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    func syncCompletedHoleEdit(round: RoundSummary, holeNumber: Int, actor: UserProfile) async {
        guard isConfigured else {
            state = .localOnly
            return
        }

        state = .syncing
        do {
            try await client.updateCompletedHoleScores(round: round, holeNumber: holeNumber, actor: actor)
            let syncDate = Date()
            lastKnownCloudUpdatedAt = syncDate
            state = .synced(syncDate)
        } catch {
            state = .failed(error.localizedDescription)
        }
    }
}
