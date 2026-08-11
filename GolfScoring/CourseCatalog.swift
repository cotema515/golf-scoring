import Foundation

struct CourseTee: Identifiable, Hashable {
    var id: String { name }
    var name: String
    var par: Int
    var rating: Double
    var slope: Int
    var yardage: Int

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
            let lhsWomenPenalty = lhs.name.localizedCaseInsensitiveContains("(W)") ? 1 : 0
            let rhsWomenPenalty = rhs.name.localizedCaseInsensitiveContains("(W)") ? 1 : 0
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
                CourseTee(name: "Yellow", par: 72, rating: 76.8, slope: 153, yardage: 7416),
                CourseTee(name: "Yellow/Black", par: 72, rating: 75.4, slope: 151, yardage: 6968),
                CourseTee(name: "Black", par: 72, rating: 73.9, slope: 148, yardage: 6519),
                CourseTee(name: "Black/White", par: 72, rating: 73.2, slope: 144, yardage: 6367),
                CourseTee(name: "White", par: 72, rating: 72.6, slope: 139, yardage: 6215),
                CourseTee(name: "White/Green", par: 72, rating: 71.9, slope: 137, yardage: 5768),
                CourseTee(name: "Green", par: 72, rating: 71.1, slope: 134, yardage: 5320),
                CourseTee(name: "Red", par: 72, rating: 67.6, slope: 124, yardage: 2660)
            ],
            holes: makeHoles(
                pars: [4, 5, 4, 4, 3, 4, 5, 3, 4, 4, 5, 4, 4, 3, 4, 5, 3, 4],
                strokeIndexes: [15, 3, 9, 1, 11, 13, 7, 17, 5, 18, 10, 8, 12, 14, 16, 4, 6, 2]
            )
        ),
        CourseCatalogEntry(
            id: "kiawah-turtle",
            name: "Turtle Point",
            location: "Kiawah Island, SC",
            tees: [
                CourseTee(name: "Tournament", par: 72, rating: 73.0, slope: 134, yardage: 6911),
                CourseTee(name: "Tournament/Blue", par: 72, rating: 72.3, slope: 132, yardage: 6694),
                CourseTee(name: "Blue", par: 72, rating: 71.5, slope: 130, yardage: 6477),
                CourseTee(name: "Blue/White", par: 72, rating: 70.5, slope: 127, yardage: 6241),
                CourseTee(name: "White", par: 72, rating: 69.5, slope: 124, yardage: 6005),
                CourseTee(name: "White/Gold", par: 72, rating: 68.3, slope: 121, yardage: 5557),
                CourseTee(name: "Gold", par: 72, rating: 67.1, slope: 118, yardage: 5109),
                CourseTee(name: "Silver", par: 72, rating: 65.8, slope: 113, yardage: 4520)
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
                CourseTee(name: "Black/Blue", par: 72, rating: 71.8, slope: 135, yardage: 6368),
                CourseTee(name: "Blue", par: 72, rating: 70.9, slope: 132, yardage: 6115),
                CourseTee(name: "Blue/White", par: 72, rating: 69.8, slope: 128, yardage: 5775),
                CourseTee(name: "White", par: 72, rating: 68.6, slope: 124, yardage: 5435),
                CourseTee(name: "White/Gold", par: 72, rating: 67.1, slope: 120, yardage: 5010),
                CourseTee(name: "Gold", par: 72, rating: 65.6, slope: 116, yardage: 4585),
                CourseTee(name: "Silver", par: 72, rating: 64.3, slope: 111, yardage: 4063)
            ],
            holes: makeHoles(
                pars: [4, 3, 5, 4, 4, 3, 4, 4, 5, 4, 5, 3, 4, 3, 5, 4, 4, 4],
                strokeIndexes: [13, 17, 5, 1, 7, 15, 9, 11, 3, 2, 10, 16, 8, 18, 4, 14, 12, 6]
            )
        )
    ]

    static let bandonCourses: [CourseCatalogEntry] = [
        CourseCatalogEntry(
            id: "bandon-dunes",
            name: "Bandon Dunes",
            location: "Bandon, OR",
            tees: [
                CourseTee(name: "Black", par: 72, rating: 74.1, slope: 143, yardage: 6732),
                CourseTee(name: "Black/Green", par: 72, rating: 72.9, slope: 141, yardage: 6477),
                CourseTee(name: "Green", par: 72, rating: 71.7, slope: 139, yardage: 6221),
                CourseTee(name: "Green/Gold", par: 72, rating: 70.6, slope: 136, yardage: 5969),
                CourseTee(name: "Gold", par: 72, rating: 69.5, slope: 133, yardage: 5716),
                CourseTee(name: "Gold/Orange", par: 72, rating: 67.4, slope: 130, yardage: 5394),
                CourseTee(name: "Orange", par: 72, rating: 66.6, slope: 126, yardage: 5072),
                CourseTee(name: "Orange/Royal Blue", par: 72, rating: 64.1, slope: 114, yardage: 4509),
                CourseTee(name: "Royal Blue", par: 72, rating: 61.5, slope: 101, yardage: 3945)
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
                CourseTee(name: "Black/Green", par: 71, rating: 72.0, slope: 139, yardage: 6388),
                CourseTee(name: "Green", par: 71, rating: 70.8, slope: 135, yardage: 6142),
                CourseTee(name: "Green/Gold", par: 71, rating: 69.9, slope: 133, yardage: 5959),
                CourseTee(name: "Gold", par: 71, rating: 68.9, slope: 131, yardage: 5775),
                CourseTee(name: "Gold/Orange", par: 71, rating: 67.3, slope: 127, yardage: 5432),
                CourseTee(name: "Orange", par: 71, rating: 65.6, slope: 122, yardage: 5088),
                CourseTee(name: "Orange/Royal Blue", par: 71, rating: 63.0, slope: 116, yardage: 4504),
                CourseTee(name: "Royal Blue", par: 71, rating: 60.4, slope: 109, yardage: 3920)
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
                CourseTee(name: "Black", par: 71, rating: 73.6, slope: 130, yardage: 6759),
                CourseTee(name: "Black/Green", par: 71, rating: 72.4, slope: 130, yardage: 6503),
                CourseTee(name: "Green", par: 71, rating: 71.1, slope: 129, yardage: 6247),
                CourseTee(name: "Green/Gold", par: 71, rating: 69.9, slope: 126, yardage: 5999),
                CourseTee(name: "Gold", par: 71, rating: 68.7, slope: 122, yardage: 5751),
                CourseTee(name: "Gold/Orange", par: 71, rating: 67.4, slope: 120, yardage: 5426),
                CourseTee(name: "Orange", par: 71, rating: 66.1, slope: 117, yardage: 5100),
                CourseTee(name: "Orange/Royal Blue", par: 71, rating: 63.7, slope: 111, yardage: 4464),
                CourseTee(name: "Royal Blue", par: 71, rating: 61.2, slope: 105, yardage: 3827)
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
                CourseTee(name: "Black", par: 71, rating: 74.1, slope: 133, yardage: 6978),
                CourseTee(name: "Black/Green", par: 71, rating: 72.7, slope: 130, yardage: 6665),
                CourseTee(name: "Green", par: 71, rating: 71.3, slope: 127, yardage: 6352),
                CourseTee(name: "Green/Gold", par: 71, rating: 69.8, slope: 123, yardage: 6021),
                CourseTee(name: "Gold", par: 71, rating: 68.2, slope: 119, yardage: 5690),
                CourseTee(name: "Gold/Orange", par: 71, rating: 66.7, slope: 112, yardage: 5367),
                CourseTee(name: "Orange", par: 71, rating: 65.2, slope: 104, yardage: 5044),
                CourseTee(name: "Orange/Royal Blue", par: 71, rating: 63.9, slope: 104, yardage: 4662),
                CourseTee(name: "Royal Blue", par: 71, rating: 62.6, slope: 104, yardage: 4280)
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
                CourseTee(name: "Black", par: 72, rating: 72.1, slope: 122, yardage: 6636),
                CourseTee(name: "Black/Green", par: 72, rating: 71.1, slope: 119, yardage: 6441),
                CourseTee(name: "Green", par: 72, rating: 70.0, slope: 116, yardage: 6245),
                CourseTee(name: "Green/Gold", par: 72, rating: 69.1, slope: 114, yardage: 6028),
                CourseTee(name: "Gold", par: 72, rating: 68.1, slope: 111, yardage: 5810),
                CourseTee(name: "Gold/Orange", par: 72, rating: 66.7, slope: 108, yardage: 5477),
                CourseTee(name: "Orange", par: 72, rating: 65.2, slope: 105, yardage: 5144),
                CourseTee(name: "Orange/Royal Blue", par: 72, rating: 63.1, slope: 101, yardage: 4544),
                CourseTee(name: "Royal Blue", par: 72, rating: 61.0, slope: 96, yardage: 3943)
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
                CourseTee(name: "Silver/Gold (Women)", par: 72, rating: 72.5, slope: 128, yardage: 5309),
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
                CourseTee(name: "Gold", par: 72, rating: 71.6, slope: 122, yardage: 5512),
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
                CourseTee(name: "Black/Silver", par: 73, rating: 70.8, slope: 127, yardage: 6462),
                CourseTee(name: "Silver", par: 73, rating: 69.5, slope: 125, yardage: 6240),
                CourseTee(name: "Silver/Gold", par: 73, rating: 67.1, slope: 120, yardage: 5726),
                CourseTee(name: "Gold", par: 73, rating: 69.5, slope: 119, yardage: 5293),
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
                CourseTee(name: "The Players", par: 72, rating: 76.8, slope: 155, yardage: 7352),
                CourseTee(name: "Blue", par: 72, rating: 73.9, slope: 148, yardage: 6670),
                CourseTee(name: "Blue/White", par: 72, rating: 72.3, slope: 144, yardage: 6396),
                CourseTee(name: "White", par: 72, rating: 70.8, slope: 138, yardage: 6086),
                CourseTee(name: "White/Green", par: 72, rating: 68.1, slope: 126, yardage: 5509),
                CourseTee(name: "Green", par: 72, rating: 65.8, slope: 116, yardage: 5019),
                CourseTee(name: "White (Women)", par: 72, rating: 77.4, slope: 149, yardage: 6086),
                CourseTee(name: "White/Green (Women)", par: 72, rating: 74.0, slope: 141, yardage: 5509),
                CourseTee(name: "Green (Women)", par: 72, rating: 71.1, slope: 134, yardage: 5019)
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
                CourseTee(name: "Blue", par: 72, rating: 72.1, slope: 131, yardage: 6502),
                CourseTee(name: "Blue/White", par: 72, rating: 71.0, slope: 128, yardage: 6272),
                CourseTee(name: "White", par: 72, rating: 70.1, slope: 127, yardage: 6079),
                CourseTee(name: "White/Green", par: 72, rating: 67.8, slope: 117, yardage: 5526),
                CourseTee(name: "Green", par: 72, rating: 65.9, slope: 113, yardage: 5126),
                CourseTee(name: "White (Women)", par: 72, rating: 76.2, slope: 138, yardage: 6079),
                CourseTee(name: "White/Green (Women)", par: 72, rating: 72.7, slope: 128, yardage: 5526),
                CourseTee(name: "Green (Women)", par: 72, rating: 70.3, slope: 124, yardage: 5126)
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
                CourseTee(name: "Champ", par: 72, rating: 75.0, slope: 143, yardage: 7086),
                CourseTee(name: "Back", par: 72, rating: 72.8, slope: 138, yardage: 6645),
                CourseTee(name: "Member", par: 72, rating: 70.7, slope: 133, yardage: 6280),
                CourseTee(name: "Combo", par: 72, rating: 69.7, slope: 129, yardage: 6053),
                CourseTee(name: "Middle", par: 72, rating: 68.4, slope: 126, yardage: 5726),
                CourseTee(name: "Forward", par: 72, rating: 65.1, slope: 118, yardage: 5001),
                CourseTee(name: "Tee it Forward", par: 72, rating: 62.1, slope: 113, yardage: 3935),
                CourseTee(name: "Combo (Women)", par: 72, rating: 72.3, slope: 131, yardage: 5413),
                CourseTee(name: "Middle (Women)", par: 72, rating: 74.3, slope: 135, yardage: 5726),
                CourseTee(name: "Forward (Women)", par: 72, rating: 70.0, slope: 124, yardage: 5001),
                CourseTee(name: "Tee it Forward (Women)", par: 72, rating: 64.7, slope: 113, yardage: 3935)
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
                CourseTee(name: "Championship", par: 73, rating: 77.2, slope: 154, yardage: 7261),
                CourseTee(name: "Gold", par: 73, rating: 74.7, slope: 145, yardage: 7011),
                CourseTee(name: "Black", par: 73, rating: 72.4, slope: 139, yardage: 6484),
                CourseTee(name: "Blended", par: 73, rating: 71.3, slope: 136, yardage: 6284),
                CourseTee(name: "White", par: 73, rating: 70.6, slope: 133, yardage: 6117),
                CourseTee(name: "Blue", par: 73, rating: 66.4, slope: 123, yardage: 5201),
                CourseTee(name: "White (Women)", par: 73, rating: 76.4, slope: 137, yardage: 6117),
                CourseTee(name: "Blue (Women)", par: 73, rating: 72.1, slope: 132, yardage: 5201)
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
                CourseTee(name: "Blue", par: 71, rating: 70.8, slope: 125, yardage: 6372),
                CourseTee(name: "White", par: 71, rating: 69.1, slope: 122, yardage: 5973),
                CourseTee(name: "Red (Women)", par: 71, rating: 75.0, slope: 137, yardage: 5932)
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
                CourseTee(name: "Gold", par: 72, rating: 71.6, slope: 132, yardage: 6553),
                CourseTee(name: "Gold/White", par: 72, rating: 70.4, slope: 129, yardage: 6294),
                CourseTee(name: "White", par: 72, rating: 68.3, slope: 127, yardage: 6017),
                CourseTee(name: "White (Women)", par: 71, rating: 74.1, slope: 131, yardage: 6017),
                CourseTee(name: "White/Red", par: 71, rating: 72.1, slope: 128, yardage: 5675),
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
                CourseTee(name: "Black", par: 72, rating: 77.9, slope: 145, yardage: 7800),
                CourseTee(name: "Blue", par: 72, rating: 75.2, slope: 140, yardage: 7316),
                CourseTee(name: "Green", par: 72, rating: 73.2, slope: 135, yardage: 6744),
                CourseTee(name: "White", par: 72, rating: 70.5, slope: 129, yardage: 6233),
                CourseTee(name: "White (Women)", par: 72, rating: 75.5, slope: 131, yardage: 6233),
                CourseTee(name: "Gold", par: 72, rating: 69.2, slope: 118, yardage: 5082)
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
                CourseTee(name: "White/Red", par: 72, rating: 68.9, slope: 133, yardage: 6037),
                CourseTee(name: "Red", par: 72, rating: 66.4, slope: 129, yardage: 5564),
                CourseTee(name: "Green (Women)", par: 72, rating: 79.4, slope: 143, yardage: 6663),
                CourseTee(name: "White (Women)", par: 72, rating: 76.9, slope: 137, yardage: 6360),
                CourseTee(name: "White/Red (Women)", par: 72, rating: 75.3, slope: 134, yardage: 6037),
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
