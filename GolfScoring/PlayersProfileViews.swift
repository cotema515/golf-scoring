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
    @State private var usernameInput = ""
    @State private var firstNameInput = ""
    @State private var lastNameInput = ""
    @State private var handicapIndexInput = ""
    @State private var showProfileError = false
    @State private var showSavedConfirmation = false
    @State private var selectedPhoto: PhotosPickerItem?
    @FocusState private var focusedField: ProfileField?

    private enum ProfileField: Hashable {
        case username
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
                TextField("Username", text: $usernameInput)
                    .textContentType(.username)
                    .textInputAutocapitalization(.never)
                    .submitLabel(.next)
                    .focused($focusedField, equals: .username)
                    .onSubmit {
                        focusedField = .firstName
                    }
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
                .disabled(focusedField == nil || focusedField == .username)

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
            Text("Enter your username, first name, last name, and Handicap Index before saving.")
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
        account.profile.username = usernameInput.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
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
        !usernameInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        Double(handicapIndexInput) != nil
    }

    private func loadDraftFromProfile() {
        usernameInput = account.profile.username
        firstNameInput = account.profile.firstName
        lastNameInput = account.profile.lastName
        if let handicapIndex = account.profile.handicapIndex {
            handicapIndexInput = String(format: "%.1f", handicapIndex)
        } else {
            handicapIndexInput = ""
        }
    }

    private func moveProfileFocusBy(_ offset: Int) {
        let fields: [ProfileField] = [.username, .firstName, .lastName, .handicapIndex]
        guard let focusedField,
              let index = fields.firstIndex(of: focusedField)
        else {
            self.focusedField = .username
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
    @State private var selectedMode: AuthScreenMode = .login
    @State private var loginIdentifier = ""
    @State private var loginPassword = ""
    @State private var username = ""
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var email = ""
    @State private var password = ""
    @State private var handicapIndex = ""
    @State private var isWorking = false
    @FocusState private var focusedField: AuthField?

    private enum AuthScreenMode: String, CaseIterable, Identifiable {
        case login = "Log In"
        case create = "Create Profile"

        var id: String { rawValue }
    }

    private enum AuthField: Hashable {
        case loginIdentifier
        case loginPassword
        case username
        case firstName
        case lastName
        case email
        case password
        case handicapIndex
    }

    var body: some View {
        Form {
            Section {
                VStack(spacing: 8) {
                AppLogoMark(size: 92)
                Text("Golf Scoring")
                    .font(.largeTitle.bold())
                    Text("Log in or create your golfer profile.")
                    .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)
                .listRowBackground(Color.clear)
            }

            Section {
                Picker("Action", selection: $selectedMode) {
                    ForEach(AuthScreenMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
            }

            if selectedMode == .login {
                Section {
                    TextField("Email or username", text: $loginIdentifier)
                        .textInputAutocapitalization(.never)
                        .textContentType(.username)
                        .submitLabel(.next)
                        .focused($focusedField, equals: .loginIdentifier)
                        .onSubmit { focusedField = .loginPassword }
                    SecureField("Password", text: $loginPassword)
                        .textContentType(.password)
                        .submitLabel(.go)
                        .focused($focusedField, equals: .loginPassword)
                        .onSubmit { Task { await login() } }
                } header: {
                    Text("Log In")
                } footer: {
                    Text("Cote users can log in with their email or username. After login, Cote users can choose the family game or general golf.")
                }

                Section {
                    Button {
                        Task { await login() }
                    } label: {
                        authButtonLabel("Log In")
                    }
                    .disabled(isWorking || loginIdentifier.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || loginPassword.isEmpty)
                }
            } else {
                Section {
                    TextField("Username", text: $username)
                        .textInputAutocapitalization(.never)
                        .textContentType(.username)
                        .submitLabel(.next)
                        .focused($focusedField, equals: .username)
                        .onSubmit { focusedField = .firstName }
                    TextField("First name", text: $firstName)
                        .textContentType(.givenName)
                        .textInputAutocapitalization(.words)
                        .submitLabel(.next)
                        .focused($focusedField, equals: .firstName)
                        .onSubmit { focusedField = .lastName }
                    TextField("Last name", text: $lastName)
                        .textContentType(.familyName)
                        .textInputAutocapitalization(.words)
                        .submitLabel(.next)
                        .focused($focusedField, equals: .lastName)
                        .onSubmit { focusedField = .email }
                    TextField("Email", text: $email)
                        .textInputAutocapitalization(.never)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .submitLabel(.next)
                        .focused($focusedField, equals: .email)
                        .onSubmit { focusedField = .password }
                    SecureField("Password", text: $password)
                        .textContentType(.newPassword)
                        .submitLabel(.next)
                        .focused($focusedField, equals: .password)
                        .onSubmit { focusedField = .handicapIndex }
                    TextField("Handicap Index", text: handicapIndexBinding)
                        .keyboardType(.decimalPad)
                        .focused($focusedField, equals: .handicapIndex)
                } header: {
                    Text("Create Profile")
                } footer: {
                    Text("If the name matches a Cote family player, the profile is linked to the Cote Family Game. Otherwise it starts as a general golf profile.")
                }

                Section {
                    Button {
                        Task { await createProfile() }
                    } label: {
                        authButtonLabel("Create Profile")
                    }
                    .disabled(isWorking || !createProfileIsValid)
                }
            }

            if let error = account.authErrorMessage, !error.isEmpty {
                Section {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .font(.footnote)
                        .foregroundStyle(.orange)
                }
            }
        }
        .navigationTitle("Welcome")
        .scrollDismissesKeyboard(.interactively)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { focusedField = nil }
            }
        }
    }

    private func authButtonLabel(_ title: String) -> some View {
        HStack {
            Spacer()
            if isWorking {
                ProgressView()
            } else {
                Text(title)
                    .fontWeight(.semibold)
            }
            Spacer()
        }
    }

    private func login() async {
        guard !isWorking else { return }
        focusedField = nil
        isWorking = true
        _ = await account.login(loginIdentifier: loginIdentifier, password: loginPassword)
        isWorking = false
    }

    private func createProfile() async {
        guard !isWorking, let handicap = Double(handicapIndex) else { return }
        focusedField = nil
        isWorking = true
        _ = await account.createProfile(
            username: username,
            firstName: firstName,
            lastName: lastName,
            email: email,
            password: password,
            handicapIndex: handicap
        )
        isWorking = false
    }

    private var createProfileIsValid: Bool {
        !username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !firstName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !lastName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        password.count >= 6 &&
        Double(handicapIndex) != nil
    }

    private var handicapIndexBinding: Binding<String> {
        Binding(
            get: { handicapIndex },
            set: { newValue in
                var hasDecimal = false
                handicapIndex = newValue.filter { character in
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
}

struct GameModeChoiceView: View {
    @ObservedObject var account: AccountStore

    var body: some View {
        VStack(spacing: 18) {
            AppLogoMark(size: 88)

            VStack(spacing: 6) {
                Text("Welcome, \(account.profile.displayName)")
                    .font(.title.bold())
                Text("Where do you want to go?")
                    .foregroundStyle(.secondary)
            }
            .multilineTextAlignment(.center)

            VStack(spacing: 12) {
                gameModeButton(.coteFamily)
                gameModeButton(.general)
            }
            .padding(.top, 12)

            Button("Sign Out", role: .destructive) {
                account.signOut()
            }
            .padding(.top, 8)
        }
        .padding()
    }

    private func gameModeButton(_ mode: AppGameMode) -> some View {
        Button {
            account.chooseGameMode(mode)
        } label: {
            HStack(spacing: 14) {
                Image(systemName: mode == .coteFamily ? "person.3.fill" : "flag.2.crossed.fill")
                    .font(.title2)
                    .foregroundStyle(.green)
                    .frame(width: 34)
                VStack(alignment: .leading, spacing: 4) {
                    Text(mode.title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(mode.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(.tertiary)
            }
            .padding()
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18))
        }
        .buttonStyle(.plain)
    }
}

struct ProfileSetupView: View {
    @ObservedObject var account: AccountStore
    @State private var showProfileError = false
    @State private var firstNameInput = ""
    @State private var lastNameInput = ""
    @State private var emailInput = ""
    @State private var handicapIndexInput = ""
    @FocusState private var focusedField: SetupProfileField?

    private enum SetupProfileField: Hashable {
        case firstName
        case lastName
        case email
        case handicapIndex
    }

    var body: some View {
        Form {
            Section("Account") {
                HStack {
                    Text("Profile type")
                    Spacer()
                    Text(account.profile.profileType.title)
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Text("Selected player")
                    Spacer()
                    Text(draftFullName.isEmpty ? "Not selected" : draftFullName)
                        .foregroundStyle(.secondary)
                }
            }

            if account.profile.profileType == .coteCup || account.profile.playerKey != nil {
                Section {
                    ForEach(account.allGroupPlayers) { player in
                        Button {
                            applyPreloadedProfile(player)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(player.fullName)
                                        .fontWeight(.semibold)
                                    Text("Index \(player.handicapIndex, format: .number.precision(.fractionLength(1))) · Cote Cup history linked")
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
                    Text("Pick your name once. The app remembers the linked player on this phone.")
                }
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
                        focusedField = .email
                    }
                TextField("Email", text: $emailInput)
                    .textContentType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                    .submitLabel(.next)
                    .focused($focusedField, equals: .email)
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
        account.profile.email = emailInput.trimmingCharacters(in: .whitespacesAndNewlines)
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
        emailInput = account.profile.email
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
        emailInput = account.profile.email
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
        let fields: [SetupProfileField] = [.firstName, .lastName, .email, .handicapIndex]
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
