import SwiftUI

/// The player: unscramble the day's five words against the clock. Tap scrambled tiles to build the
/// answer; the hint points to the word. Solve all five to finish your run.
struct GameView: View {
    let words: [Word]
    var isPractice: Bool = false

    @EnvironmentObject var appModel: AppModel
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss

    @StateObject private var game: GameState
    @State private var elapsed = 0
    @State private var finished = false
    @State private var showResult = false
    @State private var shake = false

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    init(words: [Word], isPractice: Bool = false) {
        self.words = words
        self.isPractice = isPractice
        _game = StateObject(wrappedValue: GameState(words))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                QMBackground()
                ScrollView {
                    VStack(spacing: 22) {
                        statusBar
                        hintCard
                        answerRow.modifier(Shake(animatableData: shake ? 1 : 0))
                        poolRow
                        controls
                    }
                    .padding()
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle(isPractice ? "Practice" : "Today's Words")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Close") { dismiss() }.tint(Color.qmAccent) }
            }
            .onReceive(timer) { _ in if !finished { elapsed += 1 } }
            .sheet(isPresented: $showResult) {
                ResultView(seconds: elapsed, streak: appModel.currentStreak, isPractice: isPractice) {
                    showResult = false; dismiss()
                }
                .presentationDetents([.medium])
            }
        }
    }

    private var statusBar: some View {
        HStack {
            Label(timeString(elapsed), systemImage: "clock")
                .font(.subheadline.monospacedDigit()).foregroundStyle(.secondary)
            Spacer()
            Text("\(game.solvedCount)/\(words.count) solved")
                .font(.subheadline).foregroundStyle(.secondary)
        }
    }

    private var hintCard: some View {
        VStack(spacing: 8) {
            Text("WORD \(min(game.index + 1, words.count)) OF \(words.count)")
                .font(.caption.weight(.semibold)).foregroundStyle(.secondary).tracking(1.5)
            Text(game.hint)
                .font(.title3.weight(.medium))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .qmCard()
    }

    private var answerRow: some View {
        HStack(spacing: 8) {
            ForEach(0..<game.word.count, id: \.self) { i in
                if i < game.placed.count {
                    let id = game.placed[i]
                    tile(letter: letter(id), filled: true, solved: game.solvedHere) {
                        game.tapPlaced(id)
                    }
                } else {
                    emptySlot
                }
            }
        }
    }

    private var poolRow: some View {
        HStack(spacing: 8) {
            ForEach(game.available) { t in
                tile(letter: String(t.ch), filled: false, solved: false) {
                    Haptics.soft(); game.tapPool(t.id); afterTap()
                }
            }
            if game.available.isEmpty { Color.clear.frame(height: 56) }
        }
    }

    @ViewBuilder
    private var controls: some View {
        if !game.solvedHere {
            Button(role: .destructive) { Haptics.tap(); game.clear() } label: {
                Label("Clear", systemImage: "arrow.counterclockwise")
                    .frame(maxWidth: .infinity).padding(.vertical, 2)
            }
            .softButton()
        }
    }

    private func tile(letter: String, filled: Bool, solved: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(letter)
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundStyle(filled ? .white : Color.primary)
                .frame(width: 44, height: 56)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(filled ? (solved ? Color.qmCorrect : Color.qmAccent) : Color.qmCard)
                )
        }
        .buttonStyle(.plain)
    }

    private var emptySlot: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .strokeBorder(Color.qmHair, style: StrokeStyle(lineWidth: 1.5, dash: [4]))
            .frame(width: 44, height: 56)
    }

    private func letter(_ id: Int) -> String {
        String(game.pool.first { $0.id == id }?.ch ?? " ")
    }

    private func afterTap() {
        if game.isFull && game.wrong {
            Haptics.warning()
            withAnimation(.default) { shake.toggle() }
            return
        }
        if game.solvedHere {
            Haptics.success()
            if game.allSolved {
                finished = true
                appModel.record(seconds: Double(elapsed), solved: true, isPractice: isPractice)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { showResult = true }
            } else if let n = game.nextUnsolved() {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    withAnimation { game.load(n) }
                }
            }
        }
    }

    private func timeString(_ s: Int) -> String { String(format: "%d:%02d", s / 60, s % 60) }
}

/// A small horizontal shake for a completed-but-wrong word.
struct Shake: GeometryEffect {
    var animatableData: CGFloat
    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: 8 * sin(animatableData * .pi * 4), y: 0))
    }
}
