import Testing
@testable import FiveCrowns

@Suite("Round")
struct RoundTests {

    @Test("There are exactly eleven rounds")
    func elevenRounds() {
        #expect(Round.allCases.count == 11)
        #expect(Round.first == .one)
        #expect(Round.last == .eleven)
    }

    @Test("Card count runs from three to thirteen")
    func cardCounts() {
        #expect(Round.one.cardCount == 3)
        #expect(Round.five.cardCount == 7)
        #expect(Round.eleven.cardCount == 13)
    }

    @Test("Every round's card count is its number plus two")
    func cardCountFormula() {
        for round in Round.allCases {
            #expect(round.cardCount == round.rawValue + 2)
        }
    }

    @Test("Navigation stops at the boundaries")
    func navigationBounds() {
        #expect(Round.one.previous == nil)
        #expect(Round.one.next == .two)
        #expect(Round.eleven.next == nil)
        #expect(Round.eleven.previous == .ten)
    }

    @Test("Out-of-range raw values do not produce a round")
    func invalidRawValues() {
        #expect(Round(rawValue: 0) == nil)
        #expect(Round(rawValue: 12) == nil)
    }

    @Test("Rounds order by number")
    func ordering() {
        #expect(Round.one < Round.two)
        #expect(Round.allCases.sorted() == Round.allCases)
    }
}
