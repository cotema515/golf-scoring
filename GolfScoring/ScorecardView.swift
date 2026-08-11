import SwiftUI

struct ScoreFocus: Hashable {
    let holeNumber: Int
    let golferID: UUID
}

struct ScorecardView: View {
    @ObservedObject var store: MatchStore
    @ObservedObject var account: AccountStore
    let saveRound: (RoundSummary) -> Void
    @State private var selectedHole = 1
    @State private var isSubmitted = false
    @State private var isEditingSubmittedRound = false
    @State private var savedRoundID: UUID?
    @State private var savedHoleSignatures: [Int: String] = [:]
    @State private var lastCheckpointText: String?
    @FocusState private var focusedScore: ScoreFocus?

    private var hole: Hole {
        store.round.holes.first { $0.number == selectedHole } ?? store.round.holes.first ?? Hole(number: 1, par: 4, strokeIndex: 1)
    }
    private var allHolesComplete: Bool { store.round.completedHoles == store.round.holes.count }
    private let holeColumns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 6)
    private let teamOneColor = Color.green
    private let teamTwoColor = Color.blue
    private var orderedGolfers: [Golfer] {
        store.round.golfers.sorted {
            if $0.team == $1.team {
                return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
            return $0.team < $1.team
        }
    }

    init(
        store: MatchStore,
        account: AccountStore,
        savedRoundID: UUID? = nil,
        saveRound: @escaping (RoundSummary) -> Void
    ) {
        self.store = store
        self.account = account
        self.saveRound = saveRound
        _savedRoundID = State(initialValue: savedRoundID)
        _isSubmitted = State(initialValue: savedRoundID != nil)
        _isEditingSubmittedRound = State(initialValue: savedRoundID != nil)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                statusCard

                if isSubmitted && !isEditingSubmittedRound {
                    submittedCard
                } else {
                    holePicker
                    scoreEntryCard
                    navigationButtons
                }
            }
            .padding()
        }
        .navigationTitle(store.round.name)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if focusedScore == nil {
                focusFirstGolfer(on: selectedHole)
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                if isSubmitted {
                    Button(isEditingSubmittedRound ? "Done" : "Edit") {
                        if isEditingSubmittedRound {
                            saveCurrentRound()
                        }
                        isEditingSubmittedRound.toggle()
                    }
                }

                ProfileMenuButton(account: account)
            }
        }
    }

    private var statusCard: some View {
        VStack(spacing: 8) {
            AppLogoMark(size: 46)

            Text(isSubmitted ? "ROUND SUBMITTED" : store.round.statusText)
                .font(.largeTitle.bold())
                .foregroundStyle(.green)
                .multilineTextAlignment(.center)
            Text("Through \(store.round.completedHoles) of \(store.round.holes.count) holes")
                .foregroundStyle(.secondary)
            Text(store.round.date.formatted(.dateTime.month().day().year()))
                .font(.caption)
                .foregroundStyle(.secondary)

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                Label("Stableford side game", systemImage: "star.circle.fill")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)

                ForEach(store.round.stablefordStandings) { standing in
                    HStack {
                        Text(standing.golfer.name)
                        Spacer()
                        Text("\(standing.points) pts")
                            .fontWeight(.semibold)
                            .monospacedDigit()
                    }
                    .font(.caption)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private var submittedCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Scores saved for review", systemImage: "checkmark.circle.fill")
                .font(.headline)
                .foregroundStyle(.green)

            Text("You can still edit the round if someone fat-fingered a score. Golf apps should respect the post-round parking lot audit.")
                .foregroundStyle(.secondary)

            Button {
                isEditingSubmittedRound = true
            } label: {
                Label("Edit Scores", systemImage: "pencil")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private var holePicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Choose Hole")
                    .font(.headline)
                Spacer()
                Text("Par \(hole.par) · HCP \(hole.strokeIndex)")
                    .foregroundStyle(.secondary)
            }

            LazyVGrid(columns: holeColumns, spacing: 8) {
                ForEach(store.round.holes) { courseHole in
                    Button {
                        selectedHole = courseHole.number
                        focusFirstGolfer(on: courseHole.number)
                    } label: {
                        Text("\(courseHole.number)")
                            .font(.subheadline.monospacedDigit().bold())
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 9)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(holeTint(for: courseHole))
                }
            }
        }
    }

    private var scoreEntryCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Hole \(hole.number)")
                        .font(.title2.bold())
                    Text("Enter gross scores. Net is calculated automatically.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            if let lastCheckpointText {
                Label(lastCheckpointText, systemImage: "checkmark.icloud.fill")
                    .font(.caption.bold())
                    .foregroundStyle(.green)
                    .transition(.opacity)
            }

            ForEach(1...2, id: \.self) { team in
                VStack(alignment: .leading, spacing: 10) {
                    Text(store.round.teamName(team).uppercased())
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)

                    ForEach(orderedGolfers.filter { $0.team == team }) { golfer in
                        ScoreEntryRow(
                            golfer: golfer,
                            strokes: store.round.strokes(for: golfer, on: hole),
                            net: store.round.netScore(for: golfer, on: hole),
                            stableford: store.round.stablefordPoints(for: golfer, on: hole),
                            gross: scoreBinding(for: golfer, on: hole),
                            focus: ScoreFocus(holeNumber: hole.number, golferID: golfer.id),
                            focusedScore: $focusedScore
                        )
                    }
                }
            }
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private var navigationButtons: some View {
        VStack(spacing: 12) {
            HStack {
                Button {
                    moveToHole(selectedHole - 1)
                } label: {
                    Label("Previous", systemImage: "chevron.left")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(selectedHole == 1)

                if selectedHole < store.round.holes.count {
                    Button {
                        moveToHole(selectedHole + 1)
                    } label: {
                        Label("Next", systemImage: "chevron.right")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }

            if selectedHole == store.round.holes.count && !isEditingSubmittedRound {
                Button {
                    saveCurrentRound()
                    isSubmitted = true
                    isEditingSubmittedRound = false
                } label: {
                    Label("Submit Round", systemImage: "checkmark.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(!allHolesComplete)

                if !allHolesComplete {
                    Text("Complete all four scores on every hole before submitting.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }

            if isEditingSubmittedRound {
                Button {
                    saveCurrentRound()
                    isEditingSubmittedRound = false
                    isSubmitted = true
                } label: {
                    Label("Save Round", systemImage: "checkmark.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!allHolesComplete)
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Button("Previous") {
                    moveFocusBy(-1)
                }
                .disabled(focusedScore == nil)

                Button("Next") {
                    moveFocusBy(1)
                }
                .disabled(focusedScore == nil)

                Spacer()

                Button("Done") {
                    focusedScore = nil
                }
            }
        }
    }

    private func scoreBinding(for golfer: Golfer, on hole: Hole) -> Binding<String> {
        Binding(
            get: {
                store.round.scores[golfer.id]?[hole.number]?.gross.map(String.init) ?? ""
            },
            set: { newValue in
                let wasComplete = store.round.isHoleComplete(hole)
                let digits = sanitizedScoreText(from: newValue)
                let score = Int(digits)
                store.setScore(score, golferID: golfer.id, holeNumber: hole.number)
                checkpointIfNeeded(for: hole, wasComplete: wasComplete)

                if let score, shouldAutoAdvance(scoreText: digits, score: score) {
                    advanceAfterScore(for: golfer, on: hole)
                }
            }
        )
    }

    private func sanitizedScoreText(from input: String) -> String {
        let digitsOnly = input.filter(\.isNumber)
        guard let firstDigit = digitsOnly.first else { return "" }

        if firstDigit == "1", digitsOnly.dropFirst().first == "0" {
            return "10"
        }

        return String(firstDigit)
    }

    private func shouldAutoAdvance(scoreText: String, score: Int) -> Bool {
        guard (1...10).contains(score) else { return false }
        if score == 1 {
            return false
        }
        return scoreText.count == 1 || score == 10
    }

    private func moveToHole(_ holeNumber: Int) {
        let clampedHole = min(max(1, holeNumber), store.round.holes.count)
        selectedHole = clampedHole
        focusFirstGolfer(on: clampedHole)
    }

    private func focusFirstGolfer(on holeNumber: Int) {
        guard let firstGolfer = orderedGolfers.first else {
            focusedScore = nil
            return
        }
        focusedScore = ScoreFocus(holeNumber: holeNumber, golferID: firstGolfer.id)
    }

    private func advanceAfterScore(for golfer: Golfer, on hole: Hole) {
        guard let currentIndex = orderedGolfers.firstIndex(where: { $0.id == golfer.id }) else {
            focusedScore = nil
            return
        }

        let nextIndex = orderedGolfers.index(after: currentIndex)
        if nextIndex < orderedGolfers.endIndex {
            focusedScore = ScoreFocus(holeNumber: hole.number, golferID: orderedGolfers[nextIndex].id)
        } else if hole.number < store.round.holes.count {
            moveToHole(hole.number + 1)
        } else {
            focusedScore = nil
        }
    }

    private func checkpointIfNeeded(for hole: Hole, wasComplete: Bool) {
        guard store.round.isHoleComplete(hole) else {
            savedHoleSignatures[hole.number] = nil
            return
        }

        let signature = holeSignature(for: hole)
        guard savedHoleSignatures[hole.number] != signature else { return }

        savedHoleSignatures[hole.number] = signature
        saveCurrentRound()
        lastCheckpointText = wasComplete ? "Hole \(hole.number) edit saved" : "Hole \(hole.number) saved"
    }

    private func holeSignature(for hole: Hole) -> String {
        orderedGolfers
            .map { golfer in
                "\(golfer.id.uuidString):\(store.round.scores[golfer.id]?[hole.number]?.gross ?? -1)"
            }
            .joined(separator: "|")
    }

    private func moveFocusBy(_ offset: Int) {
        guard
            let focus = focusedScore,
            let currentIndex = orderedGolfers.firstIndex(where: { $0.id == focus.golferID })
        else {
            focusFirstGolfer(on: selectedHole)
            return
        }

        let nextIndex = currentIndex + offset
        if orderedGolfers.indices.contains(nextIndex) {
            focusedScore = ScoreFocus(holeNumber: selectedHole, golferID: orderedGolfers[nextIndex].id)
        } else if offset > 0, selectedHole < store.round.holes.count {
            moveToHole(selectedHole + 1)
        } else if offset < 0, selectedHole > 1 {
            selectedHole -= 1
            if let lastGolfer = orderedGolfers.last {
                focusedScore = ScoreFocus(holeNumber: selectedHole, golferID: lastGolfer.id)
            }
        } else {
            focusedScore = nil
        }
    }

    private func holeTint(for hole: Hole) -> Color {
        guard store.round.isHoleComplete(hole) else {
            return hole.number == selectedHole ? Color(white: 0.28) : .secondary
        }

        switch store.round.holeWinner(on: hole) {
        case 1:
            return teamOneColor
        case 2:
            return teamTwoColor
        default:
            return .gray
        }
    }

    private func saveCurrentRound() {
        let id = savedRoundID ?? UUID()
        savedRoundID = id
        saveRound(store.round.summary(id: id))
    }
}

struct ScoreEntryRow: View {
    let golfer: Golfer
    let strokes: Int
    let net: Int?
    let stableford: Int?
    @Binding var gross: String
    let focus: ScoreFocus
    @FocusState.Binding var focusedScore: ScoreFocus?

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(golfer.name)
                    .fontWeight(.semibold)
                Text(strokes == 0 ? "No stroke on this hole" : "\(strokes) stroke\(strokes == 1 ? "" : "s") on this hole")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                TextField("–", text: $gross)
                    .keyboardType(.numberPad)
                    .focused($focusedScore, equals: focus)
                    .multilineTextAlignment(.center)
                    .font(.title2.monospacedDigit().bold())
                    .frame(width: 54, height: 44)
                    .background(.background, in: RoundedRectangle(cornerRadius: 10))

                Text(net.map { "Net \($0)" } ?? "Net –")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(stableford.map { "SF \($0)" } ?? "SF –")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
