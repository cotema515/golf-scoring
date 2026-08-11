import SwiftUI
import PhotosUI
#if canImport(UIKit)
import UIKit
#endif

struct ContentView: View {
    @StateObject private var store = MatchStore()
    @StateObject private var account = AccountStore()
    @StateObject private var cloudSync = CloudSyncStore()
    @State private var trips = AppPersistence.loadTrips()
    @State private var isApplyingCloudSnapshot = false
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
            } else {
                TabView {
                    HomeTabView(
                        store: store,
                        account: account,
                        cloudSync: cloudSync,
                        trips: $trips,
                        refreshCloud: manuallyRefreshCloud,
                        backupCloud: manuallyBackupToCloud
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
        .tint(.green)
        .task {
            await refreshFromCloud()
            await pushCurrentSnapshot(force: true)
        }
        .onChange(of: trips) { _, updatedTrips in
            AppPersistence.saveTrips(updatedTrips)
            guard !isApplyingCloudSnapshot else { return }
            latestLocalChangeDate = Date()
            Task {
                await pushCurrentSnapshot(trips: updatedTrips)
            }
        }
        .onChange(of: account.profile) { _, _ in
            guard !isApplyingCloudSnapshot else { return }
            latestLocalChangeDate = Date()
            Task {
                await pushCurrentSnapshot()
            }
        }
        .onReceive(refreshTimer) { _ in
            Task {
                await refreshFromCloud()
            }
        }
    }

    private func currentSnapshot(trips snapshotTrips: [GolfTrip]? = nil) -> AppSnapshot {
        AppPersistence.currentSnapshot(
            profile: account.profile,
            trips: snapshotTrips ?? trips,
            groupPlayers: account.allGroupPlayers,
            isSignedIn: account.isSignedIn,
            hasSavedProfile: account.hasSavedProfile
        )
    }

    private func pushCurrentSnapshot(trips snapshotTrips: [GolfTrip]? = nil, force: Bool = false) async {
        await cloudSync.pushSnapshot(currentSnapshot(trips: snapshotTrips), force: force)
    }

    private func refreshFromCloud() async {
        guard let snapshot = await cloudSync.fetchCloudSnapshot() else { return }
        guard snapshot.savedAt >= latestLocalChangeDate else { return }
        isApplyingCloudSnapshot = true
        account.applyCloudGroupPlayers(snapshot.groupPlayers)
        trips = GolfTrip.mergedWithCurrentSamples(snapshot.trips)
        AppPersistence.saveTrips(trips)
        AppPersistence.saveGroupPlayers(account.allGroupPlayers)
        AppPersistence.saveProfile(account.profile)
        AppPersistence.saveIsSignedIn(account.isSignedIn)
        AppPersistence.saveHasSavedProfile(account.hasSavedProfile)
        isApplyingCloudSnapshot = false
    }

    fileprivate func manuallyRefreshCloud() {
        Task {
            await refreshFromCloud()
        }
    }

    fileprivate func manuallyBackupToCloud() {
        Task {
            await pushCurrentSnapshot(force: true)
        }
    }
}
