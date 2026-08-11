import SwiftUI
import PhotosUI
#if canImport(UIKit)
import UIKit
#endif

struct PlayersView: View {
    @ObservedObject var account: AccountStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Players")
                        .font(.title.bold())
                    Text("Everyone with the private app link is in the group for now. No friending, requests, or match codes needed.")
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 12) {
                    Label("Private Group", systemImage: "person.3")
                        .font(.headline)

                    HStack {
                        ProfileAvatar(imageData: account.profile.profileImageData, size: 38)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(account.profile.fullName)
                                .fontWeight(.semibold)
                            Text("You · Index \(account.profile.handicapIndex.map { $0.formatted(.number.precision(.fractionLength(1))) } ?? "—")")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }

                    ForEach(account.friends) { friend in
                        HStack {
                            ProfileAvatar(imageData: friend.profileImageData, size: 38)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(friend.fullName)
                                    .fontWeight(.semibold)
                                Text("Group player · Index \(friend.handicapIndex, format: .number.precision(.fractionLength(1)))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        }
                    }
                }
                .padding()
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 12) {
                    Label("Rounds", systemImage: "link")
                        .font(.headline)
                    Text("For this version, rounds are created from Home. Later, this area can become the place for shared links, invitations, comments, and post-round chirping.")
                        .foregroundStyle(.secondary)
                }
                .padding()
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
            }
            .padding()
        }
        .navigationTitle("Players")
    }
}

struct ProfileView: View {
    @ObservedObject var account: AccountStore
    @State private var firstNameInput = ""
    @State private var lastNameInput = ""
    @State private var handicapIndexInput = ""
    @State private var showProfileError = false
    @State private var showSavedConfirmation = false
    @State private var selectedPhoto: PhotosPickerItem?
    @FocusState private var focusedField: ProfileField?

    private enum ProfileField: Hashable {
        case firstName
        case lastName
        case handicapIndex
    }

    var body: some View {
        Form {
            Section {
                VStack(spacing: 10) {
                    ProfileAvatar(imageData: account.profile.profileImageData, size: 96)

                    PhotosPicker(selection: $selectedPhoto, matching: .images) {
                        Label("Upload / Change Profile Picture", systemImage: "photo")
                    }
                    .buttonStyle(.bordered)

                    if account.profile.profileImageData != nil {
                        Button("Remove Profile Picture", role: .destructive) {
                            account.profile.profileImageData = nil
                            _ = account.saveProfile()
                        }
                        .font(.caption)
                    }
                }
                .frame(maxWidth: .infinity)
                .listRowBackground(Color.clear)
            }

            Section("Your Profile") {
                TextField("First name", text: $firstNameInput)
                    .textContentType(.givenName)
                    .textInputAutocapitalization(.words)
                    .submitLabel(.next)
                    .focused($focusedField, equals: .firstName)
                    .onSubmit {
                        focusedField = .lastName
                    }
                TextField("Last name", text: $lastNameInput)
                    .textContentType(.familyName)
                    .textInputAutocapitalization(.words)
                    .submitLabel(.next)
                    .focused($focusedField, equals: .lastName)
                    .onSubmit {
                        focusedField = .handicapIndex
                    }
                TextField("Handicap Index", text: handicapIndexBinding)
                    .keyboardType(.decimalPad)
                    .focused($focusedField, equals: .handicapIndex)
                LabeledContent("Selected Player", value: draftFullName.isEmpty ? "—" : draftFullName)
            }

            Section("App") {
                LabeledContent("Primary game", value: "2 v 2 net best ball")
                LabeledContent("Side game", value: "Net Stableford")
                LabeledContent("Handicap rule", value: "Low man plays off 0")
            }

            Section {
                Button("Save Changes", action: saveChanges)
                    .frame(maxWidth: .infinity)
                    .fontWeight(.semibold)
                    .disabled(!draftProfileIsComplete)
            }

            Section {
                Button("Sign Out", role: .destructive, action: account.signOut)
            }
        }
        .navigationTitle("Profile")
        .scrollDismissesKeyboard(.interactively)
        .toolbar {
            if focusedField != nil {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") {
                        focusedField = nil
                    }
                }
            }

            ToolbarItemGroup(placement: .keyboard) {
                Button("Previous") {
                    moveProfileFocusBy(-1)
                }
                .disabled(focusedField == nil || focusedField == .firstName)

                Button("Next") {
                    moveProfileFocusBy(1)
                }
                .disabled(focusedField == nil || focusedField == .handicapIndex)

                Spacer()

                Button("Done") {
                    focusedField = nil
                }
            }
        }
        .alert("Profile required", isPresented: $showProfileError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Enter your first name, last name, and Handicap Index before saving.")
        }
        .onAppear {
            loadDraftFromProfile()
        }
        .onChange(of: selectedPhoto) { _, newValue in
            Task {
                guard let data = try? await newValue?.loadTransferable(type: Data.self) else { return }
                await MainActor.run {
                    account.profile.profileImageData = preparedProfileImageData(from: data)
                    if account.saveProfile() {
                        showSavedMessage()
                    }
                }
            }
        }
        .overlay(alignment: .bottom) {
            if showSavedConfirmation {
                Label("Changes saved", systemImage: "checkmark.circle.fill")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(.thinMaterial, in: Capsule())
                    .shadow(radius: 8, y: 4)
                    .padding(.bottom, 20)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

    private func saveChanges() {
        let previousProfile = account.profile
        account.profile.firstName = firstNameInput.trimmingCharacters(in: .whitespacesAndNewlines)
        account.profile.lastName = lastNameInput.trimmingCharacters(in: .whitespacesAndNewlines)
        account.profile.handicapIndex = Double(handicapIndexInput)
        focusedField = nil

        if !account.saveProfile(replacing: previousProfile) {
            showProfileError = true
        } else {
            showSavedMessage()
        }
    }

    private func showSavedMessage() {
        withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
            showSavedConfirmation = true
        }

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_600_000_000)
            withAnimation(.easeOut(duration: 0.2)) {
                showSavedConfirmation = false
            }
        }
    }

    private var draftFullName: String {
        "\(firstNameInput) \(lastNameInput)".trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var draftProfileIsComplete: Bool {
        !firstNameInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !lastNameInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        Double(handicapIndexInput) != nil
    }

    private func loadDraftFromProfile() {
        firstNameInput = account.profile.firstName
        lastNameInput = account.profile.lastName
        if let handicapIndex = account.profile.handicapIndex {
            handicapIndexInput = String(format: "%.1f", handicapIndex)
        } else {
            handicapIndexInput = ""
        }
    }

    private func moveProfileFocusBy(_ offset: Int) {
        let fields: [ProfileField] = [.firstName, .lastName, .handicapIndex]
        guard let focusedField,
              let index = fields.firstIndex(of: focusedField)
        else {
            self.focusedField = .firstName
            return
        }

        let newIndex = min(max(index + offset, fields.startIndex), fields.index(before: fields.endIndex))
        self.focusedField = fields[newIndex]
    }

    private var handicapIndexBinding: Binding<String> {
        Binding(
            get: { handicapIndexInput },
            set: { newValue in
                var hasDecimal = false
                handicapIndexInput = newValue.filter { character in
                    if character.isNumber { return true }
                    if character == ".", !hasDecimal {
                        hasDecimal = true
                        return true
                    }
                    return false
                }
            }
        )
    }

    private func preparedProfileImageData(from data: Data) -> Data {
        #if canImport(UIKit)
        guard let image = UIImage(data: data) else { return data }
        let maxSide: CGFloat = 512
        let largestSide = max(image.size.width, image.size.height)
        guard largestSide > 0 else { return data }

        let scale = min(1, maxSide / largestSide)
        let targetSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)

        let renderer = UIGraphicsImageRenderer(size: targetSize)
        let resizedImage = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }

        return resizedImage.jpegData(compressionQuality: 0.72) ?? data
        #else
        return data
        #endif
    }
}

struct SignInView: View {
    @ObservedObject var account: AccountStore

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                AppLogoMark(size: 92)
                Text("Golf Scoring")
                    .font(.largeTitle.bold())
                Text("Who is using this phone?")
                    .foregroundStyle(.secondary)
            }
            .multilineTextAlignment(.center)
            .padding(.top, 40)
            .padding(.bottom, 18)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                ForEach(account.allGroupPlayers) { player in
                    Button {
                        account.signIn(as: player)
                    } label: {
                        VStack(spacing: 10) {
                            ProfileAvatar(imageData: player.profileImageData, size: 62)

                            VStack(spacing: 3) {
                                Text(player.fullName)
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                Text("Index \(player.handicapIndex, format: .number.precision(.fractionLength(1)))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Label("Select", systemImage: "checkmark.circle")
                                .font(.caption.bold())
                                .foregroundStyle(.green)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18))
                    }
                    .buttonStyle(.plain)
                }
            }

            Text("Pick your profile once. The app remembers it on this phone, and the Bandon history is already loaded.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.top, 18)
        }
        .padding()
    }
}

struct ProfileSetupView: View {
    @ObservedObject var account: AccountStore
    @State private var showProfileError = false
    @State private var firstNameInput = ""
    @State private var lastNameInput = ""
    @State private var handicapIndexInput = ""
    @FocusState private var focusedField: SetupProfileField?

    private enum SetupProfileField: Hashable {
        case firstName
        case lastName
        case handicapIndex
    }

    var body: some View {
        Form {
            Section("Account") {
                HStack {
                    Text("Selected player")
                    Spacer()
                    Text(draftFullName.isEmpty ? "Not selected" : draftFullName)
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                ForEach(account.allGroupPlayers) { player in
                    Button {
                        applyPreloadedProfile(player)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(player.fullName)
                                    .fontWeight(.semibold)
                                Text("Index \(player.handicapIndex, format: .number.precision(.fractionLength(1))) · Bandon history loaded")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            if selectedPlayerMatches(player) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                            } else {
                                Image(systemName: "person.badge.plus")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            } header: {
                Text("Preloaded Cote Accounts")
            } footer: {
                Text("Pick your name once. The app remembers it on this phone, and the Bandon trip history is already included for all four players.")
            }

            Section {
                TextField("First name", text: $firstNameInput)
                    .textContentType(.givenName)
                    .textInputAutocapitalization(.words)
                    .submitLabel(.next)
                    .focused($focusedField, equals: .firstName)
                    .onSubmit {
                        focusedField = .lastName
                    }
                TextField("Last name", text: $lastNameInput)
                    .textContentType(.familyName)
                    .textInputAutocapitalization(.words)
                    .submitLabel(.next)
                    .focused($focusedField, equals: .lastName)
                    .onSubmit {
                        focusedField = .handicapIndex
                    }
                TextField("Handicap Index", text: handicapIndexBinding)
                    .keyboardType(.decimalPad)
                    .focused($focusedField, equals: .handicapIndex)
            } header: {
                Text("Golfer Profile")
            } footer: {
                Text("Enter your current Handicap Index. You can adjust it before each match if needed.")
            }

            Section {
                Button("Save Profile", action: saveProfile)
                    .frame(maxWidth: .infinity)
                    .fontWeight(.semibold)
                    .disabled(!draftProfileIsComplete)
            }
        }
        .navigationTitle("Your Profile")
        .scrollDismissesKeyboard(.interactively)
        .toolbar {
            if focusedField != nil {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") {
                        focusedField = nil
                    }
                }
            }

            ToolbarItemGroup(placement: .keyboard) {
                Button("Previous") {
                    moveSetupFocusBy(-1)
                }
                .disabled(focusedField == nil || focusedField == .firstName)

                Button("Next") {
                    moveSetupFocusBy(1)
                }
                .disabled(focusedField == nil || focusedField == .handicapIndex)

                Spacer()

                Button("Done") {
                    focusedField = nil
                }
            }
        }
        .alert("Profile required", isPresented: $showProfileError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Enter your first name, last name, and Handicap Index before continuing.")
        }
        .onAppear {
            loadDraftFromProfile()
        }
    }

    private func saveProfile() {
        account.profile.firstName = firstNameInput.trimmingCharacters(in: .whitespacesAndNewlines)
        account.profile.lastName = lastNameInput.trimmingCharacters(in: .whitespacesAndNewlines)
        account.profile.handicapIndex = Double(handicapIndexInput)
        focusedField = nil

        guard account.saveProfile() else {
            showProfileError = true
            return
        }
    }

    private func applyPreloadedProfile(_ player: FriendProfile) {
        account.applyPreloadedProfile(player)
        firstNameInput = player.firstName
        lastNameInput = player.lastName
        handicapIndexInput = String(format: "%.1f", player.handicapIndex)
    }

    private var draftFullName: String {
        "\(firstNameInput) \(lastNameInput)".trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var draftProfileIsComplete: Bool {
        !firstNameInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !lastNameInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        Double(handicapIndexInput) != nil
    }

    private func selectedPlayerMatches(_ player: FriendProfile) -> Bool {
        if let profileKey = account.profile.playerKey,
           let playerKey = player.playerKey,
           !profileKey.isEmpty,
           !playerKey.isEmpty {
            return profileKey == playerKey
        }

        return firstNameInput.localizedCaseInsensitiveCompare(player.firstName) == .orderedSame &&
        lastNameInput.localizedCaseInsensitiveCompare(player.lastName) == .orderedSame
    }

    private func loadDraftFromProfile() {
        firstNameInput = account.profile.firstName
        lastNameInput = account.profile.lastName
        if let handicapIndex = account.profile.handicapIndex {
            handicapIndexInput = String(format: "%.1f", handicapIndex)
        } else {
            handicapIndexInput = ""
        }
    }

    private var handicapIndexBinding: Binding<String> {
        Binding(
            get: { handicapIndexInput },
            set: { newValue in
                var hasDecimal = false
                handicapIndexInput = newValue.filter { character in
                    if character.isNumber { return true }
                    if character == ".", !hasDecimal {
                        hasDecimal = true
                        return true
                    }
                    return false
                }
            }
        )
    }

    private func moveSetupFocusBy(_ offset: Int) {
        let fields: [SetupProfileField] = [.firstName, .lastName, .handicapIndex]
        guard let focusedField,
              let index = fields.firstIndex(of: focusedField)
        else {
            self.focusedField = .firstName
            return
        }

        let newIndex = min(max(index + offset, fields.startIndex), fields.index(before: fields.endIndex))
        self.focusedField = fields[newIndex]
    }
}
