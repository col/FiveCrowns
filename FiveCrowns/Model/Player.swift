import Foundation
import Observation

/// One player's identity and per-round scores for a single game.
///
/// Deliberately not `Codable`: persistence goes through `PlayerSnapshot` so
/// the save format does not track the `@Observable` macro's backing storage.
@Observable
final class Player: Identifiable {
    let id: UUID
    var name: String
    private(set) var scores: [Round: Int]

    init(id: UUID = UUID(), name: String, scores: [Round: Int] = [:]) {
        self.id = id
        self.name = name
        self.scores = scores
    }

    /// Derived rather than stored, so it can never drift out of sync.
    var totalPoints: Int { scores.values.reduce(0, +) }

    func score(for round: Round) -> Int? { scores[round] }

    /// Passing `nil` clears the entry, which is how "no score yet" is represented.
    func setScore(_ points: Int?, for round: Round) {
        if let points {
            scores[round] = points
        } else {
            scores.removeValue(forKey: round)
        }
    }

    func resetScores() { scores = [:] }
}
