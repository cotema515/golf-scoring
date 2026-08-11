import Foundation

enum ScoringEngine {
    static func courseHandicap(handicapIndex: Double, course: CourseSetup) -> Int {
        Int((handicapIndex * (Double(course.slope) / 113.0) + (course.rating - Double(course.par))).rounded())
    }

    static func lowestCourseHandicap(golfers: [Golfer]) -> Int {
        golfers.map(\.courseHandicap).min() ?? 0
    }

    static func playingHandicap(for golfer: Golfer, among golfers: [Golfer]) -> Int {
        max(0, golfer.courseHandicap - lowestCourseHandicap(golfers: golfers))
    }

    static func strokes(for golfer: Golfer, on hole: Hole, among golfers: [Golfer]) -> Int {
        let allowance = playingHandicap(for: golfer, among: golfers)
        guard allowance > 0 else { return 0 }
        return allowance / 18 + (hole.strokeIndex <= allowance % 18 ? 1 : 0)
    }

    static func netScore(gross: Int, strokes: Int) -> Int {
        gross - strokes
    }

    static func stablefordPoints(netScore: Int, par: Int) -> Int {
        switch netScore - par {
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

    static func teamName(_ team: Int, golfers: [Golfer]) -> String {
        let players = golfers
            .filter { $0.team == team }
            .map(PlayerNameParts.init)

        guard !players.isEmpty else { return "Team \(team)" }

        let displayNames = players
            .map { player in
                player.displayName(disambiguatedAmong: players)
            }
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }

        return displayNames.joined(separator: " & ")
    }
}

private struct PlayerNameParts {
    let first: String
    let last: String
    let fallback: String

    init(golfer: Golfer) {
        let parts = golfer.name
            .split(separator: " ")
            .map(String.init)

        first = parts.first ?? golfer.name
        last = parts.dropFirst().joined(separator: " ")
        fallback = golfer.name
    }

    func displayName(disambiguatedAmong players: [PlayerNameParts]) -> String {
        let matchingFirstNames = players.filter {
            $0.first.localizedCaseInsensitiveCompare(first) == .orderedSame
        }

        guard matchingFirstNames.count > 1, !last.isEmpty else {
            return first.isEmpty ? fallback : first
        }

        for prefixLength in 1...last.count {
            let prefix = String(last.prefix(prefixLength))
            let matchingPrefixes = matchingFirstNames.filter {
                !$0.last.isEmpty &&
                String($0.last.prefix(prefixLength)).localizedCaseInsensitiveCompare(prefix) == .orderedSame
            }

            if matchingPrefixes.count == 1 {
                return "\(first) \(prefix)."
            }
        }

        return "\(first) \(last)"
    }
}
