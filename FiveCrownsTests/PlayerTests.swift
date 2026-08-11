import Testing
@testable import FiveCrowns

@Suite("Player scoring")
struct PlayerTests {

    @Test("A new player has no scores and a zero total")
    func newPlayerIsEmpty() {
        let player = Player(name: "Ada")
        #expect(player.totalPoints == 0)
        #expect(player.score(for: .one) == nil)
    }

    @Test("Setting a score updates the total")
    func settingScoreUpdatesTotal() {
        let player = Player(name: "Ada")
        player.setScore(7, for: .one)
        #expect(player.score(for: .one) == 7)
        #expect(player.totalPoints == 7)
    }

    @Test("Totals accumulate across rounds")
    func totalsAccumulate() {
        let player = Player(name: "Ada")
        player.setScore(7, for: .one)
        player.setScore(13, for: .two)
        player.setScore(0, for: .three)
        #expect(player.totalPoints == 20)
    }

    @Test("Going out scores zero, which is distinct from no score")
    func zeroIsNotAbsent() {
        let player = Player(name: "Ada")
        player.setScore(0, for: .one)
        #expect(player.score(for: .one) == 0)
        #expect(player.score(for: .two) == nil)
    }

    @Test("Setting nil clears the entry and the total follows")
    func nilClears() {
        let player = Player(name: "Ada")
        player.setScore(7, for: .one)
        player.setScore(nil, for: .one)
        #expect(player.score(for: .one) == nil)
        #expect(player.totalPoints == 0)
    }

    @Test("Reset clears every score")
    func resetClears() {
        let player = Player(name: "Ada")
        player.setScore(7, for: .one)
        player.resetScores()
        #expect(player.totalPoints == 0)
        #expect(player.score(for: .one) == nil)
    }
}
