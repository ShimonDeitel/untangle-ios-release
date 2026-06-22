import Foundation
import SwiftData

/// One word to unscramble, with a hint that points to it.
struct Word: Codable, Identifiable, Equatable {
    let id: Int
    let word: String
    let hint: String
    let difficulty: String
}

/// The bundled word bank. Each day picks a fixed set (date-seeded, same for everyone): two easy,
/// two medium, one hard. Pro unlocks the archive and unlimited practice.
enum Bank {
    static let all: [Word] = load()
    static var easy: [Word] { all.filter { $0.difficulty == "easy" } }
    static var medium: [Word] { all.filter { $0.difficulty == "medium" } }
    static var hard: [Word] { all.filter { $0.difficulty == "hard" } }

    private static func load() -> [Word] {
        guard let url = Bundle.main.url(forResource: "untangle_bank", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let words = try? JSONDecoder().decode([Word].self, from: data) else { return [] }
        return words
    }

    private static func epochDay(_ date: Date) -> Int {
        let cal = Calendar.current
        return Int((cal.startOfDay(for: date).timeIntervalSince1970 / 86_400).rounded(.down))
    }

    private static func pick(_ p: [Word], _ n: Int, _ salt: Int, _ day: Int) -> [Word] {
        guard !p.isEmpty else { return [] }
        let base = ((day &* 2_654_435_761 &+ salt) % p.count + p.count) % p.count
        return (0..<min(n, p.count)).map { p[(base + $0) % p.count] }
    }

    /// The day's five words, in increasing difficulty.
    static func dailySet(for date: Date = .now) -> [Word] {
        let d = epochDay(date)
        return pick(easy, 2, 0, d) + pick(medium, 2, 1, d) + pick(hard, 1, 2, d)
    }

    static func dailySet(daysAgo: Int, from date: Date = .now) -> [Word] {
        let day = Calendar.current.date(byAdding: .day, value: -daysAgo, to: date) ?? date
        return dailySet(for: day)
    }

    /// A fresh random set for Pro practice.
    static func practiceSet() -> [Word] {
        Array(easy.shuffled().prefix(2)) + Array(medium.shuffled().prefix(2)) + Array(hard.shuffled().prefix(1))
    }

    static func dateKey(for date: Date = .now) -> String {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 2026, c.month ?? 1, c.day ?? 1)
    }
}

/// A scrambled letter tile with a stable identity so SwiftUI can animate it between rows.
struct PoolTile: Identifiable, Equatable {
    let id: Int
    let ch: Character
}

/// Mutable state for one play session: the five words, the current scramble, and solve tracking.
final class GameState: ObservableObject {
    let words: [Word]
    @Published var index = 0
    @Published var pool: [PoolTile] = []
    @Published var placed: [Int] = []          // pool-tile ids, in answer order
    @Published var wrong = false
    @Published var solvedFlags: [Bool]

    init(_ words: [Word]) {
        self.words = words
        solvedFlags = Array(repeating: false, count: words.count)
        load(0)
    }

    var word: String { words.isEmpty ? "" : words[index].word }
    var hint: String { words.isEmpty ? "" : words[index].hint }

    func load(_ i: Int) {
        index = i
        let target = Array(word)
        var s = target
        if target.count > 1 {
            var t = 0
            repeat { s = target.shuffled(); t += 1 } while String(s) == word && t < 10
        }
        pool = s.enumerated().map { PoolTile(id: $0.offset, ch: $0.element) }
        placed = []
        wrong = false
    }

    private func ch(_ id: Int) -> Character { pool.first { $0.id == id }?.ch ?? " " }
    var answer: String { String(placed.map { ch($0) }) }
    var isFull: Bool { placed.count == word.count }
    var available: [PoolTile] { pool.filter { !placed.contains($0.id) } }
    var solvedHere: Bool { solvedFlags.indices.contains(index) && solvedFlags[index] }

    func tapPool(_ id: Int) {
        guard !solvedHere, !placed.contains(id) else { return }
        placed.append(id)
        if answer == word {
            solvedFlags[index] = true
            wrong = false
        } else {
            wrong = isFull
        }
    }

    func tapPlaced(_ id: Int) {
        guard !solvedHere else { return }
        placed.removeAll { $0 == id }
        wrong = false
    }

    func clear() {
        guard !solvedHere else { return }
        placed = []
        wrong = false
    }

    var solvedCount: Int { solvedFlags.filter { $0 }.count }
    var allSolved: Bool { !solvedFlags.isEmpty && solvedFlags.allSatisfy { $0 } }
    func nextUnsolved() -> Int? { (0..<words.count).first { !solvedFlags[$0] } }
}

/// One recorded daily run. Local-only; CloudKit-friendly defaults.
@Model
final class UntangleResult {
    var id: UUID = UUID()
    var dateKey: String = ""
    var seconds: Double = 0
    var solved: Bool = false
    var isPractice: Bool = false
    var date: Date = Date.now

    init(id: UUID = UUID(), dateKey: String = "", seconds: Double = 0,
         solved: Bool = false, isPractice: Bool = false, date: Date = .now) {
        self.id = id; self.dateKey = dateKey; self.seconds = seconds
        self.solved = solved; self.isPractice = isPractice; self.date = date
    }
}
