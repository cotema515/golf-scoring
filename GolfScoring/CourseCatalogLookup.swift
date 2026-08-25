import Foundation

enum CourseCatalogLookup {
    static func course(for courseName: String) -> CourseCatalogEntry? {
        let savedName = normalizedCourseName(courseName)
        return CourseCatalogEntry.courses.first { course in
            let catalogName = normalizedCourseName(course.name)
            return catalogName == savedName ||
                savedName.hasPrefix(catalogName) ||
                catalogName.hasPrefix(savedName)
        }
    }

    static func canonicalHoles(for courseName: String, fallback holes: [Hole]) -> [Hole] {
        course(for: courseName)?.holes ?? holes
    }

    static func canonicalHoleSummaries(for round: RoundSummary) -> [HoleSummary] {
        guard let catalogCourse = course(for: round.course?.name ?? round.courseName) else {
            return round.holes
        }

        return round.holes.map { savedHole in
            guard let catalogHole = catalogCourse.holes.first(where: { $0.number == savedHole.number }) else {
                return savedHole
            }

            var correctedHole = savedHole
            correctedHole.par = catalogHole.par
            correctedHole.strokeIndex = catalogHole.strokeIndex
            return correctedHole
        }
    }

    private static func normalizedCourseName(_ name: String) -> String {
        name
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .joined()
    }
}
