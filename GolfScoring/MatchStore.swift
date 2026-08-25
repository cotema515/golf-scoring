import Foundation

@MainActor
final class MatchStore: ObservableObject {
    @Published var round = MatchRound.empty

    func resetRound() {
        round = MatchRound.empty
    }

    func loadRound(_ summary: RoundSummary) {
        let course = summary.course ?? inferredCourse(for: summary)
        let golfers = (summary.golfers ?? inferredGolfers(for: summary)).map { golfer in
            var normalizedGolfer = golfer
            if let familyTeam = ScoringEngine.familyTeam(for: golfer.name) {
                normalizedGolfer.team = familyTeam
            }
            return normalizedGolfer
        }
        var scores: [UUID: [Int: HoleScore]] = [:]

        for golfer in golfers {
            var playerScores: [Int: HoleScore] = [:]
            for hole in summary.holes {
                guard summary.isHoleComplete(hole.number) else { continue }
                if let player = hole.players.first(where: { $0.name == golfer.name }) {
                    playerScores[hole.number] = HoleScore(gross: player.gross)
                }
            }
            scores[golfer.id] = playerScores
        }

        round = MatchRound(
            name: "\(summary.courseName) · \(summary.date.formatted(.dateTime.month(.abbreviated).day().year()))",
            date: summary.date,
            course: course,
            golfers: golfers,
            holes: CourseCatalogLookup.canonicalHoles(
                for: course.name.isEmpty ? summary.courseName : course.name,
                fallback: summary.holes.map { Hole(number: $0.number, par: $0.par, strokeIndex: $0.strokeIndex) }
            ),
            scores: scores
        )
    }

    func setScore(_ score: Int?, golferID: UUID, holeNumber: Int) {
        var playerScores = round.scores[golferID, default: [:]]
        playerScores[holeNumber] = HoleScore(gross: score)
        round.scores[golferID] = playerScores
    }

    private func inferredCourse(for summary: RoundSummary) -> CourseSetup {
        if let catalogCourse = CourseCatalogLookup.course(for: summary.courseName) {
            return catalogCourse.setup(for: catalogCourse.defaultTee)
        }

        let par = summary.holes.reduce(0) { $0 + $1.par }
        return CourseSetup(name: summary.courseName, tee: "Saved", par: par > 0 ? par : 72)
    }

    private func inferredGolfers(for summary: RoundSummary) -> [Golfer] {
        summary.players.enumerated().map { index, player in
            let team = ScoringEngine.familyTeam(for: player.name) ?? (index < 2 ? 1 : 2)
            return Golfer(
                name: player.name,
                handicapIndex: 0,
                courseHandicap: player.strokes,
                team: team
            )
        }
    }
}
