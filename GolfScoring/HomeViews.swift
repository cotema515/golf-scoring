import SwiftUI
import MapKit

struct HomeView: View {
    @ObservedObject var account: AccountStore
    @ObservedObject var cloudSync: CloudSyncStore
    let trips: [GolfTrip]
    let refreshCloud: () -> Void
    let startSingleRound: () -> Void
    let startTrip: () -> Void
    let openTrip: (GolfTrip) -> Void
    let editTrip: (GolfTrip, String, Date) -> Void
    let deleteTrip: (GolfTrip) -> Void
    @State private var tripBeingEdited: GolfTrip?
    @State private var tripPendingFirstDeleteConfirmation: GolfTrip?
    @State private var tripPendingFinalDeleteConfirmation: GolfTrip?
    @State private var deleteConfirmationText = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 14) {
                    AppLogoMark(size: 58)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Welcome, \(account.profile.firstName)")
                            .font(.title.bold())
                        Text("Trips, scorecards, and the running match total.")
                            .foregroundStyle(.secondary)
                    }
                }

                OverallGamesCard(trips: trips)
                PlayerAveragesCard(trips: trips)

                VStack(spacing: 10) {
                    Button(action: startTrip) {
                        Label("Start Trip", systemImage: "map.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)

                    Button(action: startSingleRound) {
                        Label("Start Single Round", systemImage: "flag.checkered")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("Trips")
                        .font(.headline)

                    ForEach(trips) { trip in
                        Button {
                            openTrip(trip)
                        } label: {
                            TripCard(trip: trip)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button("Edit Trip") {
                                tripBeingEdited = trip
                            }

                            Button("Delete Trip", role: .destructive) {
                                tripPendingFirstDeleteConfirmation = trip
                            }
                        }
                    }
                }

                CloudStatusCard(sync: cloudSync, refresh: refreshCloud)
            }
            .padding()
        }
        .sheet(item: $tripBeingEdited) { trip in
            EditTripView(
                trip: trip,
                save: { updatedName, updatedDate in
                    editTrip(trip, updatedName, updatedDate)
                    tripBeingEdited = nil
                },
                cancel: {
                    tripBeingEdited = nil
                }
            )
        }
        .navigationTitle("Golf Scoring")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                ProfileMenuButton(account: account)
            }
        }
        .alert("Delete this trip?", isPresented: firstTripDeleteBinding) {
            Button("Cancel", role: .cancel) {}
            Button("Continue", role: .destructive) {
                tripPendingFinalDeleteConfirmation = tripPendingFirstDeleteConfirmation
                deleteConfirmationText = ""
            }
        } message: {
            Text("This will remove the trip and every round inside it from this device.")
        }
        .alert("Type DELETE to confirm", isPresented: finalTripDeleteBinding) {
            TextField("DELETE", text: $deleteConfirmationText)
            Button("Cancel", role: .cancel) {}
            Button("Delete Forever", role: .destructive) {
                if deleteConfirmationText == "DELETE", let trip = tripPendingFinalDeleteConfirmation {
                    deleteTrip(trip)
                }
                tripPendingFirstDeleteConfirmation = nil
                tripPendingFinalDeleteConfirmation = nil
                deleteConfirmationText = ""
            }
            .disabled(deleteConfirmationText != "DELETE")
        } message: {
            Text("This cannot be undone. Type DELETE exactly to remove this trip.")
        }
    }

    private var firstTripDeleteBinding: Binding<Bool> {
        Binding(
            get: { tripPendingFirstDeleteConfirmation != nil },
            set: { isPresented in
                if !isPresented {
                    tripPendingFirstDeleteConfirmation = nil
                }
            }
        )
    }

    private var finalTripDeleteBinding: Binding<Bool> {
        Binding(
            get: { tripPendingFinalDeleteConfirmation != nil },
            set: { isPresented in
                if !isPresented {
                    tripPendingFinalDeleteConfirmation = nil
                    deleteConfirmationText = ""
                }
            }
        )
    }
}

struct CloudStatusCard: View {
    @ObservedObject var sync: CloudSyncStore
    let refresh: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: iconName)
                .font(.subheadline)
                .foregroundStyle(iconColor)
                .frame(width: 20)

            Text(statusText)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Spacer()

            Menu {
                Button("Refresh Now") {
                    refresh()
                }
                .disabled(!sync.isConfigured)
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(minHeight: 28)
        .accessibilityElement(children: .combine)
    }

    private var iconName: String {
        switch sync.state {
        case .idle, .syncing, .synced:
            return "icloud.fill"
        case .localOnly, .failed:
            return "icloud.slash"
        }
    }

    private var iconColor: Color {
        switch sync.state {
        case .localOnly, .failed:
            return .orange
        default:
            return .secondary
        }
    }

    private var statusText: String {
        switch sync.state {
        case .localOnly:
            return "Cloud off"
        case .failed:
            return "Cloud issue"
        case .idle, .syncing, .synced:
            return "Cloud backup"
        }
    }
}

struct TripCard: View {
    let trip: GolfTrip

    private var incompleteRoundCount: Int {
        trip.rounds.filter { !$0.isComplete }.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                AppLogoMark(size: 36)

                VStack(alignment: .leading, spacing: 3) {
                    Text(trip.name)
                        .font(.title3.bold())
                    Text("\(trip.displayDate.formatted(.dateTime.month().day().year())) · \(trip.rounds.count) round\(trip.rounds.count == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(trip.leaderText)
                    .font(.headline)
                    .foregroundStyle(trip.leaderColor)
            }

            HStack(spacing: 10) {
                TripStat(label: "Josh/Matt", value: trip.joshMattWins)
                TripStat(label: "Jeff/Shane", value: trip.shaneJeffWins)
                TripStat(label: "Ties", value: trip.ties)
            }

            if incompleteRoundCount > 0 {
                Label(
                    "\(incompleteRoundCount) incomplete round\(incompleteRoundCount == 1 ? "" : "s")",
                    systemImage: "exclamationmark.circle.fill"
                )
                .font(.caption.weight(.semibold))
                .foregroundStyle(.orange)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.orange.opacity(0.12), in: Capsule())
            }
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
    }
}

struct OverallGamesCard: View {
    let trips: [GolfTrip]

    private var joshMattWins: Int {
        trips.reduce(0) { $0 + $1.teamOneWins }
    }

    private var shaneJeffWins: Int {
        trips.reduce(0) { $0 + $1.teamTwoWins }
    }

    private var ties: Int {
        trips.reduce(0) { $0 + $1.ties }
    }

    private var delta: Int {
        joshMattWins - shaneJeffWins
    }

    private var leaderText: String {
        if delta == 0 { return "All square all-time" }
        return delta > 0 ? "Josh & Matt +\(delta) all-time" : "Jeff & Shane +\(abs(delta)) all-time"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                AppLogoMark(size: 34)

                VStack(alignment: .leading, spacing: 3) {
                    Text("Overall Games")
                        .font(.headline)
                    Text("Across every saved round.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(leaderText)
                    .font(.headline)
                    .foregroundStyle(delta > 0 ? AppColors.joshMatt : delta < 0 ? AppColors.jeffShane : AppColors.push)
            }

            HStack(spacing: 10) {
                TripStat(label: "Josh/Matt", value: joshMattWins)
                TripStat(label: "Jeff/Shane", value: shaneJeffWins)
                TripStat(label: "Ties", value: ties)
            }
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
    }
}

struct PlayerAveragesCard: View {
    let trips: [GolfTrip]

    private var completedRounds: [RoundSummary] {
        trips
            .flatMap(\.rounds)
            .filter(\.isComplete)
            .sorted { $0.date < $1.date }
    }

    private var playerStats: [PlayerAverageStat] {
        var entriesByName: [String: [PlayerRoundWithHoles]] = [:]
        for round in completedRounds {
            for player in round.players {
                entriesByName[player.name, default: []].append(PlayerRoundWithHoles(round: round, player: player))
            }
        }

        var stats: [PlayerAverageStat] = []
        for (name, entries) in entriesByName {
            let scores = entries.map { $0.player }
            guard !scores.isEmpty else { continue }

            let grossTotal = scores.reduce(0) { $0 + $1.gross }
            let netTotal = scores.reduce(0) { $0 + $1.net }
            var birdies = 0
            var netBirdies = 0

            for entry in entries {
                for hole in entry.round.holes where entry.round.isHoleComplete(hole.number) {
                    guard let playerHole = hole.players.first(where: { $0.name == name }) else { continue }
                    if playerHole.gross == hole.par - 1 {
                        birdies += 1
                    }
                    if playerHole.net <= hole.par - 1 {
                        netBirdies += 1
                    }
                }
            }

            stats.append(PlayerAverageStat(
                name: name,
                rounds: scores.count,
                grossAverage: Double(grossTotal) / Double(scores.count),
                netAverage: Double(netTotal) / Double(scores.count),
                birdies: birdies,
                netBirdies: netBirdies
            ))
        }

        return stats.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    var body: some View {
        if !playerStats.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("Player Form", systemImage: "chart.bar.fill")
                        .font(.headline)
                    Spacer()
                    Text("Averages + birdies")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                }

                ForEach(playerStats) { stat in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(firstName(for: stat.name))
                                .font(.subheadline.bold())
                            Spacer()
                            Text("\(stat.rounds) rounds")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }

                        Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 4) {
                            GridRow {
                                PlayerFormMiniStat(label: "Gross", value: stat.grossAverage.formatted(.number.precision(.fractionLength(1))))
                                PlayerFormMiniStat(label: "Net", value: stat.netAverage.formatted(.number.precision(.fractionLength(1))))
                            }
                            GridRow {
                                PlayerFormMiniStat(label: "Birdies", value: "\(stat.birdies)")
                                PlayerFormMiniStat(label: "Net birdies", value: "\(stat.netBirdies)")
                            }
                        }
                    }
                    .padding(.vertical, 6)

                    if stat.id != playerStats.last?.id {
                        Divider()
                    }
                }
            }
            .padding()
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
        }
    }

    private func firstName(for name: String) -> String {
        name.split(separator: " ").first.map(String.init) ?? name
    }
}

struct PlayerAverageStat: Identifiable {
    let name: String
    let rounds: Int
    let grossAverage: Double
    let netAverage: Double
    let birdies: Int
    let netBirdies: Int

    var id: String { name }
}

private struct PlayerRoundWithHoles {
    let round: RoundSummary
    let player: PlayerRoundSummary
}

private struct PlayerFormMiniStat: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.semibold)
                .monospacedDigit()
        }
        .font(.caption)
    }
}

private struct StablefordBarChart: View {
    let values: [Int]
    let color: Color

    private var maxValue: Double {
        Double(max(values.max() ?? 1, 1))
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 6) {
            if values.isEmpty {
                Capsule().fill(Color.secondary.opacity(0.18)).frame(height: 8)
            } else {
                ForEach(Array(values.enumerated()), id: \.offset) { _, value in
                    VStack(spacing: 3) {
                        Text("\(value)")
                            .font(.caption2.monospacedDigit().bold())
                            .foregroundStyle(.secondary)
                        Capsule()
                            .fill(color.opacity(0.78))
                            .frame(maxWidth: .infinity)
                            .frame(height: max(8, CGFloat(Double(value) / maxValue) * 34))
                    }
                }
            }
        }
    }
}

struct TripStablefordCard: View {
    let trip: GolfTrip

    private var standings: [PlayerStablefordTripStat] {
        let rounds = trip.rounds.filter(\.isComplete).sorted { $0.date < $1.date }
        let grouped = Dictionary(grouping: rounds.flatMap(\.players), by: \.name)
        return grouped.map { name, players in
            PlayerStablefordTripStat(
                name: name,
                points: players.reduce(0) { $0 + $1.stableford },
                roundPoints: rounds.compactMap { round in
                    round.players.first(where: { $0.name == name })?.stableford
                }
            )
        }
        .sorted {
            if $0.points == $1.points {
                return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
            return $0.points > $1.points
        }
    }

    private var topPoints: Int? {
        standings.first?.points
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Trip Stableford", systemImage: "star.circle.fill")
                    .font(.headline)
            }

            if standings.isEmpty {
                Text("Stableford totals will show after scores are saved.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 8) {
                    ForEach(Array(standings.enumerated()), id: \.element.id) { index, stat in
                        let isTiedForLead = stat.points == topPoints
                        HStack(spacing: 10) {
                            Text("\(index + 1)")
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)
                                .frame(width: 22)

                            Text(stat.name)
                                .font(.subheadline.weight(isTiedForLead ? .bold : .regular))

                            Spacer()
                            Text("\(stat.points) pts")
                                .font(.subheadline.monospacedDigit().bold())
                        }

                        StablefordBarChart(values: stat.roundPoints, color: .orange)
                            .frame(maxWidth: .infinity)
                            .frame(height: 46)

                        if stat.id != standings.last?.id {
                            Divider()
                        }
                    }
                    .padding(.vertical, 6)
                }
            }
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
    }

    private func firstName(for name: String) -> String {
        name.split(separator: " ").first.map(String.init) ?? name
    }
}

private struct PlayerStablefordTripStat: Identifiable {
    let name: String
    let points: Int
    let roundPoints: [Int]

    var id: String { name }
}

struct TripStatsCard: View {
    let trip: GolfTrip

    private var completedRounds: [RoundSummary] {
        trip.rounds.filter(\.isComplete)
    }

    private var playerRounds: [PlayerTripRound] {
        completedRounds.flatMap { round in
            round.players.map {
                PlayerTripRound(
                    playerName: $0.name,
                    courseName: round.courseName,
                    gross: $0.gross,
                    net: $0.net,
                    stableford: $0.stableford
                )
            }
        }
    }

    private var bestGross: PlayerTripRound? {
        playerRounds.min {
            if $0.gross == $1.gross {
                return $0.net < $1.net
            }
            return $0.gross < $1.gross
        }
    }

    private var totalBirdies: Int {
        completedRounds.reduce(0) { total, round in
            total + round.holes.reduce(0) { holeTotal, hole in
                guard round.isHoleComplete(hole.number) else { return holeTotal }
                return holeTotal + hole.players.filter { $0.gross == hole.par - 1 }.count
            }
        }
    }

    private var totalNetBirdies: Int {
        completedRounds.reduce(0) { total, round in
            total + round.holes.reduce(0) { holeTotal, hole in
                guard round.isHoleComplete(hole.number) else { return holeTotal }
                return holeTotal + hole.players.filter { $0.net <= hole.par - 1 }.count
            }
        }
    }

    private var totalEaglesOrBetter: Int {
        completedRounds.reduce(0) { total, round in
            total + round.holes.reduce(0) { holeTotal, hole in
                guard round.isHoleComplete(hole.number) else { return holeTotal }
                return holeTotal + hole.players.filter { $0.gross <= hole.par - 2 }.count
            }
        }
    }

    private var bestBallSummary: String {
        let scoredHoles = completedRounds.flatMap { round in
            round.holes.filter { round.isHoleComplete($0.number) }
        }
        guard !scoredHoles.isEmpty else { return "—" }

        let bestBall = scoredHoles.reduce(0) { total, hole in
            total + (hole.players.map(\.gross).min() ?? hole.par)
        }
        let par = scoredHoles.reduce(0) { $0 + $1.par }
        let delta = bestBall - par

        if delta == 0 { return "\(bestBall) / E" }
        return "\(bestBall) / \(delta > 0 ? "+" : "")\(delta)"
    }

    private var bestNet: PlayerTripRound? {
        playerRounds.min {
            if $0.net == $1.net {
                return $0.gross < $1.gross
            }
            return $0.net < $1.net
        }
    }

    private var trendText: String {
        if trip.gamesDelta == 0 {
            return "The match is dead even."
        }

        let leader = trip.gamesDelta > 0 ? GolfTrip.joshMattTeamName : GolfTrip.shaneJeffTeamName
        let margin = abs(trip.gamesDelta)
        return "\(leader) \(margin == 1 ? "has a one-game edge" : "leads by \(margin) games")."
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Trip Stats", systemImage: "chart.bar.xaxis")
                    .font(.headline)
                Spacer()
                Text(trendText)
                    .font(.caption.bold())
                    .foregroundStyle(trip.leaderColor)
                    .multilineTextAlignment(.trailing)
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                TripMetricTile(title: "Birdies", value: "\(totalBirdies)", subtitle: "\(totalNetBirdies) net birdies")
                TripMetricTile(title: "Best Ball", value: bestBallSummary, subtitle: "group gross score")
                TripMetricTile(
                    title: "Low Gross",
                    value: bestGross.map { "\($0.gross)" } ?? "—",
                    subtitle: bestGross.map { "\(firstName(for: $0.playerName)) · \($0.courseName)" } ?? "after a round"
                )
                TripMetricTile(
                    title: "Low Net",
                    value: bestNet.map { "\($0.net)" } ?? "—",
                    subtitle: bestNet.map { "\(firstName(for: $0.playerName)) · \($0.courseName)" } ?? "after a round"
                )
            }
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
    }

    private func firstName(for name: String) -> String {
        name.split(separator: " ").first.map(String.init) ?? name
    }
}

private struct TripMetricTile: View {
    let title: String
    let value: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.monospacedDigit().bold())
            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 10))
    }
}

private struct PlayerTripRound {
    let playerName: String
    let courseName: String
    let gross: Int
    let net: Int
    let stableford: Int
}

struct TripPlayersCard: View {
    let trip: GolfTrip
    @ObservedObject var account: AccountStore

    private var playerNames: [String] {
        var seen = Set<String>()
        let names = trip.rounds.flatMap { round -> [String] in
            if let golfers = round.golfers {
                return golfers.map(\.name)
            }
            return round.players.map(\.name)
        }

        return names.filter { name in
            if seen.contains(name) { return false }
            seen.insert(name)
            return true
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Trip Players", systemImage: "person.3.fill")
                    .font(.headline)
                Spacer()
                Text("\(playerNames.count)")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
            }

            if playerNames.isEmpty {
                Text("Players will show here after the first round is added.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 72), spacing: 12)], spacing: 12) {
                    ForEach(playerNames, id: \.self) { playerName in
                        VStack(spacing: 6) {
                            ProfileAvatar(imageData: account.profileImageData(for: playerName), size: 54)
                            Text(firstName(for: playerName))
                                .font(.caption.bold())
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
    }

    private func firstName(for name: String) -> String {
        name.split(separator: " ").first.map(String.init) ?? name
    }
}

struct TripCourseMapCard: View {
    let trip: GolfTrip

    private var mappedCourses: [MappedCourse] {
        var seen = Set<String>()
        return trip.rounds.compactMap { round in
            let name = round.course?.name ?? round.courseName
            guard let coordinate = CourseCoordinateLookup.coordinate(for: name) else { return nil }
            let key = CourseCoordinateLookup.normalized(name)
            guard !seen.contains(key) else { return nil }
            seen.insert(key)
            return MappedCourse(name: name, coordinate: coordinate)
        }
    }

    private var shouldShowMap: Bool {
        trip.name.localizedCaseInsensitiveCompare("Single Rounds") != .orderedSame && !mappedCourses.isEmpty
    }

    private var tripCoordinate: CLLocationCoordinate2D {
        let coordinates = mappedCourses.map(\.coordinate)
        let latitude = coordinates.map(\.latitude).reduce(0, +) / Double(coordinates.count)
        let longitude = coordinates.map(\.longitude).reduce(0, +) / Double(coordinates.count)
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    private var position: MapCameraPosition {
        .region(region(center: tripCoordinate))
    }

    var body: some View {
        if shouldShowMap {
            VStack(alignment: .leading, spacing: 10) {
                Label("Trip Map", systemImage: "map.fill")
                    .font(.headline)

                Map(initialPosition: position) {
                    Annotation(trip.name, coordinate: tripCoordinate, anchor: .center) {
                        TripRegionMapDot(title: trip.name)
                    }
                }
                .mapStyle(.standard(elevation: .flat, pointsOfInterest: .excludingAll))
                .frame(height: 220)
                .clipShape(RoundedRectangle(cornerRadius: 14))

                VStack(alignment: .leading, spacing: 6) {
                    ForEach(mappedCourses) { course in
                        Label(course.name, systemImage: "flag.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding()
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
        }
    }

    private func region(center: CLLocationCoordinate2D) -> MKCoordinateRegion {
        return MKCoordinateRegion(
            center: center,
            span: MKCoordinateSpan(latitudeDelta: 9.0, longitudeDelta: 12.0)
        )
    }
}

private struct TripRegionMapDot: View {
    let title: String

    var body: some View {
        VStack(spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.thinMaterial, in: Capsule())
                .overlay {
                    Capsule().stroke(Color.green.opacity(0.25), lineWidth: 1)
                }

            Circle()
                .fill(Color.green)
                .frame(width: 12, height: 12)
                .overlay {
                    Circle().stroke(.white, lineWidth: 3)
                }
                .shadow(color: .black.opacity(0.18), radius: 3, y: 1)
        }
    }
}

private struct MappedCourse: Identifiable {
    let name: String
    let coordinate: CLLocationCoordinate2D

    var id: String { CourseCoordinateLookup.normalized(name) }
}

private enum CourseCoordinateLookup {
    static func coordinate(for courseName: String) -> CLLocationCoordinate2D? {
        coordinates[normalized(courseName)]
    }

    static func normalized(_ name: String) -> String {
        name.lowercased().components(separatedBy: CharacterSet.alphanumerics.inverted).joined()
    }

    private static let coordinates: [String: CLLocationCoordinate2D] = [
        normalized("The Ocean Course"): CLLocationCoordinate2D(latitude: 32.6083, longitude: -79.9746),
        normalized("Turtle Point"): CLLocationCoordinate2D(latitude: 32.6040, longitude: -80.0770),
        normalized("Cougar Point"): CLLocationCoordinate2D(latitude: 32.6080, longitude: -80.1290),
        normalized("Bandon Dunes"): CLLocationCoordinate2D(latitude: 43.1848, longitude: -124.3900),
        normalized("Pacific Dunes"): CLLocationCoordinate2D(latitude: 43.1950, longitude: -124.3890),
        normalized("Bandon Trails"): CLLocationCoordinate2D(latitude: 43.1730, longitude: -124.3880),
        normalized("Old Macdonald"): CLLocationCoordinate2D(latitude: 43.2060, longitude: -124.3950),
        normalized("Sheep Ranch"): CLLocationCoordinate2D(latitude: 43.2160, longitude: -124.3980),
        normalized("Streamsong Red"): CLLocationCoordinate2D(latitude: 27.6530, longitude: -81.9530),
        normalized("Streamsong Blue"): CLLocationCoordinate2D(latitude: 27.6538, longitude: -81.9518),
        normalized("Streamsong Black"): CLLocationCoordinate2D(latitude: 27.6550, longitude: -81.9560),
        normalized("TPC Sawgrass Stadium Course"): CLLocationCoordinate2D(latitude: 30.1980, longitude: -81.3940),
        normalized("TPC Sawgrass Dye's Valley Course"): CLLocationCoordinate2D(latitude: 30.1970, longitude: -81.3920),
        normalized("Sailfish Point Golf Club"): CLLocationCoordinate2D(latitude: 27.1760, longitude: -80.1720),
        normalized("TPC Boston"): CLLocationCoordinate2D(latitude: 42.0190, longitude: -71.2270),
        normalized("Erin Hills"): CLLocationCoordinate2D(latitude: 43.2440, longitude: -88.3940),
        normalized("Whistling Straits"): CLLocationCoordinate2D(latitude: 43.8510, longitude: -87.7350),
        normalized("Rhode Island Country Club"): CLLocationCoordinate2D(latitude: 41.7440, longitude: -71.3150),
        normalized("Newport National Golf Club"): CLLocationCoordinate2D(latitude: 41.5140, longitude: -71.2630)
    ]
}

struct TripStat: View {
    let label: String
    let value: Int

    var body: some View {
        VStack(spacing: 2) {
            Text("\(value)")
                .font(.title3.bold())
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct EditTripView: View {
    let trip: GolfTrip
    let save: (String, Date) -> Void
    let cancel: () -> Void
    @State private var tripName: String
    @State private var tripDate: Date
    @FocusState private var isTripNameFocused: Bool

    init(
        trip: GolfTrip,
        save: @escaping (String, Date) -> Void,
        cancel: @escaping () -> Void
    ) {
        self.trip = trip
        self.save = save
        self.cancel = cancel
        _tripName = State(initialValue: trip.name)
        _tripDate = State(initialValue: trip.displayDate)
    }

    private var cleanTripName: String {
        tripName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Trip name", text: $tripName)
                        .textInputAutocapitalization(.words)
                        .submitLabel(.done)
                        .focused($isTripNameFocused)
                        .onSubmit {
                            isTripNameFocused = false
                        }
                    DateSelectionButton(title: "First round date", date: $tripDate)
                } footer: {
                    if trip.rounds.isEmpty {
                        Text("This date is used until the trip has rounds.")
                    } else {
                        Text("Trips use the date of the first round. Changing this shifts all round dates in the trip together.")
                    }
                }
            }
            .navigationTitle("Edit Trip")
            .navigationBarTitleDisplayMode(.inline)
            .scrollDismissesKeyboard(.interactively)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .cancel, action: cancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save(cleanTripName, tripDate)
                    }
                    .disabled(cleanTripName.isEmpty)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        isTripNameFocused = false
                    }
                }
            }
        }
    }
}

struct NewTripView: View {
    @ObservedObject var account: AccountStore
    let create: (String, Date) -> Void
    let cancel: () -> Void
    @State private var tripName = ""
    @State private var tripDate = Date()
    @FocusState private var isTripNameFocused: Bool

    private var cleanTripName: String {
        tripName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        Form {
            Section {
                HStack {
                    Spacer()
                    AppLogoMark(size: 78)
                    Spacer()
                }
                .listRowBackground(Color.clear)
            }

            Section {
                TextField("Trip name", text: $tripName)
                    .textInputAutocapitalization(.words)
                    .submitLabel(.done)
                    .focused($isTripNameFocused)
                    .onSubmit {
                        isTripNameFocused = false
                    }
                DateSelectionButton(title: "Trip date", date: $tripDate)
            } footer: {
                Text("A trip keeps multiple rounds together and tracks the running match total across the whole trip.")
            }

            Section {
                Button("Create Trip") {
                    create(cleanTripName, tripDate)
                }
                .frame(maxWidth: .infinity)
                .fontWeight(.semibold)
                .disabled(cleanTripName.isEmpty)
            }
        }
        .navigationTitle("Start Trip")
        .navigationBarBackButtonHidden(true)
        .scrollDismissesKeyboard(.interactively)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Cancel", role: .cancel, action: cancel)
            }

            ToolbarItem(placement: .topBarTrailing) {
                ProfileMenuButton(account: account)
            }

            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    isTripNameFocused = false
                }
            }
        }
    }
}

struct TripDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var trip: GolfTrip
    @ObservedObject var account: AccountStore
    let startRound: () -> Void
    let editRoundScores: (UUID) -> Void
    let editRoundSetup: (UUID) -> Void
    let deleteRound: (UUID) -> Void
    let saveCompletedHoleEdit: (RoundSummary, Int) -> Void
    let editTrip: (String, Date) -> Void
    let deleteTrip: () -> Void
    @State private var showEditTrip = false
    @State private var showFirstTripDeleteConfirmation = false
    @State private var showFinalTripDeleteConfirmation = false
    @State private var deleteConfirmationText = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                TripCard(trip: trip)
                TripStablefordCard(trip: trip)
                TripStatsCard(trip: trip)
                TripPlayersCard(trip: trip, account: account)

                Button(action: startRound) {
                    Label("Add Round to Trip", systemImage: "plus.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)

                VStack(alignment: .leading, spacing: 12) {
                    Text("Round Scorecards")
                        .font(.headline)

                    if trip.rounds.isEmpty {
                        ContentUnavailableView(
                            "No rounds yet",
                            systemImage: "list.bullet.rectangle",
                            description: Text("Start a round to build this trip's running total.")
                        )
                    } else {
                        ForEach($trip.rounds) { $round in
                            if round.isComplete {
                                NavigationLink {
                                    RoundDetailView(round: $round, account: account) {
                                        editRoundScores(round.id)
                                    } editSetup: {
                                        editRoundSetup(round.id)
                                    } deleteRound: {
                                        deleteRound(round.id)
                                    } saveCompletedHoleEdit: { updatedRound, holeNumber in
                                        saveCompletedHoleEdit(updatedRound, holeNumber)
                                    } playerImageData: { playerName in
                                        account.profileImageData(for: playerName)
                                    }
                                } label: {
                                    RoundSummaryCard(round: round) { playerName in
                                        account.profileImageData(for: playerName)
                                    }
                                }
                                .buttonStyle(.plain)
                            } else {
                                Button {
                                    editRoundScores(round.id)
                                } label: {
                                    RoundSummaryCard(round: round) { playerName in
                                        account.profileImageData(for: playerName)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle(trip.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Menu {
                    Button("Edit Trip") {
                        showEditTrip = true
                    }

                    Button("Delete Trip", role: .destructive) {
                        showFirstTripDeleteConfirmation = true
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }

                ProfileMenuButton(account: account)
            }
        }
        .sheet(isPresented: $showEditTrip) {
            EditTripView(
                trip: trip,
                save: { updatedName, updatedDate in
                    editTrip(updatedName, updatedDate)
                    showEditTrip = false
                },
                cancel: {
                    showEditTrip = false
                }
            )
        }
        .alert("Delete this trip?", isPresented: $showFirstTripDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Continue", role: .destructive) {
                deleteConfirmationText = ""
                showFinalTripDeleteConfirmation = true
            }
        } message: {
            Text("This will remove \(trip.name) and all of its rounds from this device.")
        }
        .alert("Type DELETE to confirm", isPresented: $showFinalTripDeleteConfirmation) {
            TextField("DELETE", text: $deleteConfirmationText)
            Button("Cancel", role: .cancel) {}
            Button("Delete Forever", role: .destructive) {
                guard deleteConfirmationText == "DELETE" else { return }
                deleteTrip()
                dismiss()
            }
            .disabled(deleteConfirmationText != "DELETE")
        } message: {
            Text("This cannot be undone. Type DELETE exactly to remove the trip.")
        }
    }
}
