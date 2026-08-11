import Foundation
import Observation

/// The state and rules of one game of Five Crowns.
@MainActor
@Observable
final class Game {
    private(set) var players: [Player] = []
    private(set) var round: Round = .first
    /// Set when a background save fails, so the UI can say so without crashing.
    private(set) var saveFailed = false

    private var announcedRounds: Set<Round> = []
    private let store: GameStore

    init(store: GameStore) {
        self.store = store
    }

    // MARK: Roster

    func addPlayer(named name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        players.append(Player(name: trimmed))
        autosave()
    }

    func removePlayer(id: Player.ID) {
        players.removeAll { $0.id == id }
        autosave()
    }

    func rename(id: Player.ID, to name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let player = players.first(where: { $0.id == id }) else { return }
        player.name = trimmed
        autosave()
    }

    // MARK: Scoring

    func setScore(_ points: Int?, for id: Player.ID) {
        players.first { $0.id == id }?.setScore(points, for: round)
        autosave()
    }

    func score(for id: Player.ID) -> Int? {
        players.first { $0.id == id }?.score(for: round)
    }

    // MARK: Rules

    var isRoundComplete: Bool {
        !players.isEmpty && players.allSatisfy { $0.score(for: round) != nil }
    }

    var isGameOver: Bool { round == .last && isRoundComplete }

    /// True the first time a round becomes complete, false after it has been
    /// acknowledged — so correcting a score does not re-announce.
    var needsRoundCompleteAnnouncement: Bool {
        isRoundComplete && !announcedRounds.contains(round)
    }

    func acknowledgeRound() {
        announcedRounds.insert(round)
    }

    var canAdvance: Bool { round.next != nil }
    var canRetreat: Bool { round.previous != nil }

    func advance() {
        guard let next = round.next else { return }
        round = next
        autosave()
    }

    func retreat() {
        guard let previous = round.previous else { return }
        round = previous
        autosave()
    }

    func startNewGame() {
        players.forEach { $0.resetScores() }
        round = .first
        announcedRounds = []
        autosave()
    }

    var leaderboard: [RankedPlayer] { Ranking.rank(players) }
    var winner: Player? { leaderboard.first?.player }

    // MARK: Persistence

    func snapshot() -> GameSnapshot {
        GameSnapshot(
            round: round.rawValue,
            players: players.map {
                PlayerSnapshot(
                    id: $0.id,
                    name: $0.name,
                    scores: Dictionary(uniqueKeysWithValues:
                        $0.scores.map { ($0.key.rawValue, $0.value) })
                )
            }
        )
    }

    func apply(_ snapshot: GameSnapshot) {
        round = snapshot.clampedRound
        players = snapshot.players.map { snap in
            Player(
                id: snap.id,
                name: snap.name,
                scores: Dictionary(uniqueKeysWithValues:
                    snap.scores.compactMap { key, value in
                        Round(rawValue: key).map { ($0, value) }
                    })
            )
        }
        announcedRounds = []
    }

    func loadFromDisk() async {
        if let snapshot = await store.load() {
            apply(snapshot)
        }
    }

    /// Flushes any pending debounced write. Call on scene-phase change.
    func flush() async {
        await store.flush()
        saveFailed = await store.lastWriteFailed
    }

    private func autosave() {
        let snapshot = snapshot()
        Task { [store] in await store.scheduleSave(snapshot) }
    }
}
