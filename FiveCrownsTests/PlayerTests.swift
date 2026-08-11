import Testing
@testable import FiveCrowns

@Suite("Player scoring")
struct PlayerTests {

    @Test("A new player has no scores and a zero total")
    func newPlayerIsEmpty() {
        let player = Player(name: "Ada", order: 1)
        #expect(player.totalPoints == 0)
        #expect(player.pointsFor(round: 1) == nil)
    }

    @Test("Setting a score updates the total")
    func settingScoreUpdatesTotal() {
        let player = Player(name: "Ada", order: 1)
        player.setScore(round: 1, points: 7)
        #expect(player.pointsFor(round: 1) == 7)
        #expect(player.totalPoints == 7)
    }

    @Test("Totals accumulate across rounds")
    func totalsAccumulate() {
        let player = Player(name: "Ada", order: 1)
        player.setScore(round: 1, points: 7)
        player.setScore(round: 2, points: 13)
        player.setScore(round: 3, points: 0)
        #expect(player.totalPoints == 20)
    }

    @Test("Going out scores zero, which is distinct from no score")
    func zeroIsNotAbsent() {
        let player = Player(name: "Ada", order: 1)
        player.setScore(round: 1, points: 0)
        #expect(player.pointsFor(round: 1) == 0)
        #expect(player.pointsFor(round: 2) == nil)
    }

    @Test("Reset clears every score")
    func resetClears() {
        let player = Player(name: "Ada", order: 1)
        player.setScore(round: 1, points: 7)
        player.reset()
        #expect(player.totalPoints == 0)
        #expect(player.pointsFor(round: 1) == nil)
    }
}
