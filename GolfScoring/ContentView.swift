import SwiftUI
import PhotosUI
#if canImport(UIKit)
import UIKit
#endif

struct ContentView: View {
    @StateObject private var store = MatchStore()
    @StateObject private var account = AccountStore()
    @StateObject private var cloudSync = CloudSyncStore()
    @StateObject private var golfAppStore = GolfAppStore()
    @State private var trips: [GolfTrip] = []
    @State private var isApplyingCloudData = false
    @State private var latestLocalChangeDate = Date.distantPast
    private let refreshTimer = Timer.publish(every: 2, on: .main, in: .common).autoconnect()

    var body: some View {
        Group {
            if !account.isSignedIn {
                NavigationStack {
                    SignInView(account: account)
                }
            } else if !account.hasSavedProfile {
                NavigationStack {
                    ProfileSetupView(account: account)
                }
            } else if account.needsGameModeChoice {
                GameModeChoiceView(account: account)
            } else if account.activeGameMode == .coteFamily {
                CoteCupRootView(
                    store: store,
                    account: account,
                    cloudSync: cloudSync,
                    trips: $trips,
                    refreshCloud: manuallyRefreshCloud
                )
            } else {
                GeneralGolfRootView(account: account, golfAppStore: golfAppStore)
            }
        }
        .tint(.green)
        .task {
            guard isCoteFamilyActive else { return }
            await refreshCloudData()
        }
        .onChange(of: trips) { _, _ in
            guard isCoteFamilyActive else { return }
            guard !isApplyingCloudData else { return }
            latestLocalChangeDate = Date()
        }
        .onChange(of: account.profile) { _, _ in
            guard isCoteFamilyActive else { return }
            guard !isApplyingCloudData else { return }
            latestLocalChangeDate = Date()
            Task {
                await cloudSync.syncGroupPlayers(account.allGroupPlayers, actor: account.profile)
            }
        }
        .onChange(of: account.groupPlayersRevision) { _, _ in
            guard isCoteFamilyActive else { return }
            guard !isApplyingCloudData else { return }
            latestLocalChangeDate = Date()
            Task {
                await cloudSync.syncGroupPlayers(account.allGroupPlayers, actor: account.profile)
            }
        }
        .onChange(of: account.activeGameMode) { _, newMode in
            guard newMode == .coteFamily else { return }
            Task {
                await refreshCloudData()
            }
        }
        .onReceive(refreshTimer) { _ in
            guard isCoteFamilyActive else { return }
            Task {
                await refreshCloudDataIfChanged()
            }
        }
    }

    private var isCoteFamilyActive: Bool {
        account.isSignedIn && account.activeGameMode == .coteFamily
    }

    private func refreshCloudData() async {
        guard let data = await cloudSync.fetchCloudData() else { return }
        applyCloudData(data)
    }

    private func refreshCloudDataIfChanged() async {
        guard let data = await cloudSync.fetchCloudDataIfChanged() else { return }
        applyCloudData(data)
    }

    private func applyCloudData(_ data: FamilyGolfData) {
        guard isCoteFamilyActive else { return }
        guard data.savedAt >= latestLocalChangeDate else { return }
        isApplyingCloudData = true
        account.applyCloudGroupPlayers(data.groupPlayers)
        trips = data.trips
        AppPersistence.saveProfile(account.profile)
        AppPersistence.saveIsSignedIn(account.isSignedIn)
        AppPersistence.saveHasSavedProfile(account.hasSavedProfile)
        isApplyingCloudData = false
    }

    fileprivate func manuallyRefreshCloud() {
        Task {
            await refreshCloudData()
        }
    }

}

private struct CoteCupRootView: View {
    @ObservedObject var store: MatchStore
    @ObservedObject var account: AccountStore
    @ObservedObject var cloudSync: CloudSyncStore
    @Binding var trips: [GolfTrip]
    let refreshCloud: () -> Void

    var body: some View {
        TabView {
            HomeTabView(
                store: store,
                account: account,
                cloudSync: cloudSync,
                trips: $trips,
                refreshCloud: refreshCloud
            )
            .tabItem {
                Label("Home", systemImage: "house.fill")
            }

            CoursesTabView(trips: trips, account: account)
            .tabItem {
                Label("Courses", systemImage: "flag.2.crossed.fill")
            }

            NavigationStack {
                PlayersView(account: account)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            ProfileMenuButton(account: account)
                        }
                    }
            }
            .tabItem {
                Label("Players", systemImage: "person.3.fill")
            }

            NavigationStack {
                ProfileView(account: account)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            ProfileMenuButton(account: account)
                        }
                    }
            }
            .tabItem {
                Label("Profile", systemImage: "person.crop.circle")
            }
        }
    }
}

private struct GeneralGolfRootView: View {
    @ObservedObject var account: AccountStore
    @ObservedObject var golfAppStore: GolfAppStore

    var body: some View {
        TabView {
            NavigationStack {
                GeneralGolfHomeView(account: account)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            ProfileMenuButton(account: account)
                        }
                    }
            }
            .tabItem {
                Label("Home", systemImage: "house.fill")
            }

            NavigationStack {
                GolfAppSocialView(account: account, golfAppStore: golfAppStore)
            }
            .tabItem {
                Label("Social", systemImage: "person.2.fill")
            }

            NavigationStack {
                GolfAppGamesView(account: account, golfAppStore: golfAppStore)
            }
            .tabItem {
                Label("Games", systemImage: "flag.checkered.2.crossed")
            }

            CoursesTabView(trips: [], account: account, showsCotePerformance: false)
            .tabItem {
                Label("Courses", systemImage: "flag.2.crossed.fill")
            }

            NavigationStack {
                ProfileView(account: account)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            ProfileMenuButton(account: account)
                        }
                    }
            }
            .tabItem {
                Label("Profile", systemImage: "person.crop.circle")
            }
        }
    }
}

private struct GeneralGolfHomeView: View {
    @ObservedObject var account: AccountStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Golf App")
                        .font(.largeTitle.bold())
                    Text("Track rounds, browse courses, and build your golf history.")
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 12) {
                    Label("Your profile", systemImage: "person.crop.circle.fill")
                        .font(.headline)

                    HStack(spacing: 12) {
                        ProfileAvatar(imageData: account.profile.profileImageData, size: 48)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(account.profile.displayName)
                                .fontWeight(.semibold)
                            Text("@\(account.profile.username.isEmpty ? "username" : account.profile.username)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("Index \(account.profile.handicapIndex?.formatted(.number.precision(.fractionLength(1))) ?? "—")")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding()
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18))

                ContentUnavailableView(
                    "Scoring coming next",
                    systemImage: "plus.circle",
                    description: Text("Next we can add personal rounds, friend groups, and regular scorecards here.")
                )
                .padding(.top, 24)
            }
            .padding()
        }
        .navigationTitle("Golf App")
    }
}
