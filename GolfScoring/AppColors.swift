import SwiftUI

enum AppColors {
    static let joshMatt = Color.green
    static let jeffShane = Color(red: 0.10, green: 0.42, blue: 0.95)
    static let push = Color.gray

    static func resultColor(_ result: String, teamOneName: String = "Josh & Matt", teamTwoName: String = "Shane & Jeff") -> Color {
        if result.contains("JM") ||
            result.localizedCaseInsensitiveContains("Josh") && result.localizedCaseInsensitiveContains("Matt") ||
            result.localizedCaseInsensitiveContains(teamOneName) {
            return joshMatt
        }

        if result.contains("SJ") ||
            result.localizedCaseInsensitiveContains("Jeff") && result.localizedCaseInsensitiveContains("Shane") ||
            result.localizedCaseInsensitiveContains(teamTwoName) {
            return jeffShane
        }

        return push
    }
}
