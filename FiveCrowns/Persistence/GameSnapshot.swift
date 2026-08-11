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

    /// A file written by a newer build than this one. Such a file must not be
    /// loaded (its fields would be silently dropped) and must not be
    /// overwritten (the newer build's data is still recoverable).
    var isFromFutureVersion: Bool { schemaVersion > Self.currentSchemaVersion }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion, round, players
    }

    /// Always stamps `currentSchemaVersion`, never the value that was read.
    /// Echoing a foreign version back out would leave a file claiming to hold
    /// data this build has already dropped.
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(Self.currentSchemaVersion, forKey: .schemaVersion)
        try container.encode(round, forKey: .round)
        try container.encode(players, forKey: .players)
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
        let players = legacy.map {
            PlayerSnapshot(id: $0.id, name: $0.name, scores: $0.scores)
        }
        // v1 never persisted the round, but the scores make it inferable.
        self.init(round: Self.inferredRound(from: players), players: players)
    }

    /// Where a migrated game should resume, deduced from which rounds have
    /// been scored.
    ///
    /// The highest scored round is finished only if *every* player has a score
    /// for it; then play resumes at the round after. If anyone still owes a
    /// score for it, that round is still in progress and is the resume point.
    static func inferredRound(from players: [PlayerSnapshot]) -> Int {
        guard let highest = players.compactMap({ $0.scores.keys.max() }).max() else {
            return Round.first.rawValue   // nobody has scored anything
        }
        let roundIsComplete = players.allSatisfy { $0.scores[highest] != nil }
        return roundIsComplete ? min(highest + 1, Round.last.rawValue) : highest
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
