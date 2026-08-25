import SwiftUI

struct CreateGolfAppGameView: View {
    @ObservedObject var account: AccountStore
    @ObservedObject var golfAppStore: GolfAppStore
    @Environment(\.dismiss) private var dismiss

    @State private var gameName = ""
    @State private var format = "strokePlay"
    @State private var selectedCourseID = CourseCatalogEntry.courses.first?.id ?? ""
    @State private var selectedTeeName = ""
    @State private var selectedFriendIDs: Set<String> = []
    @State private var teamAssignments: [String: String] = [:]
    @State private var teeTimeAssignments: [String: String] = [:]
    @State private var isSaving = false
    @FocusState private var isNameFocused: Bool

    private let formats = ["strokePlay", "netStrokePlay", "stableford", "matchPlay"]

    private var selectedCourse: CourseCatalogEntry? {
        CourseCatalogEntry.courses.first { $0.id == selectedCourseID } ?? CourseCatalogEntry.courses.first
    }

    private var selectedTee: CourseTee? {
        guard let selectedCourse else { return nil }
        return selectedCourse.tees.first { $0.name == selectedTeeName } ?? selectedCourse.defaultTee
    }

    private var selectedPlayers: [GolfAppUser] {
        let me = GolfAppUser(
            authUserID: account.authSession?.userID ?? "current-user",
            username: account.profile.username,
            email: account.profile.email,
            firstName: account.profile.firstName,
            lastName: account.profile.lastName,
            handicapIndex: account.profile.handicapIndex,
            playerKey: account.profile.playerKey,
            profileType: account.profile.profileType,
            isFriend: false
        )
        return [me] + golfAppStore.friends.filter { selectedFriendIDs.contains($0.id) }
    }

    private var formatNeedsTeams: Bool {
        format == "matchPlay" || format == "stableford"
    }

    var body: some View {
        NavigationStack {
            Form {
                gameSection
                courseSection
                inviteSection
                if formatNeedsTeams { teamsSection }
                if selectedPlayers.count > 1 { teeTimesSection }
            }
            .navigationTitle("New Game")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isSaving ? "Creating..." : "Create") { createGame() }
                        .disabled(isSaving)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { isNameFocused = false }
                }
            }
            .task {
                await golfAppStore.refresh(authSession: account.authSession)
                selectedTeeName = selectedCourse?.defaultTee.name ?? ""
            }
        }
    }

    private var gameSection: some View {
        Section("Game") {
            TextField("Game name", text: $gameName)
                .focused($isNameFocused)

            Picker("Format", selection: $format) {
                ForEach(formats, id: \.self) { format in
                    Text(format.displayGameFormat).tag(format)
                }
            }
        }
    }

    private var courseSection: some View {
        Section("Course") {
            Picker("Course", selection: $selectedCourseID) {
                ForEach(CourseCatalogEntry.courses) { course in
                    Text("\(course.name) · \(course.location)").tag(course.id)
                }
            }
            .onChange(of: selectedCourseID) { _, _ in
                selectedTeeName = selectedCourse?.defaultTee.name ?? ""
            }

            if let selectedCourse {
                Picker("Tee", selection: $selectedTeeName) {
                    ForEach(selectedCourse.tees) { tee in
                        Text(tee.setupName).tag(tee.name)
                    }
                }
            }
        }
    }

    private var inviteSection: some View {
        Section("Invite Friends") {
            if golfAppStore.friends.isEmpty {
                Text("Add friends in Social first.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(golfAppStore.friends) { friend in
                    Button { toggle(friend) } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(friend.displayName)
                                    .foregroundStyle(.primary)
                                Text("@\(friend.username)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if selectedFriendIDs.contains(friend.id) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                            }
                        }
                    }
                }
            }
        }
    }

    private var teamsSection: some View {
        Section("Teams") {
            Text("Assign players to Team 1 or Team 2 for the event leaderboard.")
                .font(.caption)
                .foregroundStyle(.secondary)

            ForEach(selectedPlayers) { player in
                Picker(player.displayName, selection: teamBinding(for: player)) {
                    Text("Team 1").tag("Team 1")
                    Text("Team 2").tag("Team 2")
                }
                .pickerStyle(.segmented)
            }
        }
    }

    private var teeTimesSection: some View {
        Section("Tee Times") {
            Text("Split the group into two tee times while everyone can still enter scores.")
                .font(.caption)
                .foregroundStyle(.secondary)

            ForEach(selectedPlayers) { player in
                Picker(player.displayName, selection: teeTimeBinding(for: player)) {
                    Text("Tee Time 1").tag("Tee Time 1")
                    Text("Tee Time 2").tag("Tee Time 2")
                }
                .pickerStyle(.segmented)
            }
        }
    }

    private func toggle(_ friend: GolfAppUser) {
        if selectedFriendIDs.contains(friend.id) {
            selectedFriendIDs.remove(friend.id)
        } else {
            selectedFriendIDs.insert(friend.id)
        }
    }

    private func createGame() {
        isSaving = true
        let selectedFriends = golfAppStore.friends.filter { selectedFriendIDs.contains($0.id) }
        let cleanedTeamAssignments = formatNeedsTeams ? selectedPlayers.reduce(into: [String: String]()) { result, player in
            result[player.authUserID] = teamAssignments[player.authUserID] ?? defaultTeam(for: player)
        } : [:]
        let cleanedTeeTimeAssignments = selectedPlayers.reduce(into: [String: String]()) { result, player in
            result[player.authUserID] = teeTimeAssignments[player.authUserID] ?? defaultTeeTime(for: player)
        }

        Task {
            let saved = await golfAppStore.createGame(
                name: gameName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Golf Game" : gameName,
                format: format,
                selectedFriends: selectedFriends,
                course: selectedCourse,
                tee: selectedTee,
                teamAssignments: cleanedTeamAssignments,
                teeTimeAssignments: cleanedTeeTimeAssignments,
                authSession: account.authSession
            )
            await MainActor.run {
                isSaving = false
                if saved { dismiss() }
            }
        }
    }

    private func teamBinding(for player: GolfAppUser) -> Binding<String> {
        Binding(
            get: { teamAssignments[player.authUserID] ?? defaultTeam(for: player) },
            set: { teamAssignments[player.authUserID] = $0 }
        )
    }

    private func teeTimeBinding(for player: GolfAppUser) -> Binding<String> {
        Binding(
            get: { teeTimeAssignments[player.authUserID] ?? defaultTeeTime(for: player) },
            set: { teeTimeAssignments[player.authUserID] = $0 }
        )
    }

    private func defaultTeam(for player: GolfAppUser) -> String {
        guard let index = selectedPlayers.firstIndex(where: { $0.id == player.id }) else {
            return "Team 1"
        }
        return index.isMultiple(of: 2) ? "Team 1" : "Team 2"
    }

    private func defaultTeeTime(for player: GolfAppUser) -> String {
        guard let index = selectedPlayers.firstIndex(where: { $0.id == player.id }) else {
            return "Tee Time 1"
        }
        return index < 4 ? "Tee Time 1" : "Tee Time 2"
    }
}
