import SwiftUI

struct CoursesTabView: View {
    let trips: [GolfTrip]
    @ObservedObject var account: AccountStore
    var showsCotePerformance = true
    @State private var searchText = ""
    @State private var selectedRegion = "All"
    @FocusState private var isSearchFocused: Bool

    private var allRounds: [RoundSummary] {
        trips.flatMap(\.rounds)
    }

    private var regions: [String] {
        ["All"] + Array(Set(CourseCatalogEntry.courses.map(\.courseRegion))).sorted()
    }

    private var summaries: [CoursePerformanceSummary] {
        CourseCatalogEntry.courses.map { course in
            CoursePerformanceSummary(
                course: course,
                rounds: allRounds.filter { CoursePerformanceSummary.matches($0, course: course) }
            )
        }
        .filter { summary in
            let cleanSearch = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            let matchesRegion = selectedRegion == "All" || summary.course.courseRegion == selectedRegion
            let matchesSearch = cleanSearch.isEmpty ||
                summary.course.name.localizedCaseInsensitiveContains(cleanSearch) ||
                summary.course.location.localizedCaseInsensitiveContains(cleanSearch)

            return matchesRegion && matchesSearch
        }
        .sorted {
            if $0.roundCount == $1.roundCount {
                return $0.course.name.localizedCaseInsensitiveCompare($1.course.name) == .orderedAscending
            }
            return $0.roundCount > $1.roundCount
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header

                    TextField("Search courses", text: $searchText)
                        .textInputAutocapitalization(.words)
                        .submitLabel(.done)
                        .textFieldStyle(.roundedBorder)
                        .focused($isSearchFocused)
                        .onSubmit {
                            isSearchFocused = false
                        }

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(regions, id: \.self) { region in
                                Button {
                                    selectedRegion = region
                                } label: {
                                    Text(region)
                                        .font(.caption.weight(.semibold))
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(
                                            selectedRegion == region ? Color.green.opacity(0.2) : Color.secondary.opacity(0.12),
                                            in: Capsule()
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    if summaries.isEmpty {
                        ContentUnavailableView(
                            "No courses found",
                            systemImage: "magnifyingglass",
                            description: Text("Try changing the search or region filter.")
                        )
                    } else {
                        LazyVStack(spacing: 12) {
                            ForEach(summaries) { summary in
                                NavigationLink {
                                    CoursePerformanceDetailView(summary: summary, account: account)
                                } label: {
                                    CoursePerformanceCard(summary: summary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Courses")
            .scrollDismissesKeyboard(.interactively)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    ProfileMenuButton(account: account)
                }

                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        isSearchFocused = false
                    }
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                AppLogoMark(size: 46)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Course Book")
                        .font(.title2.bold())
                    Text(showsCotePerformance ? "Catalog, tee info, and how the boys have played each track." : "Browse courses, tees, yardages, ratings, and slopes.")
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 10) {
                CourseMiniStat(label: "Courses", value: "\(CourseCatalogEntry.courses.count)")
                CourseMiniStat(label: "Played", value: "\(summaries.filter { $0.roundCount > 0 }.count)")
                CourseMiniStat(label: "Rounds", value: "\(allRounds.count)")
            }
        }
    }
}

struct CoursePerformanceCard: View {
    let summary: CoursePerformanceSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: summary.roundCount > 0 ? "flag.checkered.circle.fill" : "map.circle")
                    .font(.title2)
                    .foregroundStyle(summary.roundCount > 0 ? .green : .secondary)

                VStack(alignment: .leading, spacing: 4) {
                    Text(summary.course.name)
                        .font(.headline)
                    Text(summary.course.location)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(summary.roundCount == 0 ? "Not played" : "\(summary.roundCount) round\(summary.roundCount == 1 ? "" : "s")")
                    .font(.caption.bold())
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.secondary.opacity(0.12), in: Capsule())
            }

            if summary.roundCount > 0 {
                HStack(spacing: 10) {
                    CourseMiniStat(label: "Josh/Matt", value: "\(summary.teamOneWins)")
                    CourseMiniStat(label: "Jeff/Shane", value: "\(summary.teamTwoWins)")
                    CourseMiniStat(label: "Ties", value: "\(summary.ties)")
                }

                VStack(alignment: .leading, spacing: 6) {
                    Label(summary.averageGrossText, systemImage: "number.circle")
                    Label(summary.bestGrossText, systemImage: "star.fill")
                    Label(summary.bestNetText, systemImage: "sparkles")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            } else {
                Text("Default tee: \(summary.course.defaultTee.setupName)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
    }
}

struct CoursePerformanceDetailView: View {
    let summary: CoursePerformanceSummary
    @ObservedObject var account: AccountStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                CoursePerformanceCard(summary: summary)
                PlayerCourseBestsCard(summary: summary)

                VStack(alignment: .leading, spacing: 10) {
                    Text("Tees")
                        .font(.headline)

                    ForEach(summary.course.tees) { tee in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(tee.name)
                                    .font(.subheadline.bold())
                                Text("\(tee.yardage) yards · Par \(tee.par)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text("\(tee.rating.formatted(.number.precision(.fractionLength(1)))) / \(tee.slope)")
                                .font(.caption.monospacedDigit().bold())
                                .foregroundStyle(.secondary)
                        }
                        .padding(10)
                        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Rounds Here")
                        .font(.headline)

                    if summary.rounds.isEmpty {
                        ContentUnavailableView(
                            "No rounds here yet",
                            systemImage: "flag",
                            description: Text("Once you play this course, the round cards and performance stats will show up here.")
                        )
                    } else {
                        ForEach(summary.rounds.sorted { $0.date > $1.date }) { round in
                            NavigationLink {
                                CourseRoundReadOnlyDetailView(round: round, account: account)
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
            .padding()
        }
        .navigationTitle(summary.course.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct CourseRoundReadOnlyDetailView: View {
    let round: RoundSummary
    @ObservedObject var account: AccountStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                RoundSummaryCard(round: round) { playerName in
                    account.profileImageData(for: playerName)
                }
                PreviousRoundBreakdownCard(round: round)
                RoundHoleMatrixView(round: round)
            }
            .padding()
        }
        .navigationTitle(round.courseName)
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct PlayerCourseBestsCard: View {
    let summary: CoursePerformanceSummary

    private var bests: [PlayerCourseBest] {
        summary.playerBests
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Player Bests")
                .font(.headline)

            if bests.isEmpty {
                Text("No player scores here yet.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 8) {
                    GridRow {
                        Text("Player").font(.caption.bold())
                        Text("Low Gross").font(.caption.bold())
                        Text("Low Net").font(.caption.bold())
                    }
                    .foregroundStyle(.secondary)

                    ForEach(bests) { best in
                        GridRow {
                            Text(best.name)
                            Text("\(best.bestGross)")
                            Text("\(best.bestNet)")
                        }
                        .font(.subheadline)
                    }
                }
            }
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
    }
}

struct PlayerCourseBest: Identifiable {
    let name: String
    let bestGross: Int
    let bestNet: Int

    var id: String { name }
}

struct CourseMiniStat: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.headline.monospacedDigit())
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
    }
}

struct CoursePerformanceSummary: Identifiable {
    let course: CourseCatalogEntry
    let rounds: [RoundSummary]

    var id: String { course.id }

    var roundCount: Int {
        rounds.count
    }

    var teamOneWins: Int {
        rounds.filter(\.winnerIsJoshMatt).count
    }

    var teamTwoWins: Int {
        rounds.filter(\.winnerIsJeffShane).count
    }

    var ties: Int {
        rounds.filter { $0.winningTeamName == "Tie" }.count
    }

    var averageGrossText: String {
        let grossScores = rounds.flatMap { $0.players.map(\.gross) }
        guard !grossScores.isEmpty else { return "Avg gross —" }
        let average = Double(grossScores.reduce(0, +)) / Double(grossScores.count)
        return "Avg gross \(average.formatted(.number.precision(.fractionLength(1))))"
    }

    var bestGrossText: String {
        guard
            let best = rounds.flatMap({ $0.players }).min(by: { $0.gross < $1.gross })
        else { return "Best gross —" }

        let firstName = best.name.split(separator: " ").first.map(String.init) ?? best.name
        return "Best gross \(best.gross) by \(firstName)"
    }

    var bestNetText: String {
        guard
            let best = rounds.flatMap({ $0.players }).min(by: { $0.net < $1.net })
        else { return "Best net —" }

        let firstName = best.name.split(separator: " ").first.map(String.init) ?? best.name
        return "Best net \(best.net) by \(firstName)"
    }

    var playerBests: [PlayerCourseBest] {
        let grouped = Dictionary(grouping: rounds.flatMap(\.players), by: \.name)
        return grouped.map { name, players in
            PlayerCourseBest(
                name: name,
                bestGross: players.map(\.gross).min() ?? 0,
                bestNet: players.map(\.net).min() ?? 0
            )
        }
        .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    static func matches(_ round: RoundSummary, course: CourseCatalogEntry) -> Bool {
        normalized(round.courseName) == normalized(course.name) ||
            normalized(round.course?.name ?? "") == normalized(course.name)
    }

    private static func normalized(_ name: String) -> String {
        name
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .joined()
    }
}
