import Foundation
import Testing
@testable import FiveCrowns

@Suite("Legacy fixture")
struct LegacyFixtureTests {

    /// The v1 save format, captured from the pre-refactor build. Guards the
    /// migration in Task 11 against a hand-authored approximation.
    static func legacyData() throws -> Data {
        let url = try #require(
            Bundle(for: BundleToken.self).url(forResource: "legacy-v1-game", withExtension: "json"),
            "legacy-v1-game.json is not in the test bundle"
        )
        return try Data(contentsOf: url)
    }

    @Test("Fixture is present and has the v1 shape")
    func fixtureHasLegacyShape() throws {
        let text = try #require(String(data: Self.legacyData(), encoding: .utf8))
        #expect(text.contains("_name"))
        #expect(text.contains("_scores"))
        #expect(text.contains("_$observationRegistrar"))
        #expect(text.contains("Ada"))
        #expect(text.contains("Grace"))
    }
}

/// Anchors `Bundle(for:)` to the test bundle.
final class BundleToken {}
