import Foundation

/// The on-disk representation of a game.
///
/// Deliberately separate from the model types. Encoding `@Observable` classes
/// directly produced keys like `_name` and `_$observationRegistrar`, because
/// `Codable` synthesis ran over the macro's generated backing storage.
struct GameSnapshot: Codable, Sendable, Equatable {
    static let currentSchemaVersion = 2

    var schemaVersion: Int
    /// `Round.rawValue`. Stored as `Int` so an out-of-range file cannot fail
    /// to decode; use `clampedRound` to read it.
    var round: Int
    var players: [PlayerSnapshot]

    init(schemaVersion: Int = GameSnapshot.currentSchemaVersion,
         round: Int,
         players: [PlayerSnapshot]) {
        self.schemaVersion = schemaVersion
        self.round = round
        self.players = players
    }

    var clampedRound: Round {
        Round(rawValue: min(max(round, Round.first.rawValue), Round.last.rawValue)) ?? .one
    }
}

struct PlayerSnapshot: Codable, Sendable, Equatable {
    var id: UUID
    var name: String
    /// Keyed by `Round.rawValue`. Absence means no score entered.
    var scores: [Int: Int]
}

// MARK: - Legacy v1 migration

extension GameSnapshot {
    /// Decodes the pre-v2 format: a bare array of `@Observable` players whose
    /// keys carry the macro's underscore prefix. Returns `nil` if `data` is
    /// not that format.
    init?(legacyData data: Data) {
        guard let legacy = try? JSONDecoder().decode([LegacyPlayer].self, from: data) else {
            return nil
        }
        self.init(
            round: Round.first.rawValue,   // v1 never persisted the round
            players: legacy.map {
                PlayerSnapshot(id: $0.id, name: $0.name, scores: $0.scores)
            }
        )
    }
}

private struct LegacyPlayer: Decodable {
    let id: UUID
    let name: String
    let scores: [Int: Int]

    private enum CodingKeys: String, CodingKey {
        case id = "_id"
        case name = "_name"
        case scores = "_scores"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        // v1 stored [Int: Int?]; an explicit null meant "cleared", which v2
        // represents by absence. Zero is a real score and must survive.
        let raw = try container.decode([Int: Int?].self, forKey: .scores)
        scores = raw.compactMapValues { $0 }
    }
}
