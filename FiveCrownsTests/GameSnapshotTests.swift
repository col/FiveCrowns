import Foundation
import Testing
@testable import FiveCrowns

@Suite("GameSnapshot")
struct GameSnapshotTests {

    @Test("Round-trips through JSON unchanged")
    func roundTrips() throws {
        let snapshot = GameSnapshot(round: 4, players: [
            PlayerSnapshot(id: UUID(), name: "Ada", scores: [1: 7, 2: 0]),
            PlayerSnapshot(id: UUID(), name: "Grace", scores: [1: 13]),
        ])
        let data = try JSONEncoder().encode(snapshot)
        let decoded = try JSONDecoder().decode(GameSnapshot.self, from: data)
        #expect(decoded == snapshot)
    }

    @Test("Encoded form contains no underscore-prefixed keys")
    func cleanKeys() throws {
        let snapshot = GameSnapshot(round: 1, players: [
            PlayerSnapshot(id: UUID(), name: "Ada", scores: [1: 7])
        ])
        let text = try #require(String(data: JSONEncoder().encode(snapshot), encoding: .utf8))
        #expect(!text.contains("_name"))
        #expect(!text.contains("_$observationRegistrar"))
        #expect(text.contains("\"name\""))
        #expect(text.contains("\"schemaVersion\""))
    }

    @Test("Decodes a genuine v1 save file")
    func decodesLegacyFixture() throws {
        let data = try LegacyFixtureTests.legacyData()
        let snapshot = try #require(GameSnapshot(legacyData: data))

        #expect(snapshot.schemaVersion == GameSnapshot.currentSchemaVersion)
        // v1 stored no round, so it is inferred: round 3 is the highest
        // scored, but Grace has no score for it, so it is still in progress.
        #expect(snapshot.round == 3)
        #expect(snapshot.players.count == 2)

        let ada = try #require(snapshot.players.first { $0.name == "Ada" })
        #expect(ada.scores[1] == 7)
        #expect(ada.scores[2] == 0)           // zero survives; it is a real score
        #expect(ada.scores[3] == 21)

        let grace = try #require(snapshot.players.first { $0.name == "Grace" })
        #expect(grace.scores[1] == 13)
        #expect(grace.scores[2] == 5)
        #expect(grace.scores[3] == nil)       // v1 null becomes absence
    }

    @Test("Rejects data that is neither format")
    func rejectsGarbage() {
        let garbage = Data("{\"nope\":true}".utf8)
        #expect(GameSnapshot(legacyData: garbage) == nil)
    }

    @Test("Round is clamped to the valid range on load")
    func clampsRound() throws {
        let json = Data("""
        {"schemaVersion":2,"round":99,"players":[]}
        """.utf8)
        let decoded = try JSONDecoder().decode(GameSnapshot.self, from: json)
        #expect(decoded.clampedRound == .eleven)

        let low = Data("""
        {"schemaVersion":2,"round":0,"players":[]}
        """.utf8)
        #expect(try JSONDecoder().decode(GameSnapshot.self, from: low).clampedRound == .one)
    }

    // MARK: - Format confusion

    @Test("A v2 file is not mistaken for a v1 file")
    func v2IsNotLegacy() throws {
        let snapshot = GameSnapshot(round: 4, players: [
            PlayerSnapshot(id: UUID(), name: "Ada", scores: [1: 7, 2: 0]),
            PlayerSnapshot(id: UUID(), name: "Grace", scores: [1: 13]),
        ])
        let data = try JSONEncoder().encode(snapshot)
        // The store tries v2 first and falls back to legacy. If a v2 file also
        // decoded as v1 the fallback could silently reset a live game.
        #expect(GameSnapshot(legacyData: data) == nil)
    }

    @Test("A v1 file is not mistaken for a v2 file")
    func legacyIsNotV2() throws {
        let data = try LegacyFixtureTests.legacyData()
        #expect(throws: (any Error).self) {
            try JSONDecoder().decode(GameSnapshot.self, from: data)
        }
    }

    // MARK: - Migration edge cases

    @Test("An empty v1 roster migrates to an empty snapshot, not a failure")
    func migratesEmptyRoster() throws {
        // The shipped app really writes `[]` for an empty roster; treating it
        // as unreadable would quarantine a perfectly valid file.
        let snapshot = try #require(GameSnapshot(legacyData: Data("[]".utf8)))
        #expect(snapshot.players.isEmpty)
        #expect(snapshot.round == Round.first.rawValue)
        #expect(snapshot.schemaVersion == GameSnapshot.currentSchemaVersion)
    }

    @Test("A player whose scores are all null survives with no scores")
    func migratesAllNullPlayer() throws {
        let json = Data("""
        [{"_id":"08AC9D68-B41E-409A-BB9D-4D0158B5168A","_name":"Ada","_order":1,
          "_scores":{"1":null,"2":null}}]
        """.utf8)
        let snapshot = try #require(GameSnapshot(legacyData: json))
        #expect(snapshot.players.count == 1)          // the player must not vanish
        let ada = try #require(snapshot.players.first)
        #expect(ada.name == "Ada")
        #expect(ada.scores.isEmpty)
        #expect(snapshot.round == Round.first.rawValue)
    }

    @Test("A truncated v1 file is rejected rather than partially read")
    func rejectsTruncatedLegacyFile() throws {
        let data = try LegacyFixtureTests.legacyData()
        let truncated = data.dropLast(20)
        #expect(truncated.count == data.count - 20)
        #expect(GameSnapshot(legacyData: Data(truncated)) == nil)
    }

    // MARK: - Schema version

    @Test("A newer schemaVersion is flagged and never written back out")
    func rejectsAndNeverEchoesFutureVersion() throws {
        let json = Data("""
        {"schemaVersion":99,"round":7,"players":[],"gameName":"Friday"}
        """.utf8)
        let decoded = try JSONDecoder().decode(GameSnapshot.self, from: json)
        #expect(decoded.schemaVersion == 99)
        #expect(decoded.isFromFutureVersion)

        // Re-encoding must stamp the current version. Echoing 99 back would
        // leave a file claiming to be v99 while holding only v2 fields.
        let reencoded = try JSONEncoder().encode(decoded)
        let roundTripped = try JSONDecoder().decode(GameSnapshot.self, from: reencoded)
        #expect(roundTripped.schemaVersion == GameSnapshot.currentSchemaVersion)
        #expect(!roundTripped.isFromFutureVersion)

        let text = try #require(String(data: reencoded, encoding: .utf8))
        #expect(text.contains("\"schemaVersion\":2"))
        #expect(!text.contains("99"))
    }

    @Test("The current and older versions are not flagged as future")
    func currentVersionIsReadable() throws {
        let current = GameSnapshot(round: 1, players: [])
        #expect(!current.isFromFutureVersion)
        #expect(!GameSnapshot(schemaVersion: 1, round: 1, players: []).isFromFutureVersion)
    }

    // MARK: - Round inference

    @Test("A completed round resumes at the next round")
    func infersRoundAfterCompleteRound() throws {
        let json = Data("""
        [{"_id":"08AC9D68-B41E-409A-BB9D-4D0158B5168A","_name":"Ada","_order":1,
          "_scores":{"1":7,"2":11}},
         {"_id":"104EC25F-AC3A-4BC8-90C9-6E6A2E0936BF","_name":"Grace","_order":2,
          "_scores":{"1":13,"2":0}}]
        """.utf8)
        let snapshot = try #require(GameSnapshot(legacyData: json))
        #expect(snapshot.round == 3)   // both scored round 2, so round 2 is done
    }

    @Test("An unevenly scored round resumes at the round still in progress")
    func infersRoundMidRound() throws {
        let json = Data("""
        [{"_id":"08AC9D68-B41E-409A-BB9D-4D0158B5168A","_name":"Ada","_order":1,
          "_scores":{"1":7,"2":11,"3":4,"4":9}},
         {"_id":"104EC25F-AC3A-4BC8-90C9-6E6A2E0936BF","_name":"Grace","_order":2,
          "_scores":{"1":13,"2":0,"3":6}}]
        """.utf8)
        let snapshot = try #require(GameSnapshot(legacyData: json))
        #expect(snapshot.round == 4)   // Grace still owes a round-4 score
    }

    @Test("A finished game does not resume past the last round")
    func infersRoundCappedAtLast() throws {
        let scores = (1...11).map { "\"\($0)\":\($0)" }.joined(separator: ",")
        let json = Data("""
        [{"_id":"08AC9D68-B41E-409A-BB9D-4D0158B5168A","_name":"Ada","_order":1,
          "_scores":{\(scores)}}]
        """.utf8)
        let snapshot = try #require(GameSnapshot(legacyData: json))
        #expect(snapshot.round == Round.last.rawValue)
    }
}
