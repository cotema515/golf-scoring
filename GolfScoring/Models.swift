import Foundation
import SwiftUI

struct UserProfile: Codable, Hashable {
    var username: String = ""
    var email: String = ""
    var firstName: String = ""
    var lastName: String = ""
    var ghinNumber: String = ""
    var handicapIndex: Double?
    var profileImageData: Data?
    var profileImagePath: String?
    var profileImageURL: String?
    var playerKey: String?
    var profileType: ProfileType = .general
    var createdAt: Date = Date()

    init(
        username: String = "",
        email: String = "",
        firstName: String = "",
        lastName: String = "",
        ghinNumber: String = "",
        handicapIndex: Double? = nil,
        profileImageData: Data? = nil,
        profileImagePath: String? = nil,
        profileImageURL: String? = nil,
        playerKey: String? = nil,
        profileType: ProfileType = .general,
        createdAt: Date = Date()
    ) {
        self.username = username
        self.email = email
        self.firstName = firstName
        self.lastName = lastName
        self.ghinNumber = ghinNumber
        self.handicapIndex = handicapIndex
        self.profileImageData = profileImageData
        self.profileImagePath = profileImagePath
        self.profileImageURL = profileImageURL
        self.playerKey = playerKey
        self.profileType = profileType
        self.createdAt = createdAt
    }

    enum CodingKeys: String, CodingKey {
        case email
        case username
        case firstName
        case lastName
        case ghinNumber
        case handicapIndex
        case profileImageData
        case profileImagePath
        case profileImageURL
        case playerKey
        case profileType
        case createdAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        email = try container.decodeIfPresent(String.self, forKey: .email) ?? ""
        username = try container.decodeIfPresent(String.self, forKey: .username) ?? ""
        firstName = try container.decodeIfPresent(String.self, forKey: .firstName) ?? ""
        lastName = try container.decodeIfPresent(String.self, forKey: .lastName) ?? ""
        ghinNumber = try container.decodeIfPresent(String.self, forKey: .ghinNumber) ?? ""
        handicapIndex = try container.decodeIfPresent(Double.self, forKey: .handicapIndex)
        profileImageData = try container.decodeIfPresent(Data.self, forKey: .profileImageData)
        profileImagePath = try container.decodeIfPresent(String.self, forKey: .profileImagePath)
        profileImageURL = try container.decodeIfPresent(String.self, forKey: .profileImageURL)
        playerKey = try container.decodeIfPresent(String.self, forKey: .playerKey)
        profileType = try container.decodeIfPresent(ProfileType.self, forKey: .profileType) ?? (playerKey == nil ? .general : .coteCup)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
    }

    var fullName: String {
        "\(firstName) \(lastName)".trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var displayName: String {
        fullName.isEmpty ? "New Golfer" : fullName
    }

    var isCoteCupProfile: Bool {
        profileType == .coteCup || playerKey != nil
    }

    var isComplete: Bool {
        !firstName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !lastName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        handicapIndex != nil
    }
}

enum AppGameMode: String, Codable, Hashable {
    case coteFamily
    case general

    var title: String {
        switch self {
        case .coteFamily:
            return "Cote Family Game"
        case .general:
            return "General Golf"
        }
    }

    var subtitle: String {
        switch self {
        case .coteFamily:
            return "Matt/Josh vs Jeff/Shane history, trips, and match scoring."
        case .general:
            return "Regular golf scoring for rounds outside the family game."
        }
    }
}

enum ProfileType: String, Codable, Hashable, CaseIterable {
    case coteCup
    case general

    var title: String {
        switch self {
        case .coteCup:
            return "Cote Cup"
        case .general:
            return "General Golfer"
        }
    }

    var detail: String {
        switch self {
        case .coteCup:
            return "Linked to the family game and shared Cote Cup history."
        case .general:
            return "A standalone golfer profile for future rounds outside the family game."
        }
    }
}

struct FriendProfile: Identifiable, Codable, Hashable {
    var id = UUID()
    var firstName: String
    var lastName: String
    var handicapIndex: Double
    var profileImageData: Data? = nil
    var profileImagePath: String? = nil
    var profileImageURL: String? = nil
    var playerKey: String? = nil

    var fullName: String {
        "\(firstName) \(lastName)"
    }

}

struct GolfAppUser: Identifiable, Codable, Hashable {
    var authUserID: String
    var username: String
    var email: String
    var firstName: String
    var lastName: String
    var handicapIndex: Double?
    var playerKey: String?
    var profileType: ProfileType
    var isFriend: Bool

    var id: String { authUserID }
    var fullName: String { "\(firstName) \(lastName)".trimmingCharacters(in: .whitespacesAndNewlines) }
    var displayName: String { fullName.isEmpty ? "@\(username)" : fullName }
}

struct GolfAppGame: Identifiable, Codable, Hashable {
    struct Player: Identifiable, Codable, Hashable {
        var authUserID: String
        var displayName: String
        var username: String?
        var handicapIndex: Double?
        var teamName: String?
        var teeTimeGroup: String?

        var id: String { authUserID }
    }

    var id: UUID
    var name: String
    var format: String
    var status: String
    var createdAt: Date
    var courseName: String?
    var courseLocation: String?
    var teeName: String?
    var players: [Player]
}

struct GolfAppHoleScore: Identifiable, Codable, Hashable {
    var gameID: UUID
    var playerUserID: String
    var holeNumber: Int
    var grossScore: Int
    var updatedAt: Date?

    var id: String { "\(gameID.uuidString)-\(playerUserID)-\(holeNumber)" }
}

struct Golfer: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var handicapIndex: Double
    var courseHandicap: Int
    var team: Int
}

struct StablefordStanding: Identifiable, Hashable {
    var golfer: Golfer
    var points: Int

    var id: UUID { golfer.id }
}

struct CourseSetup: Codable, Hashable {
    var name: String = ""
    var tee: String = ""
    var par: Int = 72
    var rating: Double = 72.0
    var slope: Int = 113
    var yardage: Int = 0
}

struct PlayerRoundSummary: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var strokes: Int
    var gross: Int
    var net: Int
    var stableford: Int
}

struct PlayerHoleSummary: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var gross: Int
    var net: Int

    var strokesReceived: Int {
        max(0, gross - net)
    }
}

struct HoleSummary: Identifiable, Codable, Hashable {
    var id = UUID()
    var number: Int
    var par: Int
    var strokeIndex: Int
    var result: String
    var runningTotal: String
    var players: [PlayerHoleSummary]

}

struct RoundSummary: Identifiable, Codable, Hashable {
    var id = UUID()
    var date: Date
    var courseName: String
    var teamResult: String
    var players: [PlayerRoundSummary]
    var holes: [HoleSummary]
    var course: CourseSetup?
    var golfers: [Golfer]?
    var completedHoleNumbers: [Int]?

    init(
        id: UUID = UUID(),
        date: Date,
        courseName: String,
        teamResult: String,
        players: [PlayerRoundSummary],
        holes: [HoleSummary]? = nil,
        course: CourseSetup? = nil,
        golfers: [Golfer]? = nil,
        completedHoleNumbers: [Int]? = nil
    ) {
        self.id = id
        self.date = date
        self.courseName = courseName
        self.teamResult = teamResult
        self.players = players
        self.holes = holes ?? []
        self.course = course
        self.golfers = golfers
        self.completedHoleNumbers = completedHoleNumbers ?? self.holes.map(\.number)
    }

    func isHoleComplete(_ holeNumber: Int) -> Bool {
        completedHoleNumbers?.contains(holeNumber) ?? true
    }

    var completedHoleCount: Int {
        Set(completedHoleNumbers ?? holes.map(\.number)).count
    }

    var totalHoleCount: Int {
        holes.count
    }

    var isComplete: Bool {
        totalHoleCount > 0 && completedHoleCount >= totalHoleCount
    }

    var resolvedTeamResult: String {
        let completedHoles = holes.filter { isHoleComplete($0.number) }
        guard !completedHoles.isEmpty else { return teamResult }
        return PreviousRoundCalculator.matchResultText(
            for: completedHoles,
            round: self,
            teamOneName: teamName(1),
            teamTwoName: teamName(2)
        )
    }

    var winningTeamName: String? {
        let result = resolvedTeamResult
        if let winner = result.components(separatedBy: " Up ").first, winner != result {
            return Self.normalizedTeamName(winner)
        }
        let parts = result.split(separator: " ").map(String.init)
        if parts.count >= 4,
           Int(parts[parts.count - 3]) != nil,
           parts[parts.count - 2] == "&",
           Int(parts[parts.count - 1]) != nil {
            return Self.normalizedTeamName(parts.dropLast(3).joined(separator: " "))
        }
        if result == "Tie" { return "Tie" }
        return nil
    }

    var winnerIsJoshMatt: Bool {
        winningTeamContains(["Josh", "Matt"])
    }

    var winnerIsJeffShane: Bool {
        winningTeamContains(["Jeff", "Shane"])
    }

    private func winningTeamContains(_ names: [String]) -> Bool {
        guard let winningTeamName, winningTeamName != "Tie" else { return false }
        return names.allSatisfy { name in
            winningTeamName.localizedCaseInsensitiveContains(name)
        }
    }

    func teamName(_ team: Int) -> String {
        guard let golfers else {
            switch team {
            case 1: return "Josh & Matt"
            case 2: return "Jeff & Shane"
            default: return "Team \(team)"
            }
        }

        return ScoringEngine.teamName(team, golfers: golfers)
    }

    static func normalizedTeamName(_ name: String) -> String {
        let players = name
            .components(separatedBy: " & ")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard players.count > 1 else { return name }

        return players
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
            .joined(separator: " & ")
    }
}

struct GolfTrip: Identifiable, Codable, Hashable {
    static let joshMattTeamName = "Josh & Matt"
    static let shaneJeffTeamName = "Jeff & Shane"

    var id = UUID()
    var name: String
    var date: Date
    var rounds: [RoundSummary]

    var firstRoundDate: Date? {
        rounds.map(\.date).min()
    }

    var displayDate: Date {
        firstRoundDate ?? date
    }

    var teamOneName: String {
        rounds.compactMap { round in
            round.golfers == nil ? nil : round.teamName(1)
        }.first ?? Self.joshMattTeamName
    }

    var teamTwoName: String {
        rounds.compactMap { round in
            round.golfers == nil ? nil : round.teamName(2)
        }.first ?? Self.shaneJeffTeamName
    }

    var teamOneWins: Int {
        joshMattWins
    }

    var teamTwoWins: Int {
        shaneJeffWins
    }

    var joshMattWins: Int {
        rounds.filter(\.winnerIsJoshMatt).count
    }

    var shaneJeffWins: Int {
        rounds.filter(\.winnerIsJeffShane).count
    }

    var ties: Int {
        rounds.filter { $0.winningTeamName == "Tie" }.count
    }

    var leaderText: String {
        if gamesDelta == 0 { return "All square" }
        if joshMattWins > shaneJeffWins { return "\(Self.joshMattTeamName) +\(joshMattWins - shaneJeffWins)" }
        return "\(Self.shaneJeffTeamName) +\(abs(gamesDelta))"
    }

    var leaderColor: Color {
        if gamesDelta > 0 { return AppColors.joshMatt }
        if gamesDelta < 0 { return AppColors.jeffShane }
        return AppColors.push
    }

    var gamesDelta: Int {
        joshMattWins - shaneJeffWins
    }

    mutating func syncDateToFirstRound() {
        if let firstRoundDate {
            date = firstRoundDate
        }
    }

    mutating func updateTripDetails(name: String, startDate: Date) {
        self.name = name

        guard let firstRoundDate else {
            date = startDate
            return
        }

        let calendar = Calendar.current
        let oldStart = calendar.startOfDay(for: firstRoundDate)
        let newStart = calendar.startOfDay(for: startDate)
        let dayOffset = calendar.dateComponents([.day], from: oldStart, to: newStart).day ?? 0

        if dayOffset != 0 {
            rounds = rounds.map { round in
                var shiftedRound = round
                shiftedRound.date = calendar.date(byAdding: .day, value: dayOffset, to: round.date) ?? round.date
                return shiftedRound
            }
        }

        syncDateToFirstRound()
    }

}

struct Hole: Identifiable, Codable, Hashable {
    var id = UUID()
    let number: Int
    var par: Int
    var strokeIndex: Int
}

struct HoleScore: Codable, Hashable {
    var gross: Int?
}

struct MatchRound: Codable, Hashable {
    var name: String = "Sunday Match"
    var date: Date = Date()
    var course = CourseSetup()
    var golfers: [Golfer]
    var holes: [Hole]
    var scores: [UUID: [Int: HoleScore]] = [:]

    func calculatedCourseHandicap(for handicapIndex: Double) -> Int {
        ScoringEngine.courseHandicap(handicapIndex: handicapIndex, course: course)
    }

    var lowestHandicap: Int { ScoringEngine.lowestCourseHandicap(golfers: golfers) }

    func playingHandicap(for golfer: Golfer) -> Int {
        ScoringEngine.playingHandicap(for: golfer, among: golfers)
    }

    func strokes(for golfer: Golfer, on hole: Hole) -> Int {
        ScoringEngine.strokes(for: golfer, on: hole, among: golfers)
    }

    func netScore(for golfer: Golfer, on hole: Hole) -> Int? {
        guard let gross = scores[golfer.id]?[hole.number]?.gross else { return nil }
        return ScoringEngine.netScore(gross: gross, strokes: strokes(for: golfer, on: hole))
    }

    func stablefordPoints(for golfer: Golfer, on hole: Hole) -> Int? {
        guard let netScore = netScore(for: golfer, on: hole) else { return nil }
        return ScoringEngine.stablefordPoints(netScore: netScore, par: hole.par)
    }

    func stablefordTotal(for golfer: Golfer) -> Int {
        holes.compactMap { stablefordPoints(for: golfer, on: $0) }.reduce(0, +)
    }

    var stablefordStandings: [StablefordStanding] {
        golfers
            .map { StablefordStanding(golfer: $0, points: stablefordTotal(for: $0)) }
            .sorted {
                if $0.points == $1.points {
                    return $0.golfer.name.localizedCaseInsensitiveCompare($1.golfer.name) == .orderedAscending
                }
                return $0.points > $1.points
            }
    }

    func teamBestBall(_ team: Int, on hole: Hole) -> Int? {
        golfers.filter { $0.team == team }.compactMap { netScore(for: $0, on: hole) }.min()
    }

    func holeWinner(on hole: Hole) -> Int? {
        guard
            isHoleComplete(hole),
            let one = teamBestBall(1, on: hole),
            let two = teamBestBall(2, on: hole),
            one != two
        else { return nil }
        return one < two ? 1 : 2
    }

    func isHoleComplete(_ hole: Hole) -> Bool {
        golfers.allSatisfy { scores[$0.id]?[hole.number]?.gross != nil }
    }

    var completedHoles: Int {
        holes.filter(isHoleComplete).count
    }

    var matchDelta: Int {
        matchState(through: nil).delta
    }

    func teamName(_ team: Int) -> String {
        ScoringEngine.teamName(team, golfers: golfers)
    }

    var statusText: String {
        let state = matchState(through: nil)
        if state.delta == 0 { return "ALL SQUARE" }
        let winner = teamName(state.delta > 0 ? 1 : 2).uppercased()
        if state.closedAtHole != nil {
            return "\(winner) · \(abs(state.delta)) & \(state.holesRemaining)"
        }
        return "\(winner) · \(abs(state.delta)) UP"
    }

    func summary(id: UUID = UUID()) -> RoundSummary {
        let holeSummaries = holes.map { hole in
            HoleSummary(
                number: hole.number,
                par: hole.par,
                strokeIndex: hole.strokeIndex,
                result: summaryResult(for: hole),
                runningTotal: runningTotal(through: hole.number),
                players: golfers.map { golfer in
                    let gross = scores[golfer.id]?[hole.number]?.gross ?? 0
                    let net = netScore(for: golfer, on: hole) ?? gross
                    return PlayerHoleSummary(name: golfer.name, gross: gross, net: net)
                }
            )
        }

        return RoundSummary(
            id: id,
            date: date,
            courseName: course.name,
            teamResult: finalResultText(),
            players: golfers.map { golfer in
                let gross = holes.reduce(0) { total, hole in
                    total + (scores[golfer.id]?[hole.number]?.gross ?? 0)
                }
                let net = holes.reduce(0) { total, hole in
                    total + (netScore(for: golfer, on: hole) ?? 0)
                }
                return PlayerRoundSummary(
                    name: golfer.name,
                    strokes: gross - net,
                    gross: gross,
                    net: net,
                    stableford: stablefordTotal(for: golfer)
                )
            },
            holes: holeSummaries,
            course: course,
            golfers: golfers,
            completedHoleNumbers: holes.filter(isHoleComplete).map(\.number)
        )
    }

    private func summaryResult(for hole: Hole) -> String {
        switch holeWinner(on: hole) {
        case 1:
            return teamName(1).contains("Josh") && teamName(1).contains("Matt") ? "JM Win" : "\(teamName(1)) Win"
        case 2:
            return teamName(2).contains("Shane") && teamName(2).contains("Jeff") ? "SJ Win" : "\(teamName(2)) Win"
        default:
            return "Tie"
        }
    }

    private func runningTotal(through holeNumber: Int) -> String {
        let state = matchState(through: holeNumber)
        return summaryResultText(for: state.delta, closedAtHole: state.closedAtHole, holesRemaining: state.holesRemaining)
    }

    private func finalResultText() -> String {
        let state = matchState(through: nil)
        return summaryResultText(for: state.delta, closedAtHole: state.closedAtHole, holesRemaining: state.holesRemaining)
    }

    private func summaryResultText(for delta: Int, closedAtHole: Int? = nil, holesRemaining: Int? = nil) -> String {
        if delta == 0 { return "Tie" }
        let winner = delta > 0 ? teamName(1) : teamName(2)
        if closedAtHole != nil, let holesRemaining {
            return "\(winner) \(abs(delta)) & \(holesRemaining)"
        }
        return "\(winner) Up \(abs(delta))"
    }

    private func matchState(through holeNumber: Int?) -> (delta: Int, closedAtHole: Int?, holesRemaining: Int) {
        let sortedHoles = holes.sorted { $0.number < $1.number }
        let totalHoles = sortedHoles.count
        var delta = 0
        var playedCount = 0

        for (index, hole) in sortedHoles.enumerated() {
            if let holeNumber, hole.number > holeNumber { break }
            guard isHoleComplete(hole) else { break }
            playedCount += 1

            switch holeWinner(on: hole) {
            case 1:
                delta += 1
            case 2:
                delta -= 1
            default:
                break
            }

            let holesRemaining = max(0, totalHoles - index - 1)
            if holesRemaining > 0, abs(delta) > holesRemaining {
                return (delta, hole.number, holesRemaining)
            }
        }

        return (delta, nil, max(0, totalHoles - playedCount))
    }
}

extension MatchRound {
    static var empty: MatchRound {
        MatchRound(
            name: "New Match",
            golfers: [
                Golfer(name: "Player 1", handicapIndex: 0, courseHandicap: 0, team: 1),
                Golfer(name: "Player 2", handicapIndex: 0, courseHandicap: 0, team: 1),
                Golfer(name: "Player 3", handicapIndex: 0, courseHandicap: 0, team: 2),
                Golfer(name: "Player 4", handicapIndex: 0, courseHandicap: 0, team: 2)
            ],
            holes: CourseCatalogEntry.courses.first?.holes ?? (1...18).map {
                Hole(number: $0, par: 4, strokeIndex: $0)
            }
        )
    }
}
