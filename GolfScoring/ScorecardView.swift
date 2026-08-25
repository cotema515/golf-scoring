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
    @State private var didConfigureInitialHole = false
    @FocusState private var focusedScore: ScoreFocus?

    private var hole: Hole {
        store.round.holes.first { $0.number == selectedHole } ?? store.round.holes.first ?? Hole(number: 1, par: 4, strokeIndex: 1)
    }
    private var allHolesComplete: Bool { store.round.completedHoles == store.round.holes.count }
    private var holeNumbers: [Int] {
        store.round.holes.map(\.number).sorted()
    }
    private var isFirstSelectedHole: Bool {
        selectedHole == holeNumbers.first
    }
    private var isLastSelectedHole: Bool {
        selectedHole == holeNumbers.last
    }
    private let holeColumns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 6)
    private let teamOneColor = AppColors.joshMatt
    private let teamTwoColor = AppColors.jeffShane
    private var orderedGolfers: [Golfer] {
        store.round.golfers
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
                        .id(selectedHole)
                    navigationButtons
                }
            }
            .padding()
        }
        .navigationTitle(store.round.name)
        .navigationBarTitleDisplayMode(.inline)
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
        .onAppear {
            configureInitialHole()
        }
    }

    private var statusCard: some View {
        VStack(spacing: 8) {
            AppLogoMark(size: 46)

            Text(isSubmitted ? "ROUND SUBMITTED" : store.round.statusText)
                .font(.largeTitle.bold())
                .foregroundStyle(statusColor)
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
                        moveToHole(courseHole.number, focusFirstScore: false)
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

            VStack(alignment: .leading, spacing: 10) {
                Text("Score entry order")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)

                ForEach(orderedGolfers) { golfer in
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
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private var navigationButtons: some View {
        VStack(spacing: 12) {
            HStack {
                Button {
                    moveToAdjacentHole(offset: -1, focusFirstScore: false)
                } label: {
                    Label("Previous", systemImage: "chevron.left")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(isFirstSelectedHole)

                if !isLastSelectedHole {
                    Button {
                        moveToAdjacentHole(offset: 1, focusFirstScore: false)
                    } label: {
                        Label("Next", systemImage: "chevron.right")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }

            if isLastSelectedHole && !isEditingSubmittedRound {
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
                let currentValue = store.round.scores[golfer.id]?[hole.number]?.gross.map(String.init) ?? ""
                let digits = sanitizedScoreText(from: newValue, replacing: currentValue)
                let score = Int(digits)
                store.setScore(score, golferID: golfer.id, holeNumber: hole.number)
                checkpointIfNeeded(for: hole, wasComplete: wasComplete)

                if wasComplete {
                    focusedScore = nil
                    return
                }

                if let score, shouldAutoAdvance(scoreText: digits, score: score) {
                    advanceAfterScore(for: golfer, on: hole, wasComplete: wasComplete)
                }
            }
        )
    }

    private func sanitizedScoreText(from input: String, replacing currentValue: String) -> String {
        let digitsOnly = input.filter(\.isNumber)
        guard let firstDigit = digitsOnly.first else { return "" }

        if digitsOnly == "10" || digitsOnly.hasSuffix("10") {
            return "10"
        }

        let currentDigits = currentValue.filter(\.isNumber)
        if !currentDigits.isEmpty,
           digitsOnly.hasPrefix(currentDigits),
           digitsOnly.count > currentDigits.count,
           let typedDigit = digitsOnly.dropFirst(currentDigits.count).last {
            return String(typedDigit)
        }

        if digitsOnly.count > 1, let lastDigit = digitsOnly.last {
            return String(lastDigit)
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

    private func moveToHole(_ holeNumber: Int, focusFirstScore: Bool = false) {
        let availableHoles = holeNumbers
        guard !availableHoles.isEmpty else { return }
        let targetHole = availableHoles.contains(holeNumber) ? holeNumber : nearestHoleNumber(to: holeNumber, in: availableHoles)
        focusedScore = nil
        withAnimation(.snappy) {
            selectedHole = targetHole
        }
        if focusFirstScore {
            DispatchQueue.main.async {
                focusFirstGolfer(on: targetHole)
            }
        }
    }

    private func moveToAdjacentHole(offset: Int, focusFirstScore: Bool = false) {
        guard let currentIndex = holeNumbers.firstIndex(of: selectedHole) else {
            moveToHole(selectedHole, focusFirstScore: focusFirstScore)
            return
        }

        let nextIndex = currentIndex + offset
        guard holeNumbers.indices.contains(nextIndex) else { return }
        moveToHole(holeNumbers[nextIndex], focusFirstScore: focusFirstScore)
    }

    private func nearestHoleNumber(to requestedHole: Int, in holes: [Int]) -> Int {
        holes.min { abs($0 - requestedHole) < abs($1 - requestedHole) } ?? requestedHole
    }

    private func configureInitialHole() {
        guard !didConfigureInitialHole else { return }
        didConfigureInitialHole = true

        if let savedRoundID {
            isSubmitted = allHolesComplete
            isEditingSubmittedRound = true
            self.savedRoundID = savedRoundID
        }

        if !holeNumbers.contains(selectedHole) {
            selectedHole = holeNumbers.first ?? 1
        }

        if !allHolesComplete,
           let firstIncompleteHole = store.round.holes.sorted(by: { $0.number < $1.number }).first(where: { !store.round.isHoleComplete($0) }) {
            selectedHole = firstIncompleteHole.number
        }
    }

    private func focusFirstGolfer(on holeNumber: Int) {
        guard let firstGolfer = orderedGolfers.first else {
            focusedScore = nil
            return
        }
        focusedScore = ScoreFocus(holeNumber: holeNumber, golferID: firstGolfer.id)
    }

    private func advanceAfterScore(for golfer: Golfer, on hole: Hole, wasComplete: Bool) {
        if wasComplete {
            focusedScore = nil
            return
        }

        if store.round.isHoleComplete(hole) {
            moveToNextIncompleteHole(after: hole.number)
            return
        }

        guard let currentIndex = orderedGolfers.firstIndex(where: { $0.id == golfer.id }) else {
            focusedScore = nil
            return
        }

        let nextIndex = orderedGolfers.index(after: currentIndex)
        if nextIndex < orderedGolfers.endIndex,
           store.round.scores[orderedGolfers[nextIndex].id]?[hole.number]?.gross == nil {
            focusedScore = ScoreFocus(holeNumber: hole.number, golferID: orderedGolfers[nextIndex].id)
            return
        }

        if let nextMissingGolfer = orderedGolfers.first(where: { store.round.scores[$0.id]?[hole.number]?.gross == nil }) {
            focusedScore = ScoreFocus(holeNumber: hole.number, golferID: nextMissingGolfer.id)
            return
        }

        focusedScore = nil
    }

    private func moveToNextIncompleteHole(after holeNumber: Int) {
        if let nextIncompleteHole = store.round.holes
            .sorted(by: { $0.number < $1.number })
            .first(where: { $0.number > holeNumber && !store.round.isHoleComplete($0) }) {
            moveToHole(nextIncompleteHole.number, focusFirstScore: true)
            return
        }

        if let firstIncompleteHole = store.round.holes
            .sorted(by: { $0.number < $1.number })
            .first(where: { !store.round.isHoleComplete($0) }) {
            moveToHole(firstIncompleteHole.number, focusFirstScore: true)
            return
        }

        if let lastHole = holeNumbers.last {
            moveToHole(lastHole, focusFirstScore: false)
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
        } else if offset > 0, !isLastSelectedHole {
            moveToAdjacentHole(offset: 1, focusFirstScore: true)
        } else if offset < 0, !isFirstSelectedHole {
            moveToAdjacentHole(offset: -1, focusFirstScore: false)
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
            return AppColors.push
        }
    }

    private var statusColor: Color {
        if store.round.matchDelta > 0 {
            return AppColors.joshMatt
        }
        if store.round.matchDelta < 0 {
            return AppColors.jeffShane
        }
        return AppColors.push
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
