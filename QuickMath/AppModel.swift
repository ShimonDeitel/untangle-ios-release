import Foundation
import SwiftData
import SwiftUI

/// App state: owns the local SwiftData store, exposes today's word set, and derives the streak and
/// stats from recorded runs (never stored as truth).
@MainActor
final class AppModel: ObservableObject {
    let container: ModelContainer
    weak var store: Store?

    @Published private(set) var currentStreak = 0
    @Published private(set) var longestStreak = 0
    @Published private(set) var totalSolved = 0
    @Published private(set) var bestSeconds = 0.0
    @Published private(set) var solvedToday = false
    @Published private(set) var today: [Word] = []

    init(container: ModelContainer) {
        self.container = container
        today = Bank.dailySet()
        refresh()
    }

    static func makeContainer() -> ModelContainer {
        let schema = Schema([UntangleResult.self])
        let local = ModelConfiguration(schema: schema)
        if let c = try? ModelContainer(for: schema, configurations: local) { return c }
        let mem = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try! ModelContainer(for: schema, configurations: mem)
    }

    func refreshTodayIfNeeded() {
        today = Bank.dailySet()
        refresh()
    }

    func record(seconds: Double, solved: Bool, isPractice: Bool) {
        let ctx = container.mainContext
        ctx.insert(UntangleResult(dateKey: Bank.dateKey(), seconds: seconds, solved: solved, isPractice: isPractice))
        try? ctx.save()
        refresh()
    }

    func allResults() -> [UntangleResult] {
        let d = FetchDescriptor<UntangleResult>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        return (try? container.mainContext.fetch(d)) ?? []
    }

    func solvedDaily(forKey key: String) -> Bool {
        allResults().contains { $0.dateKey == key && $0.solved && !$0.isPractice }
    }

    func refresh() {
        let daily = allResults().filter { $0.solved && !$0.isPractice }
        totalSolved = Set(daily.map(\.dateKey)).count
        bestSeconds = daily.map(\.seconds).filter { $0 > 0 }.min() ?? 0
        solvedToday = daily.contains { $0.dateKey == Bank.dateKey() }
        let keys = Set(daily.map(\.dateKey))
        let s = Self.streaks(from: keys)
        currentStreak = s.current
        longestStreak = s.longest
    }

    static func streaks(from keys: Set<String>) -> (current: Int, longest: Int) {
        let fmt = DateFormatter(); fmt.dateFormat = "yyyy-MM-dd"; fmt.timeZone = .current
        let cal = Calendar.current
        let days = Set(keys.compactMap { fmt.date(from: $0) }.map { cal.startOfDay(for: $0) })
        guard !days.isEmpty else { return (0, 0) }

        let sorted = days.sorted()
        var longest = 1, run = 1
        for i in 1..<sorted.count {
            let gap = cal.dateComponents([.day], from: sorted[i - 1], to: sorted[i]).day ?? 0
            if gap == 1 { run += 1 } else { run = 1 }
            longest = max(longest, run)
        }

        var current = 0
        var cursor = cal.startOfDay(for: .now)
        if !days.contains(cursor) { cursor = cal.date(byAdding: .day, value: -1, to: cursor) ?? cursor }
        while days.contains(cursor) {
            current += 1
            cursor = cal.date(byAdding: .day, value: -1, to: cursor) ?? cursor
        }
        return (current, max(longest, current))
    }

    func deleteAllData() {
        let ctx = container.mainContext
        for r in allResults() { ctx.delete(r) }
        try? ctx.save()
        refresh()
    }
}
