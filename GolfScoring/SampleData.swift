import Foundation

extension FriendProfile {
    static let coteGroupPlayers = [
        FriendProfile(firstName: "Matt", lastName: "Cote", handicapIndex: 9.4, playerKey: "matt"),
        FriendProfile(firstName: "Josh", lastName: "Cote", handicapIndex: 13.0, playerKey: "josh"),
        FriendProfile(firstName: "Shane", lastName: "Cote", handicapIndex: 9.0, playerKey: "shane"),
        FriendProfile(firstName: "Jeff", lastName: "Cote", handicapIndex: 18.7, playerKey: "jeff")
    ]

    static let dummyFriends = coteGroupPlayers.filter { $0.firstName != "Matt" }

    static func groupPlayers(excluding profile: UserProfile) -> [FriendProfile] {
        let currentFirstName = profile.firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        let currentLastName = profile.lastName.trimmingCharacters(in: .whitespacesAndNewlines)

        return coteGroupPlayers.filter { player in
            !(player.firstName.localizedCaseInsensitiveCompare(currentFirstName) == .orderedSame &&
              player.lastName.localizedCaseInsensitiveCompare(currentLastName) == .orderedSame)
        }
    }

    func matches(_ other: FriendProfile) -> Bool {
        if let playerKey, let otherKey = other.playerKey, !playerKey.isEmpty, !otherKey.isEmpty {
            return playerKey == otherKey
        }

        return firstName.localizedCaseInsensitiveCompare(other.firstName) == .orderedSame &&
        lastName.localizedCaseInsensitiveCompare(other.lastName) == .orderedSame
    }

    func matches(_ profile: UserProfile) -> Bool {
        if let playerKey, let profileKey = profile.playerKey, !playerKey.isEmpty, !profileKey.isEmpty {
            return playerKey == profileKey
        }

        return firstName.localizedCaseInsensitiveCompare(profile.firstName) == .orderedSame &&
        lastName.localizedCaseInsensitiveCompare(profile.lastName) == .orderedSame
    }

    func withInferredPlayerKey() -> FriendProfile {
        guard playerKey == nil || playerKey?.isEmpty == true else { return self }
        var copy = self
        copy.playerKey = Self.inferredPlayerKey(firstName: firstName, lastName: lastName)
        return copy
    }

    static func inferredPlayerKey(firstName: String, lastName: String) -> String? {
        guard lastName.localizedCaseInsensitiveCompare("Cote") == .orderedSame else { return nil }
        switch firstName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "matt":
            return "matt"
        case "josh":
            return "josh"
        case "shane":
            return "shane"
        case "jeff", "dad":
            return "jeff"
        default:
            return nil
        }
    }
}

extension HoleSummary {
    static func sampleHoles(for courseName: String) -> [HoleSummary] {
        SampleRoundBuilder.bandonRounds.first { $0.courseName == courseName }?.holes ?? []
    }
}

extension GolfTrip {
    static var sampleTrips: [GolfTrip] {
        [
            GolfTrip(
                name: "Bandon",
                date: SampleRoundBuilder.date(2025, 8, 13),
                rounds: SampleRoundBuilder.bandonRounds
            )
        ]
    }

    static func mergedWithCurrentSamples(_ trips: [GolfTrip]) -> [GolfTrip] {
        guard !trips.isEmpty else { return sampleTrips }

        var mergedTrips = trips.map { trip in
            var normalizedTrip = trip
            normalizedTrip.rounds = trip.rounds.map { round in
                var normalizedRound = round
                normalizedRound.normalizeSampleCourseNames()
                return normalizedRound
            }
            normalizedTrip.syncDateToFirstRound()
            return normalizedTrip
        }

        for sampleTrip in sampleTrips {
            if let existingTripIndex = mergedTrips.firstIndex(where: { $0.name == sampleTrip.name }) {
                for sampleRound in sampleTrip.rounds {
                    if let existingRoundIndex = mergedTrips[existingTripIndex].rounds.sampleEquivalentIndex(to: sampleRound) {
                        mergedTrips[existingTripIndex].rounds[existingRoundIndex] = sampleRound
                    } else {
                        mergedTrips[existingTripIndex].rounds.append(sampleRound)
                    }
                }
                mergedTrips[existingTripIndex].syncDateToFirstRound()
            }
        }

        return mergedTrips
    }
}

extension MatchRound {
    static var sample: MatchRound {
        MatchRound(
            golfers: [
                Golfer(name: "Player 1", handicapIndex: 0, courseHandicap: 0, team: 1),
                Golfer(name: "Player 2", handicapIndex: 0, courseHandicap: 0, team: 1),
                Golfer(name: "Player 3", handicapIndex: 0, courseHandicap: 0, team: 2),
                Golfer(name: "Player 4", handicapIndex: 0, courseHandicap: 0, team: 2)
            ],
            holes: CourseCatalogEntry.courses.first?.holes ?? (1...18).map { Hole(number: $0, par: 4, strokeIndex: $0) }
        )
    }
}

private extension Array where Element == RoundSummary {
    func containsSampleEquivalent(to sampleRound: RoundSummary) -> Bool {
        sampleEquivalentIndex(to: sampleRound) != nil
    }

    func sampleEquivalentIndex(to sampleRound: RoundSummary) -> Int? {
        firstIndex { round in
            round.normalizedSampleCourseName == sampleRound.normalizedSampleCourseName &&
            Calendar.current.isDate(round.date, inSameDayAs: sampleRound.date)
        }
    }
}

private extension RoundSummary {
    var normalizedSampleCourseName: String {
        if courseName.hasPrefix("Pacific Dunes") {
            return "Pacific Dunes"
        }
        return courseName
    }

    mutating func normalizeSampleCourseNames() {
        if courseName.hasPrefix("Pacific Dunes") {
            courseName = "Pacific Dunes"
        }
        if course?.name.hasPrefix("Pacific Dunes") == true {
            course?.name = "Pacific Dunes"
        }
    }
}

private enum SampleRoundBuilder {
    static var bandonRounds: [RoundSummary] {
        seeds.map(buildRound)
    }

    static func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        Calendar.current.date(from: DateComponents(year: year, month: month, day: day)) ?? Date()
    }

    private static let seeds: [RoundSeed] = [
        RoundSeed(
            courseName: "Bandon Trails",
            sourceCourseName: "Bandon Trails",
            date: date(2025, 8, 13),
            playingStrokes: ["Josh": 8, "Matt": 3, "Shane": 0, "Jeff": 12],
            pars: [4, 3, 5, 4, 3, 4, 4, 4, 5, 4, 4, 3, 4, 4, 4, 5, 3, 4],
            strokeIndexes: [13, 17, 3, 5, 15, 9, 7, 11, 1, 10, 4, 18, 12, 14, 8, 2, 16, 6],
            grossScores: [
                "Josh": [7, 3, 5, 4, 3, 4, 6, 5, 5, 6, 6, 5, 6, 5, 6, 8, 3, 4],
                "Matt": [5, 4, 6, 3, 3, 5, 6, 5, 5, 5, 5, 4, 4, 4, 5, 8, 5, 4],
                "Shane": [4, 4, 5, 5, 4, 5, 5, 4, 5, 6, 5, 4, 4, 6, 6, 6, 4, 6],
                "Jeff": [6, 4, 7, 6, 3, 5, 7, 6, 5, 6, 5, 4, 5, 4, 7, 7, 4, 5]
            ]
        ),
        RoundSeed(
            courseName: "Bandon Dunes",
            sourceCourseName: "Bandon Dunes",
            date: date(2025, 8, 13),
            playingStrokes: ["Josh": 8, "Matt": 3, "Shane": 0, "Jeff": 11],
            pars: [4, 3, 5, 4, 4, 3, 4, 4, 5, 4, 4, 3, 5, 4, 3, 4, 4, 5],
            strokeIndexes: [13, 15, 3, 5, 1, 17, 7, 11, 9, 8, 2, 18, 6, 16, 14, 10, 12, 4],
            grossScores: [
                "Josh": [3, 5, 6, 6, 6, 4, 3, 4, 5, 7, 5, 3, 5, 4, 3, 4, 6, 6],
                "Matt": [5, 3, 4, 6, 6, 6, 4, 4, 5, 5, 4, 5, 6, 4, 4, 5, 3, 6],
                "Shane": [4, 4, 6, 6, 5, 3, 4, 5, 5, 4, 5, 5, 4, 5, 5, 4, 6, 4],
                "Jeff": [5, 4, 6, 6, 5, 6, 4, 4, 6, 5, 5, 4, 6, 5, 4, 4, 4, 7]
            ]
        ),
        RoundSeed(
            courseName: "Pacific Dunes",
            sourceCourseName: "Pacific Dunes",
            date: date(2025, 8, 14),
            playingStrokes: ["Josh": 8, "Matt": 3, "Shane": 0, "Jeff": 11],
            pars: [4, 4, 5, 4, 3, 4, 4, 4, 4, 3, 3, 5, 4, 3, 5, 4, 3, 5],
            strokeIndexes: [9, 11, 7, 3, 17, 13, 1, 5, 15, 14, 18, 6, 2, 16, 10, 12, 8, 4],
            grossScores: [
                "Josh": [4, 7, 8, 6, 3, 5, 7, 6, 5, 4, 3, 7, 6, 3, 5, 5, 5, 7],
                "Matt": [4, 4, 7, 5, 3, 4, 5, 5, 4, 3, 3, 5, 6, 3, 5, 5, 4, 5],
                "Shane": [5, 5, 7, 4, 2, 5, 6, 4, 6, 4, 4, 6, 5, 4, 5, 4, 4, 5],
                "Jeff": [6, 5, 7, 6, 3, 5, 6, 5, 6, 3, 4, 7, 5, 4, 7, 4, 4, 7]
            ]
        ),
        RoundSeed(
            courseName: "Sheep Ranch",
            sourceCourseName: "Sheep Ranch",
            date: date(2025, 8, 15),
            playingStrokes: ["Josh": 6, "Matt": 2, "Shane": 0, "Jeff": 9],
            pars: [5, 4, 3, 4, 3, 4, 3, 4, 4, 4, 5, 4, 5, 4, 4, 3, 4, 5],
            strokeIndexes: [5, 13, 17, 3, 11, 1, 15, 7, 9, 6, 4, 2, 10, 8, 14, 16, 12, 18],
            grossScores: [
                "Josh": [5, 5, 4, 6, 3, 6, 3, 5, 6, 5, 5, 5, 6, 4, 4, 3, 4, 7],
                "Matt": [5, 7, 2, 6, 3, 5, 4, 4, 5, 5, 4, 5, 6, 4, 4, 3, 4, 5],
                "Shane": [6, 6, 3, 4, 2, 5, 4, 4, 3, 5, 6, 5, 6, 5, 4, 4, 4, 5],
                "Jeff": [5, 5, 3, 6, 4, 5, 4, 5, 7, 5, 6, 5, 6, 6, 4, 4, 5, 5]
            ]
        ),
        RoundSeed(
            courseName: "Old MacDonald",
            sourceCourseName: "Old Macdonald",
            date: date(2025, 8, 16),
            playingStrokes: ["Josh": 7, "Matt": 3, "Shane": 0, "Jeff": 10],
            pars: [4, 3, 4, 4, 3, 5, 4, 3, 4, 4, 4, 3, 4, 4, 5, 4, 5, 4],
            strokeIndexes: [11, 15, 9, 1, 17, 3, 5, 13, 7, 6, 4, 16, 18, 14, 12, 2, 10, 8],
            grossScores: [
                "Josh": [4, 3, 4, 6, 3, 7, 4, 4, 5, 5, 6, 4, 4, 4, 5, 5, 6, 5],
                "Matt": [6, 3, 6, 4, 3, 6, 4, 3, 3, 5, 5, 5, 5, 4, 7, 5, 7, 5],
                "Shane": [3, 4, 4, 5, 3, 6, 4, 4, 3, 4, 4, 3, 4, 4, 5, 5, 7, 4],
                "Jeff": [5, 4, 4, 5, 5, 5, 6, 3, 6, 5, 5, 3, 4, 4, 6, 6, 5, 5]
            ]
        ),
        RoundSeed(
            courseName: "Pacific Dunes",
            sourceCourseName: "Pacific Dunes",
            date: date(2025, 8, 16),
            playingStrokes: ["Josh": 8, "Matt": 3, "Shane": 0, "Jeff": 11],
            pars: [4, 4, 5, 4, 3, 4, 4, 4, 4, 3, 3, 5, 4, 3, 5, 4, 3, 5],
            strokeIndexes: [9, 11, 7, 3, 17, 13, 1, 5, 15, 14, 18, 6, 2, 16, 10, 12, 8, 4],
            grossScores: [
                "Josh": [6, 5, 7, 7, 3, 7, 6, 5, 5, 6, 4, 5, 6, 5, 7, 5, 5, 6],
                "Matt": [4, 3, 6, 5, 4, 3, 5, 3, 4, 4, 4, 4, 4, 3, 5, 5, 3, 6],
                "Shane": [6, 4, 5, 7, 4, 3, 4, 5, 5, 3, 4, 6, 4, 3, 6, 4, 3, 6],
                "Jeff": [5, 5, 7, 5, 4, 5, 6, 7, 5, 4, 3, 7, 7, 5, 6, 5, 5, 7]
            ]
        )
    ]

    private static func buildRound(from seed: RoundSeed) -> RoundSummary {
        let catalogCourse = CourseCatalogEntry.courses.first {
            $0.name.localizedCaseInsensitiveCompare(seed.sourceCourseName) == .orderedSame
        } ?? CourseCatalogEntry(
            id: seed.sourceCourseName.lowercased().replacingOccurrences(of: " ", with: "-"),
            name: seed.sourceCourseName,
            location: "Bandon, OR",
            tees: [
                CourseTee(
                    name: "Standard",
                    par: seed.par,
                    rating: Double(seed.par),
                    slope: 113,
                    yardage: 6300
                )
            ],
            holes: zip(seed.pars, seed.strokeIndexes).enumerated().map { index, values in
                Hole(number: index + 1, par: values.0, strokeIndex: values.1)
            }
        )
        let tee = teeClosestTo6300Yards(for: catalogCourse)
        let course = catalogCourse.setup(for: tee)
        let golfers = golfers(for: seed, course: course)
        var match = MatchRound(
            name: "\(seed.courseName) · \(seed.date.formatted(.dateTime.month(.abbreviated).day().year()))",
            date: seed.date,
            course: CourseSetup(name: seed.courseName, tee: course.tee, par: seed.par, rating: course.rating, slope: course.slope, yardage: course.yardage),
            golfers: golfers,
            holes: seed.holes
        )

        for golfer in golfers {
            let firstName = golfer.name.components(separatedBy: " ").first ?? golfer.name
            for (index, gross) in (seed.grossScores[firstName] ?? []).enumerated() {
                match.setSampleScore(gross, golferID: golfer.id, holeNumber: index + 1)
            }
        }

        return match.summary()
    }

    private static func teeClosestTo6300Yards(for course: CourseCatalogEntry) -> CourseTee {
        course.tees.min {
            abs($0.yardage - 6_300) < abs($1.yardage - 6_300)
        } ?? course.defaultTee
    }

    private static func golfers(for seed: RoundSeed, course: CourseSetup) -> [Golfer] {
        let shaneCourseHandicap = 9
        let players = [
            ("Josh Cote", "Josh", 1),
            ("Matt Cote", "Matt", 1),
            ("Shane Cote", "Shane", 2),
            ("Jeff Cote", "Jeff", 2)
        ]

        return players.map { fullName, firstName, team in
            let courseHandicap = shaneCourseHandicap + (seed.playingStrokes[firstName] ?? 0)
            return Golfer(
                name: fullName,
                handicapIndex: handicapIndex(forCourseHandicap: courseHandicap, course: course),
                courseHandicap: courseHandicap,
                team: team
            )
        }
    }

    private static func handicapIndex(forCourseHandicap courseHandicap: Int, course: CourseSetup) -> Double {
        let rawIndex = (Double(courseHandicap) - (course.rating - Double(course.par))) * 113.0 / Double(course.slope)
        return (rawIndex * 10).rounded() / 10
    }
}

private struct RoundSeed {
    var courseName: String
    var sourceCourseName: String
    var date: Date
    var playingStrokes: [String: Int]
    var pars: [Int]
    var strokeIndexes: [Int]
    var grossScores: [String: [Int]]

    var par: Int {
        pars.reduce(0, +)
    }

    var holes: [Hole] {
        zip(pars, strokeIndexes).enumerated().map { index, values in
            Hole(number: index + 1, par: values.0, strokeIndex: values.1)
        }
    }
}

private extension MatchRound {
    mutating func setSampleScore(_ score: Int, golferID: UUID, holeNumber: Int) {
        var playerScores = scores[golferID, default: [:]]
        playerScores[holeNumber] = HoleScore(gross: score)
        scores[golferID] = playerScores
    }
}
