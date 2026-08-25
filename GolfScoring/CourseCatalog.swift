import Foundation

struct CourseTee: Identifiable, Hashable {
    var id: String { name }
    var name: String
    var par: Int
    var rating: Double
    var slope: Int
    var yardage: Int

    var isWomensTee: Bool {
        let normalizedName = name.lowercased()
        return normalizedName.contains("women")
            || normalizedName.contains("(w)")
            || normalizedName.contains("(f)")
            || normalizedName.contains("(l)")
    }

    var setupName: String {
        "\(name) · \(yardage) yds · \(rating.formatted(.number.precision(.fractionLength(1)))) / \(slope)"
    }
}

struct CourseCatalogEntry: Identifiable, Hashable {
    var id: String
    var name: String
    var location: String
    var tees: [CourseTee]
    var holes: [Hole]

    var defaultTee: CourseTee {
        let fallback = tees.first ?? CourseTee(name: "Default", par: 72, rating: 72.0, slope: 113, yardage: 0)
        let playableTees = tees.filter { $0.yardage > 0 }
        let preferredRange = playableTees.filter { (6300...6500).contains($0.yardage) }
        let candidates = preferredRange.isEmpty ? playableTees : preferredRange

        return candidates.min { lhs, rhs in
            let lhsWomenPenalty = lhs.isWomensTee ? 1 : 0
            let rhsWomenPenalty = rhs.isWomensTee ? 1 : 0
            if lhsWomenPenalty != rhsWomenPenalty {
                return lhsWomenPenalty < rhsWomenPenalty
            }

            let lhsDistance = abs(lhs.yardage - 6400)
            let rhsDistance = abs(rhs.yardage - 6400)
            if lhsDistance != rhsDistance {
                return lhsDistance < rhsDistance
            }

            return lhs.yardage > rhs.yardage
        } ?? fallback
    }

    func tee(named teeName: String) -> CourseTee {
        tees.first { $0.name == teeName } ?? defaultTee
    }

    func setup(for tee: CourseTee) -> CourseSetup {
        CourseSetup(name: name, tee: tee.name, par: tee.par, rating: tee.rating, slope: tee.slope, yardage: tee.yardage)
    }

    static let courses: [CourseCatalogEntry] = kiawahCourses + bandonCourses + streamsongCourses + floridaCourses + northeastCourses + midwestCourses

    static let kiawahCourses: [CourseCatalogEntry] = [
        CourseCatalogEntry(
            id: "kiawah-ocean",
            name: "The Ocean Course",
            location: "Kiawah Island, SC",
            tees: [
                CourseTee(name: "Championship", par: 72, rating: 79.1, slope: 155, yardage: 7772),
                CourseTee(name: "Black", par: 72, rating: 77.4, slope: 153, yardage: 7385),
                CourseTee(name: "Gold", par: 72, rating: 74.7, slope: 150, yardage: 6793),
                CourseTee(name: "Silver", par: 72, rating: 72.1, slope: 140, yardage: 6356),
                CourseTee(name: "Blue", par: 72, rating: 70.5, slope: 131, yardage: 6005),
                CourseTee(name: "Blue / Red", par: 72, rating: 68.9, slope: 129, yardage: 5702),
                CourseTee(name: "Red", par: 72, rating: 66.5, slope: 120, yardage: 5226),
                CourseTee(name: "Silver (Women)", par: 72, rating: 78.9, slope: 151, yardage: 6356),
                CourseTee(name: "Blue (Women)", par: 72, rating: 76.9, slope: 147, yardage: 6005),
                CourseTee(name: "Blue / Red (Women)", par: 72, rating: 75.4, slope: 137, yardage: 5702),
                CourseTee(name: "Red (Women)", par: 72, rating: 72.6, slope: 130, yardage: 5226)
            ],
            holes: makeHoles(
                pars: [4, 5, 4, 4, 3, 4, 5, 3, 4, 4, 5, 4, 4, 3, 4, 5, 3, 4],
                strokeIndexes: [15, 3, 9, 1, 11, 13, 7, 17, 5, 16, 8, 10, 2, 14, 18, 4, 12, 6]
            )
        ),
        CourseCatalogEntry(
            id: "kiawah-turtle",
            name: "Turtle Point",
            location: "Kiawah Island, SC",
            tees: [
                CourseTee(name: "Black", par: 72, rating: 73.9, slope: 141, yardage: 6911),
                CourseTee(name: "Gold", par: 72, rating: 71.9, slope: 136, yardage: 6510),
                CourseTee(name: "Silver", par: 72, rating: 70.1, slope: 127, yardage: 6162),
                CourseTee(name: "Blue", par: 72, rating: 67.3, slope: 117, yardage: 5746),
                CourseTee(name: "Blue / Red", par: 72, rating: 65.4, slope: 113, yardage: 5310),
                CourseTee(name: "Red", par: 72, rating: 64.3, slope: 112, yardage: 5064),
                CourseTee(name: "Silver (Women)", par: 72, rating: 75.8, slope: 144, yardage: 6162),
                CourseTee(name: "Blue (Women)", par: 72, rating: 72.2, slope: 134, yardage: 5746),
                CourseTee(name: "Blue / Red (Women)", par: 72, rating: 70.2, slope: 127, yardage: 5310),
                CourseTee(name: "Red (Women)", par: 72, rating: 68.7, slope: 125, yardage: 5064)
            ],
            holes: makeHoles(
                pars: [4, 5, 4, 3, 5, 4, 3, 4, 4, 5, 4, 4, 5, 3, 4, 3, 4, 4],
                strokeIndexes: [9, 5, 15, 13, 7, 11, 17, 1, 3, 12, 6, 4, 10, 16, 8, 14, 18, 2]
            )
        ),
        CourseCatalogEntry(
            id: "kiawah-cougar",
            name: "Cougar Point",
            location: "Kiawah Island, SC",
            tees: [
                CourseTee(name: "Black", par: 72, rating: 72.7, slope: 138, yardage: 6620),
                CourseTee(name: "Gold", par: 72, rating: 71.0, slope: 133, yardage: 6205),
                CourseTee(name: "Silver", par: 72, rating: 69.0, slope: 127, yardage: 5806),
                CourseTee(name: "Silver / Blue", par: 72, rating: 67.6, slope: 125, yardage: 5559),
                CourseTee(name: "Blue", par: 72, rating: 66.7, slope: 118, yardage: 5356),
                CourseTee(name: "Blue / Red", par: 72, rating: 64.9, slope: 114, yardage: 4962),
                CourseTee(name: "Red", par: 72, rating: 63.5, slope: 112, yardage: 4630),
                CourseTee(name: "Silver (Women)", par: 72, rating: 74.1, slope: 142, yardage: 5806),
                CourseTee(name: "Silver / Blue (Women)", par: 72, rating: 72.9, slope: 136, yardage: 5559),
                CourseTee(name: "Blue (Women)", par: 72, rating: 72.0, slope: 132, yardage: 5356),
                CourseTee(name: "Blue / Red (Women)", par: 72, rating: 70.0, slope: 125, yardage: 4962),
                CourseTee(name: "Red (Women)", par: 72, rating: 68.2, slope: 116, yardage: 4630)
            ],
            holes: makeHoles(
                pars: [4, 3, 5, 4, 4, 3, 4, 4, 5, 4, 5, 3, 4, 3, 5, 4, 4, 4],
                strokeIndexes: [13, 11, 17, 1, 5, 9, 7, 15, 3, 4, 18, 8, 10, 16, 14, 6, 12, 2]
            )
        )
    ]

    static let bandonCourses: [CourseCatalogEntry] = [
        CourseCatalogEntry(
            id: "bandon-dunes",
            name: "Bandon Dunes",
            location: "Bandon, OR",
            tees: [
                CourseTee(name: "Tournament", par: 72, rating: 75.9, slope: 145, yardage: 7315),
                CourseTee(name: "Black", par: 72, rating: 73.5, slope: 143, yardage: 6732),
                CourseTee(name: "Green", par: 72, rating: 71.1, slope: 133, yardage: 6221),
                CourseTee(name: "Gold", par: 72, rating: 69.1, slope: 124, yardage: 5716),
                CourseTee(name: "Orange", par: 72, rating: 65.5, slope: 114, yardage: 5040),
                CourseTee(name: "Royal Blue", par: 68, rating: 61.6, slope: 105, yardage: 3986),
                CourseTee(name: "Black (Women)", par: 72, rating: 79.6, slope: 145, yardage: 6732),
                CourseTee(name: "Green (Women)", par: 72, rating: 76.8, slope: 139, yardage: 6221),
                CourseTee(name: "Gold (Women)", par: 72, rating: 74.2, slope: 133, yardage: 5716),
                CourseTee(name: "Orange (Women)", par: 72, rating: 71.6, slope: 126, yardage: 5040),
                CourseTee(name: "Royal Blue (Women)", par: 68, rating: 64.5, slope: 111, yardage: 3986)
            ],
            holes: makeHoles(
                pars: [4, 3, 5, 4, 4, 3, 4, 4, 5, 4, 4, 3, 5, 4, 3, 4, 4, 5],
                strokeIndexes: [13, 15, 3, 5, 1, 17, 7, 11, 9, 8, 2, 18, 6, 16, 14, 10, 12, 4]
            )
        ),
        CourseCatalogEntry(
            id: "bandon-pacific-dunes",
            name: "Pacific Dunes",
            location: "Bandon, OR",
            tees: [
                CourseTee(name: "Black", par: 71, rating: 73.2, slope: 143, yardage: 6633),
                CourseTee(name: "Green", par: 71, rating: 70.8, slope: 135, yardage: 6142),
                CourseTee(name: "Gold", par: 71, rating: 68.9, slope: 131, yardage: 5775),
                CourseTee(name: "Orange", par: 68, rating: 65.8, slope: 126, yardage: 5088),
                CourseTee(name: "Royal Blue", par: 60, rating: 61.5, slope: 113, yardage: 3920),
                CourseTee(name: "Black (Women)", par: 73, rating: 78.9, slope: 149, yardage: 6633),
                CourseTee(name: "Green (Women)", par: 73, rating: 76.1, slope: 145, yardage: 6142),
                CourseTee(name: "Gold (Women)", par: 71, rating: 74.6, slope: 142, yardage: 5775),
                CourseTee(name: "Orange (Women)", par: 71, rating: 70.3, slope: 131, yardage: 5088),
                CourseTee(name: "Royal Blue (Women)", par: 64, rating: 63.9, slope: 115, yardage: 3920)
            ],
            holes: makeHoles(
                pars: [4, 4, 5, 4, 3, 4, 4, 4, 4, 3, 3, 5, 4, 3, 5, 4, 3, 5],
                strokeIndexes: [9, 11, 7, 3, 17, 13, 1, 5, 15, 14, 18, 6, 2, 16, 10, 12, 8, 4]
            )
        ),
        CourseCatalogEntry(
            id: "bandon-trails",
            name: "Bandon Trails",
            location: "Bandon, OR",
            tees: [
                CourseTee(name: "Black", par: 71, rating: 74.9, slope: 136, yardage: 6786),
                CourseTee(name: "Green", par: 71, rating: 72.0, slope: 137, yardage: 6249),
                CourseTee(name: "Gold", par: 71, rating: 69.6, slope: 132, yardage: 5751),
                CourseTee(name: "Orange", par: 71, rating: 66.7, slope: 126, yardage: 5097),
                CourseTee(name: "Royal Blue", par: 67, rating: 63.0, slope: 113, yardage: 3928),
                CourseTee(name: "Black (Women)", par: 72, rating: 80.3, slope: 146, yardage: 6786),
                CourseTee(name: "Green (Women)", par: 72, rating: 77.4, slope: 140, yardage: 6260),
                CourseTee(name: "Gold (Women)", par: 72, rating: 75.7, slope: 143, yardage: 5751),
                CourseTee(name: "Orange (Women)", par: 71, rating: 71.2, slope: 128, yardage: 5061),
                CourseTee(name: "Royal Blue (Women)", par: 68, rating: 65.2, slope: 114, yardage: 3928)
            ],
            holes: makeHoles(
                pars: [4, 3, 5, 4, 3, 4, 4, 4, 5, 4, 4, 3, 4, 4, 4, 5, 3, 4],
                strokeIndexes: [13, 17, 3, 5, 15, 9, 7, 11, 1, 10, 4, 18, 12, 14, 8, 2, 16, 6]
            )
        ),
        CourseCatalogEntry(
            id: "bandon-old-macdonald",
            name: "Old Macdonald",
            location: "Bandon, OR",
            tees: [
                CourseTee(name: "Black", par: 71, rating: 74.4, slope: 131, yardage: 6944),
                CourseTee(name: "Green", par: 71, rating: 71.6, slope: 125, yardage: 6320),
                CourseTee(name: "Gold", par: 71, rating: 68.0, slope: 116, yardage: 5658),
                CourseTee(name: "Orange", par: 71, rating: 65.2, slope: 104, yardage: 4985),
                CourseTee(name: "Royal Blue", par: 71, rating: 62.5, slope: 101, yardage: 4040),
                CourseTee(name: "Green (Women)", par: 71, rating: 77.8, slope: 137, yardage: 6320),
                CourseTee(name: "Gold (Women)", par: 71, rating: 74.1, slope: 126, yardage: 5658),
                CourseTee(name: "Orange (Women)", par: 71, rating: 70.1, slope: 117, yardage: 4985),
                CourseTee(name: "Royal Blue (Women)", par: 71, rating: 66.1, slope: 107, yardage: 4040)
            ],
            holes: makeHoles(
                pars: [4, 3, 4, 4, 3, 5, 4, 3, 4, 4, 4, 3, 4, 4, 5, 4, 5, 4],
                strokeIndexes: [11, 15, 9, 1, 17, 3, 7, 13, 5, 10, 4, 16, 18, 14, 12, 2, 6, 8]
            )
        ),
        CourseCatalogEntry(
            id: "bandon-sheep-ranch",
            name: "Sheep Ranch",
            location: "Bandon, OR",
            tees: [
                CourseTee(name: "Black", par: 72, rating: 71.9, slope: 121, yardage: 6636),
                CourseTee(name: "Green", par: 72, rating: 70.0, slope: 116, yardage: 6245),
                CourseTee(name: "Gold", par: 72, rating: 67.9, slope: 109, yardage: 5810),
                CourseTee(name: "Orange", par: 72, rating: 65.0, slope: 102, yardage: 5144),
                CourseTee(name: "Royal Blue", par: 68, rating: 61.0, slope: 97, yardage: 3943),
                CourseTee(name: "Black (Women)", par: 72, rating: 78.3, slope: 134, yardage: 6636),
                CourseTee(name: "Green (Women)", par: 74, rating: 76.2, slope: 129, yardage: 6245),
                CourseTee(name: "Gold (Women)", par: 72, rating: 73.8, slope: 124, yardage: 5810),
                CourseTee(name: "Orange (Women)", par: 72, rating: 69.8, slope: 112, yardage: 5144),
                CourseTee(name: "Royal Blue (Women)", par: 68, rating: 62.8, slope: 99, yardage: 3943)
            ],
            holes: makeHoles(
                pars: [5, 4, 3, 4, 3, 4, 3, 4, 4, 4, 5, 4, 5, 4, 4, 3, 4, 5],
                strokeIndexes: [5, 13, 17, 3, 11, 1, 15, 7, 9, 6, 4, 2, 10, 8, 14, 16, 12, 18]
            )
        )
    ]

    static let streamsongCourses: [CourseCatalogEntry] = [
        CourseCatalogEntry(
            id: "streamsong-red",
            name: "Streamsong Red",
            location: "Bowling Green, FL",
            tees: [
                CourseTee(name: "Green", par: 72, rating: 74.1, slope: 137, yardage: 7148),
                CourseTee(name: "Green/Black", par: 72, rating: 73.0, slope: 136, yardage: 6831),
                CourseTee(name: "Black", par: 72, rating: 71.6, slope: 132, yardage: 6537),
                CourseTee(name: "Black/Silver", par: 72, rating: 70.6, slope: 128, yardage: 6250),
                CourseTee(name: "Silver", par: 72, rating: 69.5, slope: 124, yardage: 6008),
                CourseTee(name: "Silver/Gold", par: 72, rating: 65.9, slope: 114, yardage: 5309),
                CourseTee(name: "Gold", par: 72, rating: 64.7, slope: 113, yardage: 4931),
                CourseTee(name: "Silver (Women)", par: 72, rating: 74.9, slope: 132, yardage: 6008),
                CourseTee(name: "Silver/Gold (Women)", par: 72, rating: 71.0, slope: 124, yardage: 5309),
                CourseTee(name: "Gold (Women)", par: 72, rating: 69.9, slope: 121, yardage: 4931)
            ],
            holes: makeHoles(
                pars: [4, 5, 4, 4, 4, 3, 5, 3, 4, 4, 4, 4, 5, 3, 4, 3, 4, 5],
                strokeIndexes: [4, 2, 14, 16, 6, 18, 12, 10, 8, 9, 5, 3, 15, 11, 1, 7, 13, 17]
            )
        ),
        CourseCatalogEntry(
            id: "streamsong-blue",
            name: "Streamsong Blue",
            location: "Bowling Green, FL",
            tees: [
                CourseTee(name: "Green", par: 72, rating: 74.0, slope: 134, yardage: 7176),
                CourseTee(name: "Green/Black", par: 72, rating: 72.9, slope: 132, yardage: 6934),
                CourseTee(name: "Black", par: 72, rating: 71.8, slope: 130, yardage: 6692),
                CourseTee(name: "Black/Silver", par: 72, rating: 70.7, slope: 129, yardage: 6381),
                CourseTee(name: "Silver", par: 72, rating: 69.5, slope: 127, yardage: 6192),
                CourseTee(name: "Silver/Gold", par: 72, rating: 67.5, slope: 120, yardage: 5796),
                CourseTee(name: "Gold", par: 72, rating: 66.4, slope: 113, yardage: 5512),
                CourseTee(name: "Silver (Women)", par: 72, rating: 75.3, slope: 130, yardage: 6192),
                CourseTee(name: "Silver/Gold (Women)", par: 72, rating: 73.0, slope: 125, yardage: 5796),
                CourseTee(name: "Gold (Women)", par: 72, rating: 71.6, slope: 122, yardage: 5512)
            ],
            holes: makeHoles(
                pars: [4, 5, 4, 4, 3, 4, 3, 4, 5, 3, 4, 4, 4, 5, 4, 3, 5, 4],
                strokeIndexes: [14, 10, 8, 4, 16, 18, 12, 2, 6, 15, 1, 11, 17, 9, 7, 13, 5, 3]
            )
        ),
        CourseCatalogEntry(
            id: "streamsong-black",
            name: "Streamsong Black",
            location: "Bowling Green, FL",
            tees: [
                CourseTee(name: "Green", par: 73, rating: 74.7, slope: 135, yardage: 7331),
                CourseTee(name: "Green/Black", par: 73, rating: 73.2, slope: 132, yardage: 7013),
                CourseTee(name: "Black", par: 73, rating: 72.0, slope: 130, yardage: 6759),
                CourseTee(name: "Black/Silver", par: 73, rating: 70.8, slope: 127, yardage: 6476),
                CourseTee(name: "Silver", par: 73, rating: 69.5, slope: 125, yardage: 6240),
                CourseTee(name: "Silver/Gold", par: 73, rating: 67.1, slope: 120, yardage: 5726),
                CourseTee(name: "Gold", par: 73, rating: 65.1, slope: 116, yardage: 5293),
                CourseTee(name: "Silver (Women)", par: 73, rating: 74.8, slope: 130, yardage: 6240),
                CourseTee(name: "Silver/Gold (Women)", par: 73, rating: 72.0, slope: 124, yardage: 5726),
                CourseTee(name: "Gold (Women)", par: 73, rating: 69.5, slope: 119, yardage: 5293)
            ],
            holes: makeHoles(
                pars: [5, 4, 4, 5, 3, 4, 3, 4, 4, 5, 4, 5, 4, 4, 3, 4, 3, 5],
                strokeIndexes: [12, 16, 4, 2, 6, 18, 14, 8, 10, 11, 3, 7, 9, 15, 17, 1, 13, 5]
            )
        )
    ]

    static let floridaCourses: [CourseCatalogEntry] = [
        CourseCatalogEntry(
            id: "tpc-sawgrass-stadium",
            name: "TPC Sawgrass - Stadium Course",
            location: "Ponte Vedra Beach, FL",
            tees: [
                CourseTee(name: "TPC", par: 72, rating: 76.8, slope: 155, yardage: 7271),
                CourseTee(name: "Blue", par: 72, rating: 73.9, slope: 148, yardage: 6631),
                CourseTee(name: "Blue / White", par: 72, rating: 72.3, slope: 144, yardage: 6347),
                CourseTee(name: "White", par: 72, rating: 70.8, slope: 138, yardage: 6018),
                CourseTee(name: "White / Green", par: 72, rating: 68.1, slope: 126, yardage: 5448),
                CourseTee(name: "Green", par: 72, rating: 65.8, slope: 116, yardage: 4984),
                CourseTee(name: "White (Women)", par: 72, rating: 77.4, slope: 149, yardage: 6018),
                CourseTee(name: "White / Green (Women)", par: 72, rating: 74.0, slope: 141, yardage: 5448),
                CourseTee(name: "Green (Women)", par: 72, rating: 71.1, slope: 134, yardage: 4984)
            ],
            holes: makeHoles(
                pars: [4, 5, 3, 4, 4, 4, 4, 3, 5, 4, 5, 4, 3, 4, 4, 5, 3, 4],
                strokeIndexes: [11, 15, 17, 9, 3, 13, 1, 7, 5, 12, 8, 16, 18, 4, 6, 10, 14, 2]
            )
        ),
        CourseCatalogEntry(
            id: "tpc-sawgrass-dyes-valley",
            name: "TPC Sawgrass - Dye's Valley Course",
            location: "Ponte Vedra Beach, FL",
            tees: [
                CourseTee(name: "TPC", par: 72, rating: 74.0, slope: 134, yardage: 6847),
                CourseTee(name: "Blue", par: 72, rating: 72.1, slope: 131, yardage: 6497),
                CourseTee(name: "Blue/White", par: 72, rating: 71.0, slope: 128, yardage: 6261),
                CourseTee(name: "White", par: 72, rating: 70.1, slope: 127, yardage: 6062),
                CourseTee(name: "White/Green", par: 72, rating: 67.8, slope: 117, yardage: 5515),
                CourseTee(name: "Green", par: 72, rating: 65.9, slope: 113, yardage: 5136),
                CourseTee(name: "White (Women)", par: 72, rating: 76.2, slope: 138, yardage: 6062),
                CourseTee(name: "White/Green (Women)", par: 72, rating: 72.7, slope: 128, yardage: 5515),
                CourseTee(name: "Green (Women)", par: 72, rating: 70.3, slope: 124, yardage: 5136)
            ],
            holes: makeHoles(
                pars: [5, 3, 4, 4, 3, 4, 4, 5, 4, 4, 3, 4, 4, 3, 4, 5, 5, 4],
                strokeIndexes: [7, 11, 17, 5, 15, 1, 13, 9, 3, 4, 6, 14, 8, 12, 16, 10, 18, 2]
            )
        ),
        CourseCatalogEntry(
            id: "sailfish-point",
            name: "Sailfish Point Golf Club",
            location: "Stuart, FL",
            tees: [
                CourseTee(name: "Black", par: 72, rating: 75.0, slope: 148, yardage: 7086),
                CourseTee(name: "Black/Red", par: 72, rating: 73.5, slope: 145, yardage: 6865),
                CourseTee(name: "Red", par: 72, rating: 72.9, slope: 143, yardage: 6645),
                CourseTee(name: "Red/Gold", par: 72, rating: 71.7, slope: 141, yardage: 6463),
                CourseTee(name: "Gold", par: 72, rating: 71.0, slope: 138, yardage: 6280),
                CourseTee(name: "Gold/White", par: 72, rating: 69.7, slope: 135, yardage: 6053),
                CourseTee(name: "White", par: 72, rating: 68.2, slope: 130, yardage: 5726),
                CourseTee(name: "White/Blue", par: 72, rating: 66.0, slope: 120, yardage: 5001),
                CourseTee(name: "Blue", par: 72, rating: 64.7, slope: 112, yardage: 4468),
                CourseTee(name: "Green", par: 72, rating: 62.1, slope: 106, yardage: 3935),
                CourseTee(name: "Gold (Women)", par: 72, rating: 75.8, slope: 144, yardage: 6280),
                CourseTee(name: "Gold/White (Women)", par: 72, rating: 74.8, slope: 142, yardage: 6053),
                CourseTee(name: "White (Women)", par: 72, rating: 73.3, slope: 132, yardage: 5726),
                CourseTee(name: "White/Blue (Women)", par: 72, rating: 71.2, slope: 128, yardage: 5001),
                CourseTee(name: "Blue (Women)", par: 72, rating: 69.1, slope: 123, yardage: 4468),
                CourseTee(name: "Blue/Green (Women)", par: 72, rating: 67.6, slope: 120, yardage: 4202),
                CourseTee(name: "Green (Women)", par: 72, rating: 66.2, slope: 118, yardage: 3935)
            ],
            holes: makeHoles(
                pars: [4, 5, 4, 3, 4, 5, 4, 3, 4, 5, 4, 3, 4, 5, 4, 3, 4, 4],
                strokeIndexes: [11, 7, 3, 13, 15, 1, 9, 17, 5, 10, 18, 12, 4, 2, 14, 16, 6, 8]
            )
        )
    ]

    static let northeastCourses: [CourseCatalogEntry] = [
        CourseCatalogEntry(
            id: "tpc-boston",
            name: "TPC Boston",
            location: "Norton, MA",
            tees: [
                CourseTee(name: "Championship", par: 72, rating: 76.6, slope: 155, yardage: 7241),
                CourseTee(name: "Gold", par: 72, rating: 75.0, slope: 149, yardage: 6990),
                CourseTee(name: "Black", par: 72, rating: 72.8, slope: 137, yardage: 6459),
                CourseTee(name: "Blended (W/B combo)", par: 72, rating: 71.6, slope: 133, yardage: 6193),
                CourseTee(name: "White", par: 72, rating: 70.3, slope: 132, yardage: 5985),
                CourseTee(name: "White/Blue", par: 72, rating: 68.3, slope: 129, yardage: 5536),
                CourseTee(name: "Blue", par: 72, rating: 66.1, slope: 122, yardage: 5070),
                CourseTee(name: "Gold (Women)", par: 72, rating: 82.1, slope: 155, yardage: 6990),
                CourseTee(name: "Black (Women)", par: 72, rating: 78.9, slope: 155, yardage: 6459),
                CourseTee(name: "White (Women)", par: 72, rating: 75.6, slope: 138, yardage: 5985),
                CourseTee(name: "White/Blue (Women)", par: 72, rating: 73.4, slope: 132, yardage: 5536),
                CourseTee(name: "Blue (Women)", par: 72, rating: 70.9, slope: 126, yardage: 5070)
            ],
            holes: makeHoles(
                pars: [4, 5, 3, 4, 4, 4, 5, 3, 4, 4, 3, 5, 4, 5, 4, 3, 4, 5],
                strokeIndexes: [13, 3, 15, 9, 7, 5, 1, 17, 11, 12, 16, 8, 2, 14, 10, 18, 6, 4]
            )
        ),
        CourseCatalogEntry(
            id: "rhode-island-country-club",
            name: "Rhode Island Country Club",
            location: "Barrington, RI",
            tees: [
                CourseTee(name: "Black", par: 71, rating: 73.1, slope: 132, yardage: 6845),
                CourseTee(name: "Blue", par: 71, rating: 71.0, slope: 129, yardage: 6372),
                CourseTee(name: "White", par: 71, rating: 68.7, slope: 123, yardage: 5973),
                CourseTee(name: "White / Red", par: 71, rating: 67.3, slope: 122, yardage: 5460),
                CourseTee(name: "Red", par: 71, rating: 64.3, slope: 115, yardage: 4932),
                CourseTee(name: "Black (Women)", par: 71, rating: 79.3, slope: 140, yardage: 6845),
                CourseTee(name: "Blue (Women)", par: 71, rating: 77.0, slope: 136, yardage: 6372),
                CourseTee(name: "White (Women)", par: 72, rating: 74.7, slope: 131, yardage: 5973),
                CourseTee(name: "White / Red (Women)", par: 72, rating: 72.8, slope: 128, yardage: 5460),
                CourseTee(name: "Red (Women)", par: 71, rating: 71.1, slope: 123, yardage: 4932)
            ],
            holes: makeHoles(
                pars: [4, 4, 4, 4, 3, 4, 4, 5, 4, 3, 5, 4, 4, 4, 4, 4, 3, 4],
                strokeIndexes: [15, 5, 9, 11, 17, 13, 1, 7, 3, 16, 4, 14, 2, 6, 12, 8, 18, 10]
            )
        ),
        CourseCatalogEntry(
            id: "newport-national-orchard",
            name: "Newport National - Orchard Course",
            location: "Middletown, RI",
            tees: [
                CourseTee(name: "Black", par: 72, rating: 74.1, slope: 139, yardage: 7244),
                CourseTee(name: "Gold", par: 72, rating: 71.6, slope: 131, yardage: 6553),
                CourseTee(name: "Gold/White", par: 72, rating: 70.4, slope: 129, yardage: 6294),
                CourseTee(name: "White", par: 72, rating: 68.3, slope: 127, yardage: 6017),
                CourseTee(name: "Red", par: 71, rating: 64.1, slope: 119, yardage: 5217),
                CourseTee(name: "White (Women)", par: 71, rating: 74.1, slope: 131, yardage: 6017),
                CourseTee(name: "Red/White (Women)", par: 72, rating: 72.1, slope: 128, yardage: 5675),
                CourseTee(name: "Red (Women)", par: 71, rating: 69.5, slope: 123, yardage: 5217)
            ],
            holes: makeHoles(
                pars: [5, 4, 3, 3, 4, 4, 4, 5, 4, 4, 5, 4, 3, 5, 4, 3, 4, 4],
                strokeIndexes: [9, 3, 15, 17, 13, 1, 5, 7, 11, 10, 12, 14, 18, 6, 4, 16, 2, 8]
            )
        )
    ]

    static let midwestCourses: [CourseCatalogEntry] = [
        CourseCatalogEntry(
            id: "erin-hills",
            name: "Erin Hills",
            location: "Erin, WI",
            tees: [
                CourseTee(name: "Black", par: 72, rating: 78.1, slope: 146, yardage: 7772),
                CourseTee(name: "Blue", par: 72, rating: 75.4, slope: 141, yardage: 7357),
                CourseTee(name: "Green", par: 72, rating: 73.5, slope: 135, yardage: 6829),
                CourseTee(name: "Green/White", par: 72, rating: 72.2, slope: 132, yardage: 6537),
                CourseTee(name: "White", par: 72, rating: 70.8, slope: 128, yardage: 6252),
                CourseTee(name: "White/Gold", par: 72, rating: 68.0, slope: 122, yardage: 5670),
                CourseTee(name: "Green/White (Women)", par: 72, rating: 77.3, slope: 136, yardage: 6537),
                CourseTee(name: "White (Women)", par: 72, rating: 75.7, slope: 131, yardage: 6252),
                CourseTee(name: "White/Gold (Women)", par: 72, rating: 72.3, slope: 124, yardage: 5670),
                CourseTee(name: "Gold (Women)", par: 72, rating: 69.2, slope: 118, yardage: 5078)
            ],
            holes: makeHoles(
                pars: [5, 4, 4, 4, 4, 3, 5, 4, 3, 4, 4, 4, 3, 5, 4, 3, 4, 5],
                strokeIndexes: [3, 13, 7, 11, 9, 15, 1, 5, 17, 4, 14, 10, 18, 2, 12, 16, 8, 6]
            )
        ),
        CourseCatalogEntry(
            id: "whistling-straits-straits",
            name: "Whistling Straits - Straits Course",
            location: "Sheboygan, WI",
            tees: [
                CourseTee(name: "Black", par: 72, rating: 77.2, slope: 152, yardage: 7790),
                CourseTee(name: "Blue", par: 72, rating: 74.2, slope: 145, yardage: 7142),
                CourseTee(name: "Green", par: 72, rating: 71.9, slope: 141, yardage: 6663),
                CourseTee(name: "White", par: 72, rating: 70.4, slope: 137, yardage: 6360),
                CourseTee(name: "White / Red", par: 72, rating: 68.6, slope: 134, yardage: 5922),
                CourseTee(name: "Red", par: 72, rating: 66.4, slope: 129, yardage: 5564),
                CourseTee(name: "Green (Women)", par: 72, rating: 79.4, slope: 143, yardage: 6663),
                CourseTee(name: "White (Women)", par: 72, rating: 76.9, slope: 137, yardage: 6360),
                CourseTee(name: "White / Red (Women)", par: 72, rating: 75.5, slope: 133, yardage: 5922),
                CourseTee(name: "Red (Women)", par: 72, rating: 72.7, slope: 129, yardage: 5564)
            ],
            holes: makeHoles(
                pars: [4, 5, 3, 4, 5, 4, 3, 4, 4, 4, 5, 3, 4, 4, 4, 5, 3, 4],
                strokeIndexes: [15, 7, 17, 1, 5, 13, 9, 3, 11, 12, 6, 18, 14, 16, 4, 10, 8, 2]
            )
        )
    ]

    private static func makeHoles(pars: [Int], strokeIndexes: [Int]) -> [Hole] {
        zip(pars, strokeIndexes).enumerated().map { index, hole in
            Hole(number: index + 1, par: hole.0, strokeIndex: hole.1)
        }
    }
}
