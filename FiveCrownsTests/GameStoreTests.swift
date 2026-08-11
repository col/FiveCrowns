import Foundation
import Testing
@testable import FiveCrowns

@Suite("GameStore")
struct GameStoreTests {

    private func tempURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("gamestore-\(UUID().uuidString)")
            .appendingPathComponent("game.data")
    }

    @Test("Loading a location with no file returns nil")
    func loadsNothingWhenAbsent() async {
        let store = GameStore(fileURL: tempURL())
        #expect(await store.load() == nil)
    }

    @Test("Saves and loads a snapshot")
    func savesAndLoads() async throws {
        let url = tempURL()
        let store = GameStore(fileURL: url)
        let snapshot = GameSnapshot(round: 5, players: [
            PlayerSnapshot(id: UUID(), name: "Ada", scores: [1: 7])
        ])
        try await store.save(snapshot)
        #expect(await store.load() == snapshot)
    }

    @Test("Reads a genuine v1 file and rewrites it as v2")
    func migratesLegacyFile() async throws {
        let url = tempURL()
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try LegacyFixtureTests.legacyData().write(to: url)

        let store = GameStore(fileURL: url)
        let loaded = try #require(await store.load())
        #expect(loaded.players.count == 2)
        #expect(loaded.schemaVersion == GameSnapshot.currentSchemaVersion)

        // Loading migrates in memory; saving persists the new format.
        try await store.save(loaded)
        let text = try #require(String(data: Data(contentsOf: url), encoding: .utf8))
        #expect(!text.contains("_name"))
    }

    @Test("A corrupt file is quarantined and does not prevent loading")
    func quarantinesCorruptFile() async throws {
        let url = tempURL()
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("this is not json".utf8).write(to: url)

        let store = GameStore(fileURL: url)
        #expect(await store.load() == nil)

        let quarantined = try FileManager.default.contentsOfDirectory(
            atPath: url.deletingLastPathComponent().path)
        #expect(quarantined.contains { $0.hasPrefix("game.data.corrupt") })
    }

    @Test("A file from a newer build is neither loaded nor overwritten")
    func refusesFutureVersion() async throws {
        let url = tempURL()
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let future = Data(#"{"schemaVersion":99,"round":7,"players":[],"dealerIndex":2}"#.utf8)
        try future.write(to: url)

        let store = GameStore(fileURL: url)
        #expect(await store.load() == nil)

        // A save attempt after seeing a future file must be a no-op.
        try await store.save(GameSnapshot(round: 1, players: []))
        #expect(try Data(contentsOf: url) == future)

        // It must not be quarantined either - it is valid, just newer.
        let siblings = try FileManager.default.contentsOfDirectory(
            atPath: url.deletingLastPathComponent().path)
        #expect(!siblings.contains { $0.contains("corrupt") })
    }

    @Test("Debounced saves coalesce into a single write")
    func debouncesSaves() async throws {
        let url = tempURL()
        let store = GameStore(fileURL: url)
        for round in 1...5 {
            await store.scheduleSave(GameSnapshot(round: round, players: []))
        }
        await store.flush()
        let loaded = try #require(await store.load())
        #expect(loaded.round == 5)
    }

    @Test("lastWriteFailed reflects the outcome of the most recent write")
    func flagsGenuineWriteFailure() async throws {
        // A regular file where the parent directory needs to be, so
        // createDirectory fails rather than succeeding.
        let blocker = FileManager.default.temporaryDirectory
            .appendingPathComponent("gamestore-blocker-\(UUID().uuidString)")
        try Data("not a directory".utf8).write(to: blocker)
        let url = blocker.appendingPathComponent("nested").appendingPathComponent("game.data")

        let store = GameStore(fileURL: url)
        #expect(await store.lastWriteFailed == false)

        await store.scheduleSave(GameSnapshot(round: 1, players: []))
        await store.flush()
        #expect(await store.lastWriteFailed == true)

        // Clear the obstruction and write again: a genuine success should
        // flip the flag back, proving it tracks the *most recent* write
        // rather than latching on the first failure.
        try FileManager.default.removeItem(at: blocker)
        await store.scheduleSave(GameSnapshot(round: 2, players: []))
        await store.flush()
        #expect(await store.lastWriteFailed == false)
        #expect(await store.load()?.round == 2)
    }
}
