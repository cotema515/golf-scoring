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

    private let client = SupabaseSnapshotClient()
    private var lastEncodedSnapshot: Data?

    var isConfigured: Bool {
        SupabaseConfiguration.isConfigured
    }

    func fetchCloudSnapshot() async -> AppSnapshot? {
        guard isConfigured else {
            state = .localOnly
            return nil
        }

        state = .syncing
        do {
            let snapshot = try await client.fetchSnapshot()
            if let snapshot {
                lastEncodedSnapshot = try? JSONEncoder.cloud.encode(snapshot)
            }
            state = .synced(Date())
            return snapshot
        } catch {
            state = .failed(error.localizedDescription)
            return nil
        }
    }

    func pushSnapshot(_ snapshot: AppSnapshot, force: Bool = false) async {
        guard isConfigured else {
            state = .localOnly
            return
        }

        let encoded = try? JSONEncoder.cloud.encode(snapshot)
        guard force || encoded != lastEncodedSnapshot else { return }

        state = .syncing
        do {
            try await client.upsertSnapshot(snapshot)
            lastEncodedSnapshot = encoded
            state = .synced(Date())
        } catch {
            state = .failed(error.localizedDescription)
        }
    }
}
