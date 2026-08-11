import SwiftUI

enum HomeRoute: Hashable {
    case newTrip
    case trip(UUID)
    case setup(UUID?, UUID?)
    case scorecard(UUID?, UUID?)
}

struct HomeTabView: View {
    @ObservedObject var store: MatchStore
    @ObservedObject var account: AccountStore
    @ObservedObject var cloudSync: CloudSyncStore
    @Binding var trips: [GolfTrip]
    let refreshCloud: () -> Void
    let backupCloud: () -> Void
    @State private var path: [HomeRoute] = []

    var body: some View {
        NavigationStack(path: $path) {
            HomeView(
                account: account,
                cloudSync: cloudSync,
                trips: trips.sortedByNewestDate(),
                refreshCloud: refreshCloud,
                backupCloud: backupCloud,
                startSingleRound: { startRound(from: nil) },
                startTrip: { path.append(.newTrip) },
                openTrip: { path.append(.trip($0.id)) },
                editTrip: { trip, name, date in
                    editTrip(trip.id, name: name, date: date)
                },
                deleteTrip: { trip in
                    deleteTrip(trip.id)
                }
            )
            .navigationDestination(for: HomeRoute.self) { route in
                destination(for: route)
            }
        }
    }

    @ViewBuilder
    private func destination(for route: HomeRoute) -> some View {
        switch route {
        case .newTrip:
            NewTripView(account: account) { tripName, tripDate in
                let trip = GolfTrip(name: tripName, date: tripDate, rounds: [])
                trips.append(trip)
                replaceCurrentRoute(with: .trip(trip.id))
            } cancel: {
                popCurrentRoute()
            }
        case .trip(let tripID):
            if let tripIndex = trips.firstIndex(where: { $0.id == tripID }) {
                TripDetailView(trip: $trips[tripIndex], account: account) {
                    startRound(from: trips[tripIndex].id)
                } editRoundScores: { roundID in
                    editRoundScores(roundID, in: trips[tripIndex].id)
                } editRoundSetup: { roundID in
                    editRoundSetup(roundID, in: trips[tripIndex].id)
                } deleteRound: { roundID in
                    deleteRound(roundID, in: trips[tripIndex].id)
                } editTrip: { name, date in
                    trips[tripIndex].updateTripDetails(name: name, startDate: date)
                } deleteTrip: {
                    deleteTrip(trips[tripIndex].id)
                }
            } else {
                ContentUnavailableView(
                    "Trip not found",
                    systemImage: "exclamationmark.triangle",
                    description: Text("Go back and choose a trip again.")
                )
            }
        case .setup(let tripID, let roundID):
            SetupView(
                store: store,
                account: account,
                isEditingExistingRound: roundID != nil,
                start: { replaceCurrentRoute(with: .scorecard(tripID, roundID)) },
                cancel: {
                    store.resetRound()
                    popCurrentRoute()
                }
            )
        case .scorecard(let tripID, let roundID):
            ScorecardView(store: store, account: account, savedRoundID: roundID) { summary in
                saveSubmittedRound(summary, tripID: tripID)
            }
        }
    }

    private func startRound(from tripID: UUID?) {
        store.resetRound()
        path.append(.setup(tripID, nil))
    }

    private func editRoundScores(_ roundID: UUID, in tripID: UUID) {
        guard loadRound(roundID, in: tripID) else { return }
        path.append(.scorecard(tripID, roundID))
    }

    private func editRoundSetup(_ roundID: UUID, in tripID: UUID) {
        guard loadRound(roundID, in: tripID) else { return }
        path.append(.setup(tripID, roundID))
    }

    @discardableResult
    private func loadRound(_ roundID: UUID, in tripID: UUID) -> Bool {
        guard
            let trip = trips.first(where: { $0.id == tripID }),
            let round = trip.rounds.first(where: { $0.id == roundID })
        else { return false }

        store.loadRound(round)
        return true
    }

    private func saveSubmittedRound(_ summary: RoundSummary, tripID: UUID?) {
        if let tripID,
           let tripIndex = trips.firstIndex(where: { $0.id == tripID }) {
            upsert(summary, in: &trips[tripIndex].rounds)
            trips[tripIndex].syncDateToFirstRound()
            return
        }

        let singleRoundsName = "Single Rounds"
        if let tripIndex = trips.firstIndex(where: { $0.name == singleRoundsName }) {
            upsert(summary, in: &trips[tripIndex].rounds)
            trips[tripIndex].syncDateToFirstRound()
        } else {
            trips.append(GolfTrip(name: singleRoundsName, date: summary.date, rounds: [summary]))
        }
    }

    private func upsert(_ summary: RoundSummary, in rounds: inout [RoundSummary]) {
        if let roundIndex = rounds.firstIndex(where: { $0.id == summary.id }) {
            rounds[roundIndex] = summary
        } else {
            rounds.append(summary)
        }
    }

    private func deleteRound(_ roundID: UUID, in tripID: UUID) {
        guard let tripIndex = trips.firstIndex(where: { $0.id == tripID }) else { return }
        trips[tripIndex].rounds.removeAll { $0.id == roundID }
        trips[tripIndex].syncDateToFirstRound()
    }

    private func editTrip(_ tripID: UUID, name: String, date: Date) {
        guard let tripIndex = trips.firstIndex(where: { $0.id == tripID }) else { return }
        trips[tripIndex].updateTripDetails(name: name, startDate: date)
    }

    private func deleteTrip(_ tripID: UUID) {
        trips.removeAll { $0.id == tripID }
        path.removeAll { route in
            if case .trip(let id) = route {
                return id == tripID
            }
            if case .setup(let id, _) = route {
                return id == tripID
            }
            if case .scorecard(let id, _) = route {
                return id == tripID
            }
            return false
        }
    }

    private func popCurrentRoute() {
        if !path.isEmpty {
            path.removeLast()
        }
    }

    private func replaceCurrentRoute(with route: HomeRoute) {
        popCurrentRoute()
        path.append(route)
    }
}

extension Array where Element == GolfTrip {
    func sortedByNewestDate() -> [GolfTrip] {
        sorted {
            if $0.displayDate == $1.displayDate {
                return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
            return $0.displayDate > $1.displayDate
        }
    }
}
