import SwiftUI

struct GolfAppGameDetailView: View {
    @ObservedObject var account: AccountStore
    @ObservedObject var golfAppStore: GolfAppStore
    let game: GolfAppGame

    @State private var selectedHole = 1

    private var scores: [GolfAppHoleScore] {
        golfAppStore.scores(for: game)
    }

    private var course: CourseCatalogEntry? {
        CourseCatalogEntry.courses.first {
            $0.name.localizedCaseInsensitiveCompare(game.courseName ?? "") == .orderedSame
        }
    }

    private var tee: CourseTee? {
        course?.tees.first { $0.name == game.teeName } ?? course?.defaultTee
    }

    private var slope: Int {
        tee?.slope ?? 113
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                standingsCard
                holePicker
                scoreEntryCard
            }
            .padding()
        }
        .navigationTitle(game.name)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await golfAppStore.refreshScores(for: game, authSession: account.authSession)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(game.format.displayGameFormat)
                .font(.headline)
                .foregroundStyle(.secondary)

            if let courseName = game.courseName {
                Text("\(courseName)\(game.teeName.map { " · \($0)" } ?? "")")
                    .font(.title2.bold())
            }

            Text("Anyone in this game can enter or fix scores for anyone else.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var standingsCard: some View {
        GolfAppStandingsCard(
            playerStandings: playerStandings(),
            teamStandings: teamStandings()
        )
    }

    private var holePicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(1...18, id: \.self) { hole in
                    Button {
                        selectedHole = hole
                    } label: {
                        Text("\(hole)")
                            .font(.caption.bold())
                            .frame(width: 38, height: 34)
                            .background(
                                selectedHole == hole ? Color.green.opacity(0.25) : Color.secondary.opacity(0.12),
                                in: Capsule()
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var scoreEntryCard: some View {
        GolfAppHoleScoreEntryCard(
            game: game,
            hole: course?.holes.first { $0.number == selectedHole },
            selectedHole: selectedHole,
            scoreForPlayer: { player in
                score(for: player, hole: selectedHole)
            },
            save: { player, grossScore in
                Task {
                    await golfAppStore.updateScore(
                        game: game,
                        player: player,
                        holeNumber: selectedHole,
                        grossScore: grossScore,
                        authSession: account.authSession
                    )
                }
            }
        )
    }

    private func score(for player: GolfAppGame.Player, hole: Int) -> Int? {
        scores.first { $0.playerUserID == player.authUserID && $0.holeNumber == hole }?.grossScore
    }

    private func courseHandicap(for player: GolfAppGame.Player) -> Int {
        Int(((player.handicapIndex ?? 0) * Double(slope) / 113.0).rounded())
    }

    private func strokesUsed(for player: GolfAppGame.Player, completedHoles: [Int]) -> Int {
        let handicap = courseHandicap(for: player)
        guard handicap > 0 else { return 0 }

        return completedHoles.reduce(0) { total, holeNumber in
            guard let strokeIndex = course?.holes.first(where: { $0.number == holeNumber })?.strokeIndex else {
                return total
            }
            let baseStroke = strokeIndex <= min(handicap, 18) ? 1 : 0
            let extraStroke = handicap > 18 && strokeIndex <= (handicap - 18) ? 1 : 0
            return total + baseStroke + extraStroke
        }
    }

    private func playerStandings() -> [GolfAppPlayerStanding] {
        game.players
            .map { player in
                let playerScores = scores.filter { $0.playerUserID == player.authUserID }
                let completedHoles = playerScores.map(\.holeNumber)
                let gross = playerScores.map(\.grossScore).reduce(0, +)
                let strokes = strokesUsed(for: player, completedHoles: completedHoles)

                return GolfAppPlayerStanding(
                    player: player,
                    gross: gross,
                    net: gross - strokes,
                    completedHoles: completedHoles.count,
                    courseHandicap: courseHandicap(for: player)
                )
            }
            .sorted {
                if $0.completedHoles != $1.completedHoles { return $0.completedHoles > $1.completedHoles }
                return $0.net < $1.net
            }
    }

    private func teamStandings() -> [GolfAppTeamStanding] {
        var totals: [String: (net: Int, gross: Int)] = [:]

        for standing in playerStandings() {
            guard let teamName = standing.player.teamName, !teamName.isEmpty else { continue }
            let current = totals[teamName] ?? (net: 0, gross: 0)
            totals[teamName] = (
                net: current.net + standing.net,
                gross: current.gross + standing.gross
            )
        }

        return totals
            .map { teamName, total in
                GolfAppTeamStanding(teamName: teamName, net: total.net, gross: total.gross)
            }
            .sorted { $0.net < $1.net }
    }
}

private struct GolfAppPlayerStanding {
    let player: GolfAppGame.Player
    let gross: Int
    let net: Int
    let completedHoles: Int
    let courseHandicap: Int

    var netText: String { completedHoles == 0 ? "—" : "\(net)" }

    var subtitle: String {
        let labels = [player.teamName, player.teeTimeGroup].compactMap { $0 }
        let suffix = labels.isEmpty ? "" : " · \(labels.joined(separator: " · "))"
        return "\(completedHoles) holes · CH \(courseHandicap)\(suffix)"
    }
}

private struct GolfAppTeamStanding {
    let teamName: String
    let net: Int
    let gross: Int

    var netText: String { "Net \(net) · Gross \(gross)" }
}

private struct GolfAppStandingsCard: View {
    let playerStandings: [GolfAppPlayerStanding]
    let teamStandings: [GolfAppTeamStanding]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Live Net Stroke Standings")
                .font(.headline)

            ForEach(Array(playerStandings.enumerated()), id: \.element.player.id) { index, standing in
                GolfAppPlayerStandingRow(rank: index + 1, standing: standing)
            }

            if !teamStandings.isEmpty {
                Divider()
                Text("Teams")
                    .font(.subheadline.bold())
                ForEach(teamStandings, id: \.teamName) { team in
                    GolfAppTeamStandingRow(team: team)
                }
            }
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}

private struct GolfAppPlayerStandingRow: View {
    let rank: Int
    let standing: GolfAppPlayerStanding

    var body: some View {
        HStack {
            Text("\(rank)")
                .font(.caption.bold())
                .frame(width: 24, height: 24)
                .background(Color.green.opacity(0.15), in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(standing.player.displayName)
                    .fontWeight(.semibold)
                Text(standing.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(standing.netText)
                    .font(.headline.monospacedDigit())
                Text("Gross \(standing.gross)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(10)
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
    }
}

private struct GolfAppTeamStandingRow: View {
    let team: GolfAppTeamStanding

    var body: some View {
        HStack {
            Text(team.teamName)
            Spacer()
            Text(team.netText)
                .font(.subheadline.monospacedDigit().bold())
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }
}

private struct GolfAppHoleScoreEntryCard: View {
    let game: GolfAppGame
    let hole: Hole?
    let selectedHole: Int
    let scoreForPlayer: (GolfAppGame.Player) -> Int?
    let save: (GolfAppGame.Player, Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(holeTitle)
                .font(.headline)

            ForEach(game.players) { player in
                GolfAppScoreButtonRow(
                    player: player,
                    currentScore: scoreForPlayer(player),
                    save: { score in save(player, score) }
                )
            }
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private var holeTitle: String {
        guard let hole else { return "Hole \(selectedHole)" }
        return "Hole \(selectedHole) · Par \(hole.par) · HCP \(hole.strokeIndex)"
    }
}

private struct GolfAppScoreButtonRow: View {
    let player: GolfAppGame.Player
    let currentScore: Int?
    let save: (Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(player.displayName)
                    .fontWeight(.semibold)
                Text(playerLabels)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 5), spacing: 6) {
                ForEach(1...10, id: \.self) { score in
                    Button {
                        save(score)
                    } label: {
                        Text("\(score)")
                            .font(.caption.monospacedDigit().bold())
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(
                                currentScore == score ? Color.green.opacity(0.28) : Color.secondary.opacity(0.10),
                                in: RoundedRectangle(cornerRadius: 8)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(10)
        .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
    }

    private var playerLabels: String {
        let labels = [player.teamName, player.teeTimeGroup].compactMap { $0 }
        return labels.isEmpty ? "Individual" : labels.joined(separator: " · ")
    }
}
