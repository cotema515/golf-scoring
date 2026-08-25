import SwiftUI

struct GolfAppSocialView: View {
    @ObservedObject var account: AccountStore
    @ObservedObject var golfAppStore: GolfAppStore
    @State private var searchText = ""
    @FocusState private var isSearchFocused: Bool

    private var cleanSearchText: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var visibleSearchResults: [GolfAppUser] {
        guard cleanSearchText.count >= 2 else { return [] }

        var seenIDs = Set<String>()
        var results: [GolfAppUser] = []

        for user in golfAppStore.searchResults + matchingFriends {
            guard !seenIDs.contains(user.id) else { continue }
            seenIDs.insert(user.id)
            results.append(user)
        }

        return results
    }

    private var matchingFriends: [GolfAppUser] {
        guard cleanSearchText.count >= 2 else { return [] }
        let query = cleanSearchText.lowercased()

        return golfAppStore.friends.filter { friend in
            friend.username.lowercased().contains(query)
                || friend.email.lowercased().contains(query)
                || friend.firstName.lowercased().contains(query)
                || friend.lastName.lowercased().contains(query)
                || friend.displayName.lowercased().contains(query)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Social")
                        .font(.largeTitle.bold())
                    Text("Find golfers by username, name, or email. Add them as friends, then invite them to games.")
                        .foregroundStyle(.secondary)
                }

                TextField("Search username, name, or email", text: $searchText)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.search)
                    .textFieldStyle(.roundedBorder)
                    .focused($isSearchFocused)
                    .onSubmit {
                        Task { await golfAppStore.search(searchText, authSession: account.authSession) }
                    }
                    .onChange(of: searchText) { _, newValue in
                        Task { await golfAppStore.search(newValue, authSession: account.authSession) }
                    }

                if !visibleSearchResults.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Search Results")
                            .font(.headline)
                        ForEach(visibleSearchResults) { user in
                            GolfAppUserRow(user: user) {
                                Task { await golfAppStore.addFriend(user, authSession: account.authSession) }
                            }
                        }
                    }
                } else if cleanSearchText.count >= 2 {
                    ContentUnavailableView(
                        "No golfers found",
                        systemImage: "magnifyingglass",
                        description: Text("Try a username, first name, last name, or email.")
                    )
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Friends")
                        .font(.headline)

                    if golfAppStore.friends.isEmpty {
                        ContentUnavailableView(
                            "No friends yet",
                            systemImage: "person.badge.plus",
                            description: Text("Search for golfers above and add them as friends.")
                        )
                    } else {
                        ForEach(golfAppStore.friends) { friend in
                            GolfAppFriendRow(user: friend)
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Social")
        .scrollDismissesKeyboard(.interactively)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                ProfileMenuButton(account: account)
            }

            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    isSearchFocused = false
                }
            }
        }
        .task {
            await golfAppStore.refresh(authSession: account.authSession)
        }
    }
}

private struct GolfAppUserRow: View {
    let user: GolfAppUser
    let addFriend: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "person.crop.circle.fill")
                .font(.title)
                .foregroundStyle(.green)

            VStack(alignment: .leading, spacing: 3) {
                Text(user.displayName)
                    .fontWeight(.semibold)
                Text("@\(user.username) · \(user.email)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Index \(user.handicapIndex?.formatted(.number.precision(.fractionLength(1))) ?? "—")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button(user.isFriend ? "Friends" : "Add") {
                addFriend()
            }
            .buttonStyle(.borderedProminent)
            .disabled(user.isFriend)
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
    }
}

private struct GolfAppFriendRow: View {
    let user: GolfAppUser

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "person.crop.circle.fill")
                .font(.title2)
                .foregroundStyle(.green)
            VStack(alignment: .leading, spacing: 3) {
                Text(user.displayName)
                    .fontWeight(.semibold)
                Text("@\(user.username) · Index \(user.handicapIndex?.formatted(.number.precision(.fractionLength(1))) ?? "—")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding()
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
    }
}

struct GolfAppGamesView: View {
    @ObservedObject var account: AccountStore
    @ObservedObject var golfAppStore: GolfAppStore
    @State private var isShowingCreateGame = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Games")
                            .font(.largeTitle.bold())
                        Text("Invite friends and create a golf game.")
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button {
                        isShowingCreateGame = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title)
                    }
                }

                if golfAppStore.games.isEmpty {
                    ContentUnavailableView(
                        "No games yet",
                        systemImage: "flag.2.crossed",
                        description: Text("Create a game and invite as many friends as you want.")
                    )
                    .padding(.top, 36)
                } else {
                    LazyVStack(spacing: 12) {
                        ForEach(golfAppStore.games) { game in
                            NavigationLink {
                                GolfAppGameDetailView(account: account, golfAppStore: golfAppStore, game: game)
                            } label: {
                                GolfAppGameCard(game: game)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Games")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                ProfileMenuButton(account: account)
            }
        }
        .sheet(isPresented: $isShowingCreateGame) {
            CreateGolfAppGameView(account: account, golfAppStore: golfAppStore)
        }
        .task {
            await golfAppStore.refresh(authSession: account.authSession)
        }
    }
}

private struct GolfAppGameCard: View {
    let game: GolfAppGame

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(game.name)
                        .font(.headline)
                    Text(game.format.displayGameFormat)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(game.status.capitalized)
                    .font(.caption.bold())
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.green.opacity(0.15), in: Capsule())
            }

            Text(game.players.map(\.displayName).joined(separator: ", "))
                .font(.caption)
                .foregroundStyle(.secondary)

            let teeGroups = Set(game.players.compactMap(\.teeTimeGroup)).sorted()
            if !teeGroups.isEmpty {
                Text(teeGroups.joined(separator: " · "))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            if let courseName = game.courseName {
                Label("\(courseName)\(game.teeName.map { " · \($0)" } ?? "")", systemImage: "flag.2.crossed")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
    }
}

extension String {
    func ifEmpty(_ fallback: String) -> String {
        isEmpty ? fallback : self
    }

    var displayGameFormat: String {
        switch self {
        case "strokePlay": return "Stroke Play"
        case "netStrokePlay": return "Net Stroke Play"
        case "stableford": return "Stableford"
        case "matchPlay": return "Match Play"
        default: return replacingOccurrences(of: "_", with: " ").capitalized
        }
    }
}
