import Foundation
import Testing
@testable import FiveCrowns

@MainActor
@Suite("Game rules")
struct GameTests {

    private func makeGame() -> Game {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("gametests-\(UUID().uuidString)")
            .appendingPathComponent("game.data")
        return Game(store: GameStore(fileURL: url))
    }

    @Test("A new game starts empty on round one")
    func startsAtRoundOne() {
        let game = makeGame()
        #expect(game.round == .one)
        #expect(game.players.isEmpty)
    }

    @Test("Player names are trimmed and blanks rejected")
    func rejectsBlankNames() {
        let game = makeGame()
        game.addPlayer(named: "  Ada  ")
        game.addPlayer(named: "   ")
        game.addPlayer(named: "")
        #expect(game.players.count == 1)
        #expect(game.players[0].name == "Ada")
    }

    @Test("Removing matches on identity, not name")
    func removesById() {
        let game = makeGame()
        game.addPlayer(named: "Sam")
        game.addPlayer(named: "Sam")
        game.removePlayer(id: game.players[0].id)
        #expect(game.players.count == 1)
    }

    @Test("Round navigation stops at both ends")
    func navigationBounds() {
        let game = makeGame()
        #expect(!game.canRetreat)
        game.advance()
        #expect(game.round == .two)
        #expect(game.canRetreat)
        game.retreat()
        #expect(game.round == .one)

        for _ in 1...20 { game.advance() }
        #expect(game.round == .eleven)
        #expect(!game.canAdvance)
    }

    @Test("A round is complete only when every player has scored")
    func roundCompletion() {
        let game = makeGame()
        game.addPlayer(named: "Ada")
        game.addPlayer(named: "Grace")
        #expect(!game.isRoundComplete)

        game.setScore(7, for: game.players[0].id)
        #expect(!game.isRoundComplete)

        game.setScore(0, for: game.players[1].id)
        #expect(game.isRoundComplete)
    }

    @Test("An empty roster is never a complete round")
    func emptyRosterIsNotComplete() {
        #expect(!makeGame().isRoundComplete)
    }

    @Test("Game is over only when round eleven is complete")
    func gameOver() {
        let game = makeGame()
        game.addPlayer(named: "Ada")
        for _ in 1...10 { game.advance() }
        #expect(game.round == .eleven)
        #expect(!game.isGameOver)
        game.setScore(5, for: game.players[0].id)
        #expect(game.isGameOver)
    }

    @Test("A round is only announced once, even after edits")
    func acknowledgementIsOncePerRound() {
        let game = makeGame()
        game.addPlayer(named: "Ada")
        game.setScore(7, for: game.players[0].id)

        #expect(game.needsRoundCompleteAnnouncement)
        game.acknowledgeRound()
        #expect(!game.needsRoundCompleteAnnouncement)

        // Correcting a typo must not re-announce.
        game.setScore(9, for: game.players[0].id)
        #expect(!game.needsRoundCompleteAnnouncement)
    }

    @Test("Starting a new game clears scores and returns to round one")
    func startNewGame() {
        let game = makeGame()
        game.addPlayer(named: "Ada")
        game.setScore(7, for: game.players[0].id)
        game.advance()

        game.startNewGame()
        #expect(game.round == .one)
        #expect(game.players.count == 1)          // roster is kept
        #expect(game.players[0].totalPoints == 0)
    }

    @Test("Applying a snapshot restores round and scores")
    func appliesSnapshot() {
        let game = makeGame()
        let id = UUID()
        game.apply(GameSnapshot(round: 6, players: [
            PlayerSnapshot(id: id, name: "Ada", scores: [1: 7, 2: 0])
        ]))
        #expect(game.round == .six)
        #expect(game.players.count == 1)
        #expect(game.players[0].id == id)
        #expect(game.players[0].totalPoints == 7)
    }

    @Test("Snapshotting captures round and scores")
    func producesSnapshot() {
        let game = makeGame()
        game.addPlayer(named: "Ada")
        game.setScore(7, for: game.players[0].id)
        game.advance()

        let snapshot = game.snapshot()
        #expect(snapshot.round == 2)
        #expect(snapshot.players.count == 1)
        #expect(snapshot.players[0].scores[1] == 7)
    }
}
