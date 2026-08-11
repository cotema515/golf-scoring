import SwiftUI

struct RoundSummaryCard: View {
    let round: RoundSummary
    var holesOverride: [HoleSummary]? = nil
    var playerImageData: (String) -> Data? = { _ in nil }

    private var displayedHoles: [HoleSummary] {
        holesOverride ?? round.holes
    }

    private var displayedPlayers: [PlayerRoundSummary] {
        guard let holesOverride else { return round.players }
        return PreviousRoundCalculator.playerTotals(from: holesOverride)
    }

    private var displayedTeamResult: String {
        guard let holesOverride else { return round.teamResult }
        return PreviousRoundCalculator.resultText(
            for: PreviousRoundCalculator.delta(for: holesOverride, round: round),
            teamOneName: round.teamName(1),
            teamTwoName: round.teamName(2)
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(round.courseName)
                        .font(.headline)
                    HStack(spacing: 6) {
                        Text(round.date, format: .dateTime.month().day().year())

                        if !round.isComplete {
                            RoundStatusBadge(round: round)
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                Spacer()
                Text(displayedTeamResult)
                    .font(.subheadline.bold())
                    .foregroundStyle(.green)
            }

            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 8) {
                GridRow {
                    Text("Player").font(.caption.bold())
                    Text("Strokes").font(.caption.bold())
                    Text("Gross").font(.caption.bold())
                    Text("Net").font(.caption.bold())
                    Text("Stableford").font(.caption.bold())
                }
                .foregroundStyle(.secondary)

                ForEach(displayedPlayers) { player in
                    GridRow {
                        HStack(spacing: 6) {
                            ProfileAvatar(imageData: playerImageData(player.name), size: 24)
                            Text(player.name)
                                .lineLimit(2)
                                .minimumScaleFactor(0.85)
                        }
                        Text("\(player.strokes)")
                        Text("\(player.gross)")
                        Text("\(player.net)")
                        Text("\(player.stableford)")
                    }
                    .font(.subheadline)
                }
            }

            if !displayedHoles.isEmpty {
                Label("Tap for hole-by-hole scores", systemImage: "chevron.right.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
    }
}

struct RoundStatusBadge: View {
    let round: RoundSummary

    var body: some View {
        Label("\(round.completedHoleCount)/\(round.totalHoleCount) incomplete", systemImage: "exclamationmark.circle.fill")
            .labelStyle(.titleAndIcon)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.orange)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.orange.opacity(0.12), in: Capsule())
    }
}

enum PreviousRoundCalculator {
    static let joshMattNames = ["Josh", "Matt"]
    static let shaneJeffNames = ["Shane", "Jeff"]

    static func playerTotals(from holes: [HoleSummary]) -> [PlayerRoundSummary] {
        let names = holes.first?.players.map(\.name) ?? []

        return names.map { name in
            let playerScores = holes.compactMap { hole in
                hole.players.first { $0.name == name }.map { (hole: hole, player: $0) }
            }
            let gross = playerScores.reduce(0) { $0 + $1.player.gross }
            let net = playerScores.reduce(0) { $0 + $1.player.net }
            let stableford = playerScores.reduce(0) {
                $0 + stablefordPoints(net: $1.player.net, par: $1.hole.par)
            }

            return PlayerRoundSummary(
                name: name,
                strokes: gross - net,
                gross: gross,
                net: net,
                stableford: stableford
            )
        }
    }

    static func playerNineTotals(from holes: [HoleSummary], range: ClosedRange<Int>) -> [PlayerRoundSummary] {
        playerTotals(from: holes.filter { range.contains($0.number) })
    }

    static func delta(for holes: [HoleSummary]) -> Int {
        delta(for: holes, teamOneNames: joshMattNames, teamTwoNames: shaneJeffNames)
    }

    static func delta(for holes: [HoleSummary], round: RoundSummary) -> Int {
        delta(
            for: holes,
            teamOneNames: teamPlayerNames(for: 1, round: round),
            teamTwoNames: teamPlayerNames(for: 2, round: round)
        )
    }

    static func delta(for holes: [HoleSummary], teamOneNames: [String], teamTwoNames: [String]) -> Int {
        holes.reduce(0) { total, hole in
            switch winner(for: hole, teamOneNames: teamOneNames, teamTwoNames: teamTwoNames) {
            case 1:
                return total + 1
            case 2:
                return total - 1
            default:
                return total
            }
        }
    }

    static func resultText(for delta: Int) -> String {
        resultText(for: delta, teamOneName: "Josh & Matt", teamTwoName: "Shane & Jeff")
    }

    static func resultText(for delta: Int, teamOneName: String, teamTwoName: String) -> String {
        if delta == 0 { return "Tie" }
        return delta > 0 ? "\(teamOneName) Up \(delta)" : "\(teamTwoName) Up \(abs(delta))"
    }

    static func teamPlayerNames(for team: Int, round: RoundSummary) -> [String] {
        if let golfers = round.golfers {
            let teamNames = golfers
                .filter { $0.team == team }
                .map(\.name)

            if !teamNames.isEmpty {
                return teamNames
            }
        }

        return team == 1 ? joshMattNames : shaneJeffNames
    }

    static func playerName(_ playerName: String, isIn names: [String]) -> Bool {
        let firstName = playerName.split(separator: " ").first.map(String.init) ?? playerName
        return names.contains { name in
            name.localizedCaseInsensitiveCompare(playerName) == .orderedSame ||
            name.localizedCaseInsensitiveCompare(firstName) == .orderedSame
        }
    }

    static func recalculate(_ holes: inout [HoleSummary]) {
        var runningDelta = 0

        for index in holes.indices {
            let winner = winner(for: holes[index])
            switch winner {
            case "JM":
                runningDelta += 1
                holes[index].result = "JM Win"
            case "SJ":
                runningDelta -= 1
                holes[index].result = "SJ Win"
            default:
                holes[index].result = "Tie"
            }
            holes[index].runningTotal = resultText(for: runningDelta)
        }
    }

    static func stablefordPoints(net: Int, par: Int) -> Int {
        switch net - par {
        case ...(-2):
            return 4
        case -1:
            return 2
        case 0:
            return 1
        default:
            return 0
        }
    }

    private static func winner(for hole: HoleSummary) -> String? {
        switch winner(for: hole, teamOneNames: joshMattNames, teamTwoNames: shaneJeffNames) {
        case 1:
            return "JM"
        case 2:
            return "SJ"
        default:
            return nil
        }
    }

    private static func winner(for hole: HoleSummary, teamOneNames: [String], teamTwoNames: [String]) -> Int? {
        guard
            let teamOne = bestNet(for: teamOneNames, on: hole),
            let teamTwo = bestNet(for: teamTwoNames, on: hole),
            teamOne != teamTwo
        else { return nil }

        return teamOne < teamTwo ? 1 : 2
    }

    private static func bestNet(for names: [String], on hole: HoleSummary) -> Int? {
        hole.players
            .filter { playerName($0.name, isIn: names) }
            .map(\.net)
            .min()
    }
}

struct RoundDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var round: RoundSummary
    @ObservedObject var account: AccountStore
    let editScores: () -> Void
    let editSetup: () -> Void
    let deleteRound: () -> Void
    var playerImageData: (String) -> Data? = { _ in nil }
    @State private var showFirstDeleteConfirmation = false
    @State private var showFinalDeleteConfirmation = false
    @State private var deleteConfirmationText = ""

    init(
        round: Binding<RoundSummary>,
        account: AccountStore,
        editScores: @escaping () -> Void,
        editSetup: @escaping () -> Void,
        deleteRound: @escaping () -> Void,
        playerImageData: @escaping (String) -> Data? = { _ in nil }
    ) {
        _round = round
        self.account = account
        self.editScores = editScores
        self.editSetup = editSetup
        self.deleteRound = deleteRound
        self.playerImageData = playerImageData
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if !round.isComplete {
                    IncompleteRoundBanner(round: round)
                }

                RoundSummaryCard(round: round, playerImageData: playerImageData)
                PreviousRoundBreakdownCard(round: round)

                Button(action: editScores) {
                    Label(round.isComplete ? "Edit Scores" : "Continue / Edit Scores", systemImage: "pencil")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Button(action: editSetup) {
                    Label("Edit Course / Handicaps", systemImage: "slider.horizontal.3")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)

                Button(role: .destructive) {
                    showFirstDeleteConfirmation = true
                } label: {
                    Label("Delete Round", systemImage: "trash")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)

                VStack(alignment: .leading, spacing: 12) {
                    Text("Hole-by-Hole")
                        .font(.headline)

                    RoundHoleMatrixView(round: round)
                }
            }
            .padding()
        }
        .navigationTitle(round.courseName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                ProfileMenuButton(account: account)
            }
        }
        .alert("Delete this round?", isPresented: $showFirstDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Continue", role: .destructive) {
                deleteConfirmationText = ""
                showFinalDeleteConfirmation = true
            }
        } message: {
            Text("This will remove \(round.courseName) from \(round.date.formatted(.dateTime.month().day().year())).")
        }
        .alert("Type DELETE to confirm", isPresented: $showFinalDeleteConfirmation) {
            TextField("DELETE", text: $deleteConfirmationText)
            Button("Cancel", role: .cancel) {}
            Button("Delete Forever", role: .destructive) {
                guard deleteConfirmationText == "DELETE" else { return }
                deleteRound()
                dismiss()
            }
            .disabled(deleteConfirmationText != "DELETE")
        } message: {
            Text("This cannot be undone. Type DELETE exactly to remove this round.")
        }
    }
}

private struct IncompleteRoundBanner: View {
    let round: RoundSummary

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)

            VStack(alignment: .leading, spacing: 3) {
                Text("Round incomplete")
                    .font(.headline)
                Text("\(round.completedHoleCount) of \(round.totalHoleCount) holes are complete. Tap Continue / Edit Scores to finish the round.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
    }
}

struct PreviousRoundBreakdownCard: View {
    let round: RoundSummary

    private var holes: [HoleSummary] {
        round.holes
    }

    private var completedHoles: [HoleSummary] {
        holes.filter { round.isHoleComplete($0.number) }
    }

    private var teamOneNames: [String] {
        PreviousRoundCalculator.teamPlayerNames(for: 1, round: round)
    }

    private var teamTwoNames: [String] {
        PreviousRoundCalculator.teamPlayerNames(for: 2, round: round)
    }

    private var frontHoles: [HoleSummary] {
        holes.filter { (1...9).contains($0.number) && round.isHoleComplete($0.number) }
    }

    private var backHoles: [HoleSummary] {
        holes.filter { (10...18).contains($0.number) && round.isHoleComplete($0.number) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Round Scores")
                .font(.headline)

            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 8) {
                GridRow {
                    Text("Side").font(.caption.bold())
                    Text("Match").font(.caption.bold())
                    Text(round.teamName(1).replacingOccurrences(of: " & ", with: "/")).font(.caption.bold())
                    Text(round.teamName(2).replacingOccurrences(of: " & ", with: "/")).font(.caption.bold())
                }
                .foregroundStyle(.secondary)

                scoreRow("Front", holes: frontHoles)
                scoreRow("Back", holes: backHoles)
                scoreRow("Overall", holes: completedHoles)
            }

            Divider()

            ScrollView(.horizontal) {
                Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 8) {
                    GridRow {
                        Text("Player").font(.caption.bold())
                        Text("Front").font(.caption.bold())
                        Text("Back").font(.caption.bold())
                        Text("Total").font(.caption.bold())
                    }
                    .foregroundStyle(.secondary)

                    ForEach(PreviousRoundCalculator.playerTotals(from: completedHoles)) { player in
                        GridRow {
                            Text(player.name)
                            Text(scoreText(for: player.name, holes: frontHoles))
                            Text(scoreText(for: player.name, holes: backHoles))
                            Text("G \(player.gross) / N \(player.net)")
                        }
                        .font(.caption)
                    }
                }
            }
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
    }

    private func scoreRow(_ label: String, holes: [HoleSummary]) -> some View {
        GridRow {
            Text(label)
            Text(PreviousRoundCalculator.resultText(
                for: PreviousRoundCalculator.delta(
                    for: holes,
                    teamOneNames: teamOneNames,
                    teamTwoNames: teamTwoNames
                ),
                teamOneName: round.teamName(1),
                teamTwoName: round.teamName(2)
            ))
                .fontWeight(.semibold)
            Text(teamNetText(names: teamOneNames, holes: holes))
            Text(teamNetText(names: teamTwoNames, holes: holes))
        }
        .font(.caption)
    }

    private func scoreText(for playerName: String, holes: [HoleSummary]) -> String {
        let playerScores = holes.compactMap { hole in
            hole.players.first { $0.name == playerName }
        }
        let gross = playerScores.reduce(0) { $0 + $1.gross }
        let net = playerScores.reduce(0) { $0 + $1.net }
        return "G \(gross) / N \(net)"
    }

    private func teamNetText(names: [String], holes: [HoleSummary]) -> String {
        let net = holes.reduce(0) { total, hole in
            total + (hole.players.filter { PreviousRoundCalculator.playerName($0.name, isIn: names) }.map(\.net).min() ?? 0)
        }
        return "Best net \(net)"
    }
}

struct RoundHoleMatrixView: View {
    let round: RoundSummary

    private var holes: [HoleSummary] {
        round.holes
    }

    private var playerNames: [String] {
        holes.first?.players.map(\.name) ?? []
    }

    private var frontHoles: [HoleSummary] {
        holes.filter { (1...9).contains($0.number) && round.isHoleComplete($0.number) }
    }

    private var backHoles: [HoleSummary] {
        holes.filter { (10...18).contains($0.number) && round.isHoleComplete($0.number) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Gross scores use traditional marks: birdie circles, eagle double-circles, bogey boxes, double bogey+ double-boxes.")
                .font(.caption)
                .foregroundStyle(.secondary)

            VStack(spacing: 8) {
                HStack(alignment: .bottom, spacing: 6) {
                    Text("Hole")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                        .frame(width: 48, alignment: .leading)

                    ForEach(playerNames, id: \.self) { name in
                        Text(shortName(name))
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal, 10)

                ForEach(holes) { hole in
                    holeRow(hole)
                }

                Divider()

                totalRow("Front", holes: frontHoles)
                totalRow("Back", holes: backHoles)
                totalRow("Total", holes: frontHoles + backHoles, isOverall: true)
            }
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
    }

    private func holeRow(_ hole: HoleSummary) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 6) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(hole.number)")
                        .font(.headline.monospacedDigit())
                    Text("P\(hole.par) · H\(hole.strokeIndex)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .frame(width: 48, alignment: .leading)

                ForEach(playerNames, id: \.self) { name in
                    if round.isHoleComplete(hole.number),
                       let player = hole.players.first(where: { $0.name == name }) {
                        playerScoreCell(player: player, par: hole.par)
                    } else {
                        Text("—")
                            .frame(maxWidth: .infinity)
                    }
                }
            }

            HStack(spacing: 8) {
                Text(round.isHoleComplete(hole.number) ? hole.result : "Not saved yet")
                    .font(.caption.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(resultColor(hole.result).opacity(0.16), in: Capsule())
                    .foregroundStyle(resultColor(hole.result))

                Text(round.isHoleComplete(hole.number) ? hole.runningTotal : "Complete all four scores to save this hole")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()
            }
            .padding(.leading, 54)
        }
        .padding(10)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
    }

    private func playerScoreCell(player: PlayerHoleSummary, par: Int) -> some View {
        VStack(spacing: 2) {
            GolfScoreMark(score: player.gross, par: par)
            Text("Net \(player.net)")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text("SF \(stablefordPoints(net: player.net, par: par))")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func totalRow(_ label: String, holes: [HoleSummary], isOverall: Bool = false) -> some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.caption.bold())
                .foregroundStyle(isOverall ? .primary : .secondary)
                .frame(width: 48, alignment: .leading)

                ForEach(playerNames, id: \.self) { name in
                    VStack(spacing: 2) {
                        Text("\(grossTotal(for: name, holes: holes))")
                        .font(.subheadline.monospacedDigit().bold())
                    Text("N \(netTotal(for: name, holes: holes))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, isOverall ? 10 : 6)
        .background(isOverall ? Color.green.opacity(0.12) : Color.clear, in: RoundedRectangle(cornerRadius: 10))
    }

    private func grossTotal(for playerName: String, holes: [HoleSummary]) -> Int {
        holes.reduce(0) { total, hole in
            total + (hole.players.first { $0.name == playerName }?.gross ?? 0)
        }
    }

    private func netTotal(for playerName: String, holes: [HoleSummary]) -> Int {
        holes.reduce(0) { total, hole in
            total + (hole.players.first { $0.name == playerName }?.net ?? 0)
        }
    }

    private func shortName(_ name: String) -> String {
        name.split(separator: " ").first.map(String.init) ?? name
    }

    private func stablefordPoints(net: Int, par: Int) -> Int {
        switch net - par {
        case ...(-2):
            return 4
        case -1:
            return 2
        case 0:
            return 1
        default:
            return 0
        }
    }

    private func resultColor(_ result: String) -> Color {
        if result.contains("JM") || result.localizedCaseInsensitiveContains(round.teamName(1)) {
            return .green
        }
        if result.contains("SJ") || result.localizedCaseInsensitiveContains(round.teamName(2)) {
            return .blue
        }
        return .gray
    }
}

struct GolfScoreMark: View {
    let score: Int
    let par: Int

    private var scoreToPar: Int {
        score - par
    }

    var body: some View {
        ZStack {
            if scoreToPar <= -2 {
                Circle()
                    .stroke(.green, lineWidth: 1.7)
                    .frame(width: 32, height: 32)
                Circle()
                    .stroke(.green, lineWidth: 1.7)
                    .frame(width: 39, height: 39)
            } else if scoreToPar == -1 {
                Circle()
                    .stroke(.green, lineWidth: 1.8)
                    .frame(width: 34, height: 34)
            } else if scoreToPar == 1 {
                RoundedRectangle(cornerRadius: 6)
                    .stroke(.orange, lineWidth: 1.8)
                    .frame(width: 34, height: 34)
            } else if scoreToPar >= 2 {
                RoundedRectangle(cornerRadius: 6)
                    .stroke(.red, lineWidth: 1.7)
                    .frame(width: 32, height: 32)
                RoundedRectangle(cornerRadius: 8)
                    .stroke(.red, lineWidth: 1.7)
                    .frame(width: 39, height: 39)
            }

            Text("\(score)")
                .font(.headline.monospacedDigit().bold())
                .foregroundStyle(markColor)
        }
        .frame(width: 44, height: 42)
        .accessibilityLabel(accessibilityText)
    }

    private var markColor: Color {
        switch scoreToPar {
        case ...(-1):
            return .green
        case 1:
            return .orange
        case 2...:
            return .red
        default:
            return .primary
        }
    }

    private var accessibilityText: String {
        switch scoreToPar {
        case ...(-2):
            return "\(score), eagle or better"
        case -1:
            return "\(score), birdie"
        case 0:
            return "\(score), par"
        case 1:
            return "\(score), bogey"
        default:
            return "\(score), double bogey or worse"
        }
    }
}
