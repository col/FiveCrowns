import Testing
@testable import FiveCrowns

@Suite("Ranking")
struct RankingTests {

    private func player(_ name: String, total: Int) -> Player {
        let p = Player(name: name, order: 1)
        p.setScore(round: 1, points: total)
        return p
    }

    @Test("Lowest total ranks first")
    func lowestScoreWins() {
        let ranked = RankedPlayer.rankPlayers(players: [
            player("High", total: 50),
            player("Low", total: 10),
            player("Mid", total: 30),
        ])
        #expect(ranked.map(\.player.name) == ["Low", "Mid", "High"])
        #expect(ranked.map(\.rank) == [1, 2, 3])
    }

    @Test("Tied players share a rank and the next takes the following rank")
    func tiesUseDenseRanking() {
        let ranked = RankedPlayer.rankPlayers(players: [
            player("A", total: 10),
            player("B", total: 10),
            player("C", total: 20),
        ])
        #expect(ranked.map(\.rank) == [1, 1, 2])
    }

    @Test("All players tied all rank first")
    func allTied() {
        let ranked = RankedPlayer.rankPlayers(players: [
            player("A", total: 15),
            player("B", total: 15),
            player("C", total: 15),
        ])
        #expect(ranked.map(\.rank) == [1, 1, 1])
    }

    @Test("Empty roster ranks to nothing")
    func emptyRoster() {
        #expect(RankedPlayer.rankPlayers(players: []).isEmpty)
    }

    @Test("Single player ranks first")
    func singlePlayer() {
        let ranked = RankedPlayer.rankPlayers(players: [player("Solo", total: 42)])
        #expect(ranked.count == 1)
        #expect(ranked[0].rank == 1)
    }
}
