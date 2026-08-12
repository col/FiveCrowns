import Foundation

struct RankedPlayer: Identifiable {
    let player: Player
    let rank: Int
    var id: Player.ID { player.id }
}

enum Ranking {
    /// Dense ranking: tied players share a rank and the next distinct score
    /// takes the immediately following rank (1, 1, 2 — not 1, 1, 3).
    static func rank(_ players: [Player]) -> [RankedPlayer] {
        let sorted = players.sorted { $0.totalPoints < $1.totalPoints }
        let rankByScore = Dictionary(
            uniqueKeysWithValues: Set(sorted.map(\.totalPoints)).sorted()
                .enumerated().map { ($1, $0 + 1) }
        )
        return sorted.map { RankedPlayer(player: $0, rank: rankByScore[$0.totalPoints] ?? 1) }
    }
}
