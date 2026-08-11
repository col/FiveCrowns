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
        #expect(snapshot.round == 1)          // v1 stored no round
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
}
