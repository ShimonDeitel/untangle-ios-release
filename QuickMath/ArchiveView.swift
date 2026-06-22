import SwiftUI

/// Pro: replay any previous day's word set.
struct ArchiveView: View {
    @EnvironmentObject var appModel: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var play: PlaySpec?

    private let days = 1...60

    var body: some View {
        NavigationStack {
            ZStack {
                QMBackground()
                ScrollView {
                    VStack(spacing: 10) {
                        ForEach(Array(days), id: \.self) { daysAgo in
                            let words = Bank.dailySet(daysAgo: daysAgo)
                            if !words.isEmpty { row(daysAgo: daysAgo, words: words) }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Past Days")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() }.tint(Color.qmAccent) }
            }
            .fullScreenCover(item: $play) { spec in
                GameView(words: spec.words, isPractice: spec.isPractice)
            }
        }
    }

    private func row(daysAgo: Int, words: [Word]) -> some View {
        let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: .now) ?? .now
        let key = Bank.dateKey(for: date)
        let solved = appModel.solvedDaily(forKey: key)
        return Button {
            Haptics.tap(); play = PlaySpec(words: words, isPractice: false)
        } label: {
            HStack(spacing: 14) {
                Image(systemName: solved ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(solved ? Color.qmCorrect : Color.secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(dateLabel(date)).font(.headline).foregroundStyle(.primary)
                    Text("\(words.count) words").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold)).foregroundStyle(.secondary)
            }
            .qmCard()
        }
        .buttonStyle(.plain)
    }

    private func dateLabel(_ d: Date) -> String {
        let f = DateFormatter(); f.dateStyle = .medium; f.timeStyle = .none
        return f.string(from: d)
    }
}
