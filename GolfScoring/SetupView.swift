import SwiftUI

struct SetupView: View {
    @ObservedObject var store: MatchStore
    @ObservedObject var account: AccountStore
    let isEditingExistingRound: Bool
    let start: () -> Void
    let cancel: () -> Void
    @State private var handicapIndexInputs: [UUID: String] = [:]
    @State private var showHandicapError = false
    @State private var selectedCourseID = CourseCatalogEntry.courses.first?.id ?? ""
    @State private var selectedTeeName = CourseCatalogEntry.courses.first?.defaultTee.name ?? ""
    @State private var roundDate = Date()
    @State private var courseSearchText = ""
    @State private var selectedCourseRegion = "All"
    @FocusState private var focusedHandicapGolferID: UUID?
    @FocusState private var isCourseSearchFocused: Bool

    private let courseCatalog = CourseCatalogEntry.courses

    private var allSetupEntered: Bool {
        guard
            !store.round.course.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            !store.round.course.tee.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            store.round.course.par > 0,
            store.round.course.rating > 0,
            (55...155).contains(store.round.course.slope)
        else { return false }

        return store.round.golfers.allSatisfy { golfer in
            let cleanName = golfer.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard
                !cleanName.isEmpty,
                !cleanName.hasPrefix("Player "),
                let input = handicapIndexInputs[golfer.id]?.trimmingCharacters(in: .whitespacesAndNewlines),
                !input.isEmpty,
                Double(input) != nil
            else { return false }
            return true
        }
    }

    var body: some View {
        Form {
            Section {
                HStack {
                    Spacer()
                    AppLogoMark(size: 72)
                    Spacer()
                }
                .listRowBackground(Color.clear)
            }

            Section {
                TextField("Search courses", text: $courseSearchText)
                    .textInputAutocapitalization(.words)
                    .submitLabel(.done)
                    .focused($isCourseSearchFocused)
                    .onSubmit {
                        isCourseSearchFocused = false
                    }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(courseRegions, id: \.self) { region in
                            Button {
                                selectedCourseRegion = region
                            } label: {
                                Text(region)
                                    .font(.caption.weight(.semibold))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(
                                        selectedCourseRegion == region ? Color.green.opacity(0.2) : Color.secondary.opacity(0.12),
                                        in: Capsule()
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                if filteredCourses.isEmpty {
                    ContentUnavailableView(
                        "No matching courses",
                        systemImage: "magnifyingglass",
                        description: Text("Try a different search or region.")
                    )
                } else {
                    VStack(spacing: 10) {
                        ForEach(filteredCourses) { course in
                            CourseSelectionCard(
                                course: course,
                                isSelected: selectedCourseID == course.id
                            ) {
                                selectCourse(course)
                            }
                        }
                    }
                    .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
                }

                if let selectedCourse {
                    Picker("Tee", selection: $selectedTeeName) {
                        ForEach(selectedCourse.tees) { tee in
                            Text(tee.setupName).tag(tee.name)
                        }
                    }
                }

                HStack {
                    Text("Location")
                    Spacer()
                    Text(selectedCourse?.location ?? "Kiawah Island, SC")
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Text("Tee")
                    Spacer()
                    Text(store.round.course.tee)
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Text("Par")
                    Spacer()
                    Text("\(store.round.course.par)")
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Text("Distance")
                    Spacer()
                    Text(store.round.course.yardage > 0 ? "\(store.round.course.yardage) yards" : "—")
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Course")
            } footer: {
                Text("Course catalog fills in par, hole handicaps, tee distance, rating, and slope for the handicap math.")
            }

            Section {
                DateSelectionButton(title: "Played on", date: $roundDate)
            } header: {
                Text("Round Date")
            } footer: {
                Text("Defaults to today. Change it if you are entering a past round.")
            }

            ForEach(1...2, id: \.self) { team in
                Section(teamName(for: team)) {
                    ForEach($store.round.golfers) { $golfer in
                        if golfer.team == team {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Menu {
                                        ForEach(account.allGroupPlayers) { player in
                                            Button(player.fullName) {
                                                applyPlayer(player.fullName, handicapIndex: player.handicapIndex, to: golfer.id)
                                            }
                                        }

                                        Divider()

                                        Button("Clear Slot", role: .destructive) {
                                            clearPlayer(golfer.id)
                                        }
                                    } label: {
                                        HStack(spacing: 6) {
                                            ProfileAvatar(imageData: account.profileImageData(for: golfer.name), size: 28)
                                            Text(golfer.name)
                                                .foregroundStyle(golfer.name.hasPrefix("Player ") ? .secondary : .primary)
                                            Image(systemName: "chevron.down")
                                                .font(.caption2.bold())
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    Spacer()
                                    Text("Index")
                                        .foregroundStyle(.secondary)
                                    TextField("Required", text: handicapIndexBinding(for: golfer.id))
                                        .keyboardType(.decimalPad)
                                        .focused($focusedHandicapGolferID, equals: golfer.id)
                                        .frame(width: 86)
                                        .multilineTextAlignment(.trailing)
                                        .onTapGesture {
                                            clearDefaultHandicapIfNeeded(for: golfer.id)
                                        }
                                }

                                HStack {
                                    Text("Course HCP")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                    Text(courseHandicapText(for: golfer.id))
                                        .font(.caption.monospacedDigit().bold())
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }

            Section {
                Button(isEditingExistingRound ? "Continue to Scores" : "Start Match", action: startIfReady)
                    .frame(maxWidth: .infinity)
                    .fontWeight(.semibold)
                    .disabled(!allSetupEntered)
            } footer: {
                Text("Every player must enter a Handicap Index before joining. The app calculates course handicaps from the selected course rating and slope.")
            }
        }
        .navigationTitle(isEditingExistingRound ? "Edit Round" : "Start Round")
        .navigationBarBackButtonHidden(true)
        .scrollDismissesKeyboard(.interactively)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Cancel", role: .cancel, action: cancel)
            }

            ToolbarItem(placement: .topBarTrailing) {
                ProfileMenuButton(account: account)
            }

            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    focusedHandicapGolferID = nil
                    isCourseSearchFocused = false
                }
            }
        }
        .alert("Setup required", isPresented: $showHandicapError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Enter the course, tee, rating, slope, par, and all four Handicap Indexes before starting the match.")
        }
        .onAppear {
            syncSelectionsFromRound()
            if handicapIndexInputs.isEmpty {
                handicapIndexInputs = Dictionary(uniqueKeysWithValues: store.round.golfers.map { golfer in
                    (golfer.id, String(format: "%.1f", golfer.handicapIndex))
                })
            }
            if !isEditingExistingRound {
                applySelectedCourse()
            }
            prefillCurrentPlayer()
            roundDate = store.round.date
        }
        .onChange(of: selectedCourseID) { _, _ in
            selectedTeeName = selectedCourse?.defaultTee.name ?? ""
            applySelectedCourse()
        }
        .onChange(of: selectedTeeName) { _, _ in
            applySelectedCourse()
        }
        .onChange(of: focusedHandicapGolferID) { _, newValue in
            if let newValue {
                clearDefaultHandicapIfNeeded(for: newValue)
            }
        }
    }

    private var selectedCourse: CourseCatalogEntry? {
        courseCatalog.first { $0.id == selectedCourseID }
    }

    private var courseRegions: [String] {
        ["All"] + Array(Set(courseCatalog.map(\.courseRegion))).sorted()
    }

    private var filteredCourses: [CourseCatalogEntry] {
        let cleanSearch = courseSearchText.trimmingCharacters(in: .whitespacesAndNewlines)

        return courseCatalog.filter { course in
            let matchesRegion = selectedCourseRegion == "All" || course.courseRegion == selectedCourseRegion
            let matchesSearch = cleanSearch.isEmpty ||
                course.name.localizedCaseInsensitiveContains(cleanSearch) ||
                course.location.localizedCaseInsensitiveContains(cleanSearch)

            return matchesRegion && matchesSearch
        }
    }

    private func selectCourse(_ course: CourseCatalogEntry) {
        selectedCourseID = course.id
        selectedTeeName = course.defaultTee.name
        applySelectedCourse()
    }

    private func syncSelectionsFromRound() {
        if let matchingCourse = courseCatalog.first(where: { courseMatches($0, roundCourseName: store.round.course.name) }) {
            selectedCourseID = matchingCourse.id
            if matchingCourse.tees.contains(where: { $0.name == store.round.course.tee }) {
                selectedTeeName = store.round.course.tee
            } else if selectedTeeName.isEmpty {
                selectedTeeName = matchingCourse.defaultTee.name
            }
        } else if selectedTeeName.isEmpty {
            selectedTeeName = selectedCourse?.defaultTee.name ?? ""
        }
    }

    private func courseMatches(_ course: CourseCatalogEntry, roundCourseName: String) -> Bool {
        let catalogName = normalizedCourseName(course.name)
        let savedName = normalizedCourseName(roundCourseName)

        return catalogName == savedName ||
            savedName.hasPrefix(catalogName) ||
            catalogName.hasPrefix(savedName)
    }

    private func normalizedCourseName(_ name: String) -> String {
        name
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .joined()
    }

    private func teamName(for team: Int) -> String {
        store.round.teamName(team)
    }

    private func handicapIndexBinding(for golferID: UUID) -> Binding<String> {
        Binding(
            get: { handicapIndexInputs[golferID, default: ""] },
            set: { newValue in
                var hasDecimal = false
                handicapIndexInputs[golferID] = newValue.filter { character in
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

    private func clearDefaultHandicapIfNeeded(for golferID: UUID) {
        let value = handicapIndexInputs[golferID, default: ""]
        if value == "0.0" || value == "0" {
            handicapIndexInputs[golferID] = ""
        }
    }

    private func courseHandicapText(for golferID: UUID) -> String {
        guard
            let input = handicapIndexInputs[golferID],
            let handicapIndex = Double(input)
        else { return "—" }

        return "\(store.round.calculatedCourseHandicap(for: handicapIndex))"
    }

    private func slotNumber(for golferID: UUID) -> Int {
        (store.round.golfers.firstIndex { $0.id == golferID } ?? 0) + 1
    }

    private func applyPlayer(_ name: String, handicapIndex: Double?, to golferID: UUID) {
        guard let index = store.round.golfers.firstIndex(where: { $0.id == golferID }) else { return }
        store.round.golfers[index].name = name
        if let handicapIndex {
            handicapIndexInputs[golferID] = String(format: "%.1f", handicapIndex)
        }
    }

    private func clearPlayer(_ golferID: UUID) {
        guard let index = store.round.golfers.firstIndex(where: { $0.id == golferID }) else { return }
        store.round.golfers[index].name = "Player \(slotNumber(for: golferID))"
        handicapIndexInputs[golferID] = ""
    }

    private func startIfReady() {
        guard allSetupEntered else {
            showHandicapError = true
            return
        }

        for index in store.round.golfers.indices {
            let id = store.round.golfers[index].id
            let handicapIndex = Double(handicapIndexInputs[id] ?? "") ?? 0
            store.round.golfers[index].handicapIndex = handicapIndex
            store.round.golfers[index].courseHandicap = store.round.calculatedCourseHandicap(for: handicapIndex)
            account.updateHandicapIndex(for: store.round.golfers[index].name, to: handicapIndex)
        }
        store.round.date = roundDate
        store.round.name = Self.roundName(courseName: store.round.course.name, date: roundDate)
        start()
    }

    private static func roundName(courseName: String, date: Date) -> String {
        let cleanCourseName = courseName.trimmingCharacters(in: .whitespacesAndNewlines)
        let formattedDate = date.formatted(.dateTime.month(.abbreviated).day().year())
        return "\(cleanCourseName) · \(formattedDate)"
    }

    private func applySelectedCourse() {
        guard let course = selectedCourse else { return }
        let tee = course.tee(named: selectedTeeName)
        var setup = course.setup(for: tee)
        setup.name = displayCourseName(for: course)
        store.round.course = setup
        store.round.holes = course.holes
    }

    private func displayCourseName(for course: CourseCatalogEntry) -> String {
        let existingName = store.round.course.name.trimmingCharacters(in: .whitespacesAndNewlines)

        if !existingName.isEmpty,
           normalizedCourseName(existingName) != normalizedCourseName(course.name),
           courseMatches(course, roundCourseName: existingName) {
            return existingName
        }

        return course.name
    }

    private func prefillCurrentPlayer() {
        guard let firstGolfer = store.round.golfers.first else { return }
        if firstGolfer.name.hasPrefix("Player "), !account.profile.fullName.isEmpty {
            store.round.golfers[0].name = account.profile.fullName
        }
        if handicapIndexInputs[firstGolfer.id, default: ""].isEmpty,
           let handicapIndex = account.profile.handicapIndex {
            handicapIndexInputs[firstGolfer.id] = String(format: "%.1f", handicapIndex)
        }
        if ["", "0", "0.0"].contains(handicapIndexInputs[firstGolfer.id, default: ""]),
           let handicapIndex = account.profile.handicapIndex,
           !account.profile.fullName.isEmpty {
            handicapIndexInputs[firstGolfer.id] = String(format: "%.1f", handicapIndex)
        }
    }
}

struct CourseSelectionCard: View {
    let course: CourseCatalogEntry
    let isSelected: Bool
    let select: () -> Void

    var body: some View {
        Button(action: select) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? .green : .secondary)

                VStack(alignment: .leading, spacing: 6) {
                    Text(course.name)
                        .font(.subheadline.bold())
                        .foregroundStyle(.primary)

                    Text("\(course.location) · \(course.defaultTee.yardage) yds from \(course.defaultTee.name)")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("Par \(course.defaultTee.par) · \(course.defaultTee.rating.formatted(.number.precision(.fractionLength(1)))) / \(course.defaultTee.slope)")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .padding(12)
            .background(
                isSelected ? Color.green.opacity(0.13) : Color.secondary.opacity(0.08),
                in: RoundedRectangle(cornerRadius: 12)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.green.opacity(0.55) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

extension CourseCatalogEntry {
    var courseRegion: String {
        if location.contains("SC") { return "Kiawah" }
        if location.contains("OR") { return "Bandon" }
        if location.contains("FL") { return "Florida" }
        if location.contains("MA") || location.contains("RI") { return "Northeast" }
        if location.contains("WI") { return "Midwest" }
        return "Other"
    }
}
