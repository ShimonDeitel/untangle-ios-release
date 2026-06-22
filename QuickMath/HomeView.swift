import SwiftUI

/// The hub: today's five-word challenge, your best time and streak, and Pro entry points
/// (the archive of past days and unlimited practice).
struct HomeView: View {
    @EnvironmentObject var appModel: AppModel
    @EnvironmentObject var store: Store

    var forceScreen: String? = nil

    @State private var active: PlaySpec?
    @State private var showSettings = false
    @State private var showPaywall = false
    @State private var showArchive = false

    var body: some View {
        NavigationStack {
            ZStack {
                QMBackground()
                ScrollView {
                    VStack(spacing: 22) {
                        header
                        todayCard
                        statsRow
                        proRow
                    }
                    .padding()
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle("Untangle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { Haptics.tap(); showSettings = true } label: {
                        Image(systemName: "gearshape").foregroundStyle(Color.qmAccent)
                    }
                    .accessibilityLabel("Settings")
                }
            }
            .tint(Color.qmAccent)
            .fullScreenCover(item: $active) { spec in
                GameView(words: spec.words, isPractice: spec.isPractice)
            }
            .sheet(isPresented: $showSettings) { SettingsView() }
            .sheet(isPresented: $showPaywall) { PaywallView() }
            .sheet(isPresented: $showArchive) { ArchiveView() }
            .onAppear { appModel.refreshTodayIfNeeded() }
        }
    }

    private var header: some View {
        VStack(spacing: 6) {
            Text(dateHeadline).font(.subheadline).foregroundStyle(.secondary)
            HStack(spacing: 6) {
                Image(systemName: "flame.fill").foregroundStyle(Color.qmAccent)
                Text("\(appModel.currentStreak) day streak").font(.headline)
            }
        }
        .padding(.top, 8)
    }

    @ViewBuilder
    private var todayCard: some View {
        VStack(spacing: 16) {
            Text("TODAY'S WORDS")
                .font(.caption.weight(.semibold)).foregroundStyle(.secondary).tracking(1.5)
            if !appModel.today.isEmpty {
                Text("\(appModel.today.count) words to unscramble")
                    .font(.headline)
                Text("Read the hint, rearrange the letters, beat the clock.")
                    .font(.footnote).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                if appModel.solvedToday {
                    Label("Solved today", systemImage: "checkmark.seal.fill")
                        .font(.subheadline).foregroundStyle(Color.qmCorrect)
                    Button { play(appModel.today, practice: false) } label: {
                        Text("Play Again").frame(maxWidth: .infinity).padding(.vertical, 4)
                    }
                    .softButton()
                } else {
                    Button { play(appModel.today, practice: false) } label: {
                        Text("Play Today's Words").frame(maxWidth: .infinity).padding(.vertical, 4)
                    }
                    .prominentButton()
                }
            } else {
                Text("Words unavailable.").font(.subheadline).foregroundStyle(.secondary)
            }
        }
        .qmCard()
    }

    private var statsRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Lifetime").font(.headline)
            HStack(spacing: 12) {
                MetricTile(value: appModel.bestSeconds > 0 ? timeString(appModel.bestSeconds) : "—", label: "Best time")
                MetricTile(value: "\(appModel.totalSolved)", label: "Solved")
                MetricTile(value: "\(appModel.longestStreak)", label: "Best streak")
            }
        }
    }

    @ViewBuilder
    private var proRow: some View {
        VStack(spacing: 12) {
            Button {
                Haptics.tap()
                if store.isPro { play(Bank.practiceSet(), practice: true) } else { showPaywall = true }
            } label: {
                proTile(icon: "infinity", title: "Practice",
                        subtitle: store.isPro ? "Unlimited fresh rounds" : "Pro", locked: !store.isPro)
            }
            .buttonStyle(.plain)

            Button {
                Haptics.tap()
                if store.isPro { showArchive = true } else { showPaywall = true }
            } label: {
                proTile(icon: "calendar", title: "Past days",
                        subtitle: store.isPro ? "Replay any previous day" : "Pro", locked: !store.isPro)
            }
            .buttonStyle(.plain)
        }
    }

    private func proTile(icon: String, title: String, subtitle: String, locked: Bool) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .semibold)).foregroundStyle(Color.qmAccent).frame(width: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline).foregroundStyle(.primary)
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: locked ? "lock.fill" : "chevron.right")
                .font(.system(size: 13, weight: .semibold)).foregroundStyle(.secondary)
        }
        .qmCard()
    }

    private func play(_ words: [Word], practice: Bool) {
        guard !words.isEmpty else { return }
        Haptics.tap()
        active = PlaySpec(words: words, isPractice: practice)
    }

    private var dateHeadline: String {
        let f = DateFormatter(); f.dateStyle = .full; f.timeStyle = .none
        return f.string(from: .now)
    }

    private func timeString(_ s: Double) -> String {
        let t = Int(s.rounded()); return String(format: "%d:%02d", t / 60, t % 60)
    }
}

/// Identifies a run being played in the full-screen cover.
struct PlaySpec: Identifiable {
    let id = UUID()
    let words: [Word]
    let isPractice: Bool
}
