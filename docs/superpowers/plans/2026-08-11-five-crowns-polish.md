# Five Crowns Polish Pass Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Take FiveCrowns from a working family app to App Store readiness by removing crash and data-loss paths, restructuring into layers, fixing dark mode, supporting iPad and landscape, and establishing real test coverage.

**Architecture:** SwiftUI app split into `App/`, `Model/`, `Persistence/`, `Views/`, `Support/`. Game rules move out of `ScorecardView` into an `@MainActor @Observable Game`. Persistence goes through a versioned `GameSnapshot` DTO written by an `actor GameStore`, decoupling the save format from the `@Observable` macro's generated storage.

**Tech Stack:** Swift 6, SwiftUI, Observation, Swift Testing, Xcode 26.4.1, iOS 17.0+

**Spec:** `docs/superpowers/specs/2026-08-11-five-crowns-polish-design.md`

---

## Conventions for every task

**Build:**
```bash
xcodebuild -project FiveCrowns.xcodeproj -scheme FiveCrowns \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -quiet build
```

**Unit tests only (fast — use this in the TDD loop):**
```bash
xcodebuild test -project FiveCrowns.xcodeproj -scheme FiveCrowns \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:FiveCrownsTests -quiet 2>&1 | tail -30
```

**Full test suite (slow, ~2 min — use before each commit):**
```bash
xcodebuild test -project FiveCrowns.xcodeproj -scheme FiveCrowns \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -quiet 2>&1 | tail -30
```

**Warning count (must be 0 by the end):**
```bash
xcodebuild -project FiveCrowns.xcodeproj -scheme FiveCrowns \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' clean build 2>&1 \
  | grep -c "warning:"
```

**Rules:**
- Never use `fatalError` or `puts`. Use `os.Logger`.
- Every task ends with a commit. Never bundle two tasks into one commit.
- If a step's expected output does not match, stop and report — do not improvise around it.

---

## File structure

| Path | Responsibility |
|---|---|
| `FiveCrowns/App/FiveCrownsApp.swift` | `@main`, dependency wiring, root chrome |
| `FiveCrowns/Model/Game.swift` | Players, current round, game rules, autosave trigger |
| `FiveCrowns/Model/Player.swift` | Identity, name, per-round scores |
| `FiveCrowns/Model/Round.swift` | `enum Round: Int` 1...11, `cardCount`, navigation |
| `FiveCrowns/Model/Ranking.swift` | `RankedPlayer` struct + pure dense-ranking function |
| `FiveCrowns/Persistence/GameSnapshot.swift` | Versioned Codable DTO + legacy v1 decoding |
| `FiveCrowns/Persistence/GameStore.swift` | `actor` — atomic load/save, corruption quarantine, debounce |
| `FiveCrowns/Views/ScorecardView.swift` | Layout and wiring only |
| `FiveCrowns/Views/ScorecardRow.swift` | One player row |
| `FiveCrowns/Views/LeaderboardView.swift` | Ranked standings |
| `FiveCrowns/Views/Components/ScorecardHeaders.swift` | Column headers |
| `FiveCrowns/Views/Components/RoundHeader.swift` | Logo + "N Card Round" title |
| `FiveCrowns/Views/Components/ScoreCell.swift` | Tappable score cell |
| `FiveCrowns/Support/Theme.swift` | Semantic colours over generated asset symbols |
| `FiveCrownsTests/*.swift` | Swift Testing suites |

**Deleted:** `AddPlayerView.swift`, `UpdatePlayerView.swift`, `UpdateScoreView.swift`, `Styles.swift`, `Models/RankedPlayer.swift` (replaced by `Model/Ranking.swift`).

### Deviations from the spec

Two, both deliberate:

1. **`Player.scores` is `[Round: Int]`, not `[Int: Int]`.** The spec's intent was dropping the `[Int: Int?]` double optional; keying on the enum goes further and makes an invalid round number unrepresentable. `PlayerSnapshot.scores` stays `[Int: Int]` as specified, because the persisted format should not depend on the enum's case names.
2. **A project-structure phase precedes Phase 1.** The spec assumed files could be added freely; the project turned out to use explicit `pbxproj` references, so Task 1 migrates to synchronized groups first. This changes no behaviour and no build settings.

---

# Phase 0 — Project structure

These two tasks change no behaviour. They exist so that later tasks can add and move files without hand-editing `project.pbxproj`.

## Task 1: Migrate project to file-system-synchronized groups

The project is `objectVersion = 56` with explicit `PBXFileReference` / `PBXBuildFile` entries for every source file. Adding the ~12 new files this plan requires would mean ~48 hand-written pbxproj edits with unique 24-character hex IDs. Migrating to `PBXFileSystemSynchronizedRootGroup` (Xcode 16+) makes Xcode pick up whatever is on disk instead.

**Files:**
- Modify: `FiveCrowns.xcodeproj/project.pbxproj`

- [ ] **Step 1: Record the current build settings so nothing is lost**

```bash
xcodebuild -project FiveCrowns.xcodeproj -target FiveCrowns \
  -showBuildSettings > /tmp/settings-before.txt 2>/dev/null
wc -l /tmp/settings-before.txt
```

Expected: a few hundred lines. Keep this file; Step 6 diffs against it.

- [ ] **Step 2: Apply the structural changes to `project.pbxproj`**

Make exactly these edits. Preserve every `XCBuildConfiguration` block **verbatim** — build settings are not part of this migration.

1. `objectVersion = 56;` → `objectVersion = 70;` (70 is the baseline that introduces `PBXFileSystemSynchronizedRootGroup`; anything higher works but is needlessly less compatible)
2. `compatibilityVersion = "Xcode 14.0";` → `compatibilityVersion = "Xcode 15.0";`
3. Delete the **entire** `PBXBuildFile` section (all 17 entries) including its `/* Begin */` and `/* End */` markers.
4. In the `PBXFileReference` section, delete every entry whose `sourceTree` is `"<group>"`. **Keep** the three `BUILT_PRODUCTS_DIR` product entries (`FiveCrowns.app`, `FiveCrownsTests.xctest`, `FiveCrownsUITests.xctest`).
5. In the `PBXGroup` section, delete the groups `FiveCrowns` (`EF2AE4842BCC16630048D0AB`), `Preview Content` (`EF2AE48B2BCC16650048D0AB`), `FiveCrownsTests` (`EF2AE4952BCC16650048D0AB`), `FiveCrownsUITests` (`EF2AE49F2BCC16650048D0AB`), and `Models` (`EF2AE4AF2BCC16720048D0AB`). Keep the root group and `Products`.
6. Add a new section immediately after the `PBXGroup` section:

```
/* Begin PBXFileSystemSynchronizedRootGroup section */
		EF2AE4842BCC16630048D0AB /* FiveCrowns */ = {
			isa = PBXFileSystemSynchronizedRootGroup;
			path = FiveCrowns;
			sourceTree = "<group>";
		};
		EF2AE4952BCC16650048D0AB /* FiveCrownsTests */ = {
			isa = PBXFileSystemSynchronizedRootGroup;
			path = FiveCrownsTests;
			sourceTree = "<group>";
		};
		EF2AE49F2BCC16650048D0AB /* FiveCrownsUITests */ = {
			isa = PBXFileSystemSynchronizedRootGroup;
			path = FiveCrownsUITests;
			sourceTree = "<group>";
		};
/* End PBXFileSystemSynchronizedRootGroup section */
```

The root group's `children` list already references these three IDs — leave it unchanged.

7. Empty the `files = (...)` array of all three `PBXSourcesBuildPhase` and all three `PBXResourcesBuildPhase` entries so each reads `files = (\n\t\t\t);`
8. Add `fileSystemSynchronizedGroups` to each `PBXNativeTarget`, immediately after its `dependencies` array:

```
			fileSystemSynchronizedGroups = (
				EF2AE4842BCC16630048D0AB /* FiveCrowns */,
			);
```

Use `EF2AE4952BCC16650048D0AB` for the `FiveCrownsTests` target and `EF2AE49F2BCC16650048D0AB` for the `FiveCrownsUITests` target.

9. Add a `PBXFileSystemSynchronizedBuildFileExceptionSet` excluding `Info.plist` from the app target, and reference it from the `FiveCrowns` root group's `exceptions` array. A synchronized group sweeps `Info.plist` into Copy Bundle Resources, which collides with `INFOPLIST_FILE` processing and fails the build with `error: Multiple commands produce '.../FiveCrowns.app/Info.plist'`. Excluding it restores exactly the pre-migration bundle contents.

**Applies to later tasks:** any other *non-source* file dropped into `FiveCrowns/` will likewise be swept into Copy Bundle Resources and may need its own exception. Swift files and asset catalogs need no action. `PrivacyInfo.xcprivacy` (Task 20) *should* be bundled, so it needs no exception.

- [ ] **Step 3: Verify the project still parses**

```bash
plutil -lint FiveCrowns.xcodeproj/project.pbxproj
```

Expected: `FiveCrowns.xcodeproj/project.pbxproj: OK`

If this fails, the edit broke the format — revert with `git checkout FiveCrowns.xcodeproj/project.pbxproj` and retry.

- [ ] **Step 4: Verify it builds**

```bash
xcodebuild -project FiveCrowns.xcodeproj -scheme FiveCrowns \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' clean build -quiet 2>&1 | tail -20
```

Expected: `BUILD SUCCEEDED`. If any source file had been dropped from the target, compilation would fail on missing symbols — a successful build proves all 13 sources are still compiled.

- [ ] **Step 5: Prove new files are picked up automatically — this is the point of the task**

```bash
cat > FiveCrowns/SyncProbe.swift <<'EOF'
enum SyncProbe { static let ok = true }
EOF
xcodebuild -project FiveCrowns.xcodeproj -scheme FiveCrowns \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build -quiet 2>&1 | tail -5
rm FiveCrowns/SyncProbe.swift
```

Expected: `BUILD SUCCEEDED` with no pbxproj edit. If it fails, `fileSystemSynchronizedGroups` was not wired to the app target correctly.

- [ ] **Step 6: Confirm build settings are unchanged**

```bash
xcodebuild -project FiveCrowns.xcodeproj -target FiveCrowns \
  -showBuildSettings > /tmp/settings-after.txt 2>/dev/null
diff /tmp/settings-before.txt /tmp/settings-after.txt && echo "IDENTICAL"
```

Expected: `IDENTICAL`. Any difference means a build setting was disturbed — fix it before committing.

- [ ] **Step 7: Run the full test suite**

```bash
xcodebuild test -project FiveCrowns.xcodeproj -scheme FiveCrowns \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -quiet 2>&1 | tail -15
```

Expected: all 4 boilerplate tests pass.

- [ ] **Step 8: Commit**

```bash
git add FiveCrowns.xcodeproj/project.pbxproj
git commit -m "build: migrate project to file-system-synchronized groups

Xcode 16+ synchronized root groups replace explicit PBXFileReference and
PBXBuildFile entries, so files on disk are picked up automatically. This
restructure adds ~12 files; without it each would need four hand-written
pbxproj edits with unique hex IDs.

Build settings verified byte-identical via -showBuildSettings.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

## Task 2: Delete dead code and restructure into folders

`AddPlayerView`, `UpdatePlayerView`, `UpdateScoreView` and `Styles.swift` are referenced only from their own `#Preview` blocks — verified by grep across the whole repo. The score-entry interaction stays as alerts (spec decision), so these have no path back.

**Files:**
- Delete: `FiveCrowns/AddPlayerView.swift`, `FiveCrowns/UpdatePlayerView.swift`, `FiveCrowns/UpdateScoreView.swift`, `FiveCrowns/Styles.swift`
- Move: all remaining sources into `App/`, `Model/`, `Views/`, `Views/Components/`

- [ ] **Step 1: Confirm the four files really are unreferenced**

```bash
grep -rn --include="*.swift" -E "AddPlayerView|UpdatePlayerView|UpdateScoreView|SubmitButtonStyle|DeleteButtonStyle" FiveCrowns/ \
  | grep -v -E "^FiveCrowns/(AddPlayerView|UpdatePlayerView|UpdateScoreView|Styles)\.swift:"
```

Expected: **no output.** Any output means something still references them — stop and report.

- [ ] **Step 2: Delete and move**

```bash
git rm -q FiveCrowns/AddPlayerView.swift FiveCrowns/UpdatePlayerView.swift \
          FiveCrowns/UpdateScoreView.swift FiveCrowns/Styles.swift

mkdir -p FiveCrowns/App FiveCrowns/Model FiveCrowns/Persistence \
         FiveCrowns/Views/Components FiveCrowns/Support

git mv FiveCrowns/FiveCrownsApp.swift      FiveCrowns/App/
git mv FiveCrowns/Models/Game.swift        FiveCrowns/Model/
git mv FiveCrowns/Models/Player.swift      FiveCrowns/Model/
git mv FiveCrowns/Models/Round.swift       FiveCrowns/Model/
git mv FiveCrowns/Models/RankedPlayer.swift FiveCrowns/Model/
git mv FiveCrowns/ScorecardView.swift      FiveCrowns/Views/
git mv FiveCrowns/ScorecardRow.swift       FiveCrowns/Views/
git mv FiveCrowns/LeaderboardView.swift    FiveCrowns/Views/
git mv FiveCrowns/ScorecardHeaders.swift   FiveCrowns/Views/Components/
rmdir FiveCrowns/Models
```

- [ ] **Step 3: Build**

```bash
xcodebuild -project FiveCrowns.xcodeproj -scheme FiveCrowns \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' clean build -quiet 2>&1 | tail -10
```

Expected: `BUILD SUCCEEDED`, with no pbxproj changes required. This is Task 1 paying off.

- [ ] **Step 4: Confirm pbxproj was untouched**

```bash
git status --short FiveCrowns.xcodeproj/
```

Expected: no output.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "refactor: delete dead views and restructure into layered folders

AddPlayerView, UpdatePlayerView, UpdateScoreView and Styles.swift were
referenced only by their own #Preview blocks (~180 lines). The alert-based
score entry they were replaced by is staying, so they have no path back.

Remaining sources move into App/, Model/, Views/, Views/Components/.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

# Phase 1 — Characterisation tests

Lock in current behaviour before changing any of it. These tests are written against the **existing** API and will be updated as the model is refactored in Phase 3 — that is intentional. Their job is to catch accidental behaviour changes during the refactor.

## Task 3: Replace test boilerplate with Swift Testing scaffolding

**Files:**
- Delete: `FiveCrownsTests/FiveCrownsTests.swift`
- Create: `FiveCrownsTests/PlayerTests.swift`

- [ ] **Step 1: Delete the boilerplate and write the first real test**

```bash
git rm -q FiveCrownsTests/FiveCrownsTests.swift
```

Create `FiveCrownsTests/PlayerTests.swift`:

```swift
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
```

- [ ] **Step 2: Run the tests**

```bash
xcodebuild test -project FiveCrowns.xcodeproj -scheme FiveCrowns \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:FiveCrownsTests -quiet 2>&1 | tail -20
```

Expected: 5 tests pass. If `zeroIsNotAbsent` fails, stop — that indicates the double-optional `[Int: Int?]` behaves differently than the spec assumes, and Task 8 needs rethinking.

- [ ] **Step 3: Commit**

```bash
git add -A
git commit -m "test: characterise Player scoring behaviour

Replaces Xcode boilerplate with Swift Testing. Locks in current
behaviour before the Phase 3 model refactor.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

## Task 4: Characterise ranking behaviour

Ranking is **dense**: tied players share a rank and the next distinct score takes the immediately following rank (1, 1, 2 — not 1, 1, 3). This is current behaviour and the spec keeps it. These tests exist to stop it changing by accident.

**Files:**
- Create: `FiveCrownsTests/RankingTests.swift`

- [ ] **Step 1: Write the tests**

```swift
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
```

- [ ] **Step 2: Run and confirm they pass against current behaviour**

```bash
xcodebuild test -project FiveCrowns.xcodeproj -scheme FiveCrowns \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:FiveCrownsTests/RankingTests -quiet 2>&1 | tail -20
```

Expected: 5 tests pass.

- [ ] **Step 3: Commit**

```bash
git add -A
git commit -m "test: characterise dense ranking semantics

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

## Task 5: Capture a real v1 save fixture

The Phase 3 migration must be tested against a genuine file produced by the current code, not a hand-authored approximation.

**Files:**
- Create: `FiveCrownsTests/Fixtures/legacy-v1-game.json`
- Create: `FiveCrownsTests/LegacyFixtureTests.swift`

- [ ] **Step 1: Generate the fixture from the current model**

```bash
mkdir -p FiveCrownsTests/Fixtures
cat > /tmp/gen-fixture.swift <<'EOF'
import Foundation
import Observation

@Observable
class Player: Codable, Identifiable {
    var id = UUID()
    var name: String
    var order: Int
    var scores: [Int: Int?] = [:]
    var totalPoints: Int = 0
    init(name: String, order: Int) { self.name = name; self.order = order }
    func setScore(round: Int, points: Int? = nil) { scores[round] = points; updateTotal() }
    func updateTotal() { totalPoints = scores.values.reduce(0) { $0 + ($1 ?? 0) } }
}

let ada = Player(name: "Ada", order: 1)
ada.setScore(round: 1, points: 7)
ada.setScore(round: 2, points: 0)
ada.setScore(round: 3, points: 21)

let grace = Player(name: "Grace", order: 2)
grace.setScore(round: 1, points: 13)
grace.setScore(round: 2, points: 5)
grace.setScore(round: 3, points: nil)

let data = try JSONEncoder().encode([ada, grace])
FileHandle.standardOutput.write(data)
EOF
swift /tmp/gen-fixture.swift > FiveCrownsTests/Fixtures/legacy-v1-game.json 2>/dev/null
cat FiveCrownsTests/Fixtures/legacy-v1-game.json
```

Expected: JSON containing `_name`, `_scores`, `_order`, `_totalPoints`, `_id` and `_$observationRegistrar` keys. Confirm `"_name":"Ada"` and `"_name":"Grace"` are both present.

- [ ] **Step 2: Add the fixture to the test bundle as a resource**

Synchronized groups include non-source files as resources automatically, but confirm it is readable from the test bundle. Create `FiveCrownsTests/LegacyFixtureTests.swift`:

```swift
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
```

- [ ] **Step 3: Run**

```bash
xcodebuild test -project FiveCrowns.xcodeproj -scheme FiveCrowns \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:FiveCrownsTests/LegacyFixtureTests -quiet 2>&1 | tail -20
```

Expected: 1 test passes. If the resource is not found, add an explicit `PBXFileSystemSynchronizedBuildFileExceptionSet` for the test target — but try the default first.

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "test: capture genuine v1 save fixture for migration testing

Generated from the current @Observable + Codable model so the Phase 3
migration is tested against the real format, underscore keys and all.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

# Phase 2 — Defect fixes

View- and app-level fixes with no model changes. Everything here is independently revertible.

## Task 6: Remove crash paths and introduce structured logging

**Files:**
- Modify: `FiveCrowns/App/FiveCrownsApp.swift`
- Modify: `FiveCrowns/Model/Game.swift`
- Create: `FiveCrowns/Support/AppLog.swift`

- [ ] **Step 1: Create the logger**

`FiveCrowns/Support/AppLog.swift`:

```swift
import OSLog

enum AppLog {
    static let persistence = Logger(subsystem: "com.challengr.FiveCrowns", category: "persistence")
    static let game = Logger(subsystem: "com.challengr.FiveCrowns", category: "game")
}
```

- [ ] **Step 2: Replace `puts` in `Game.swift`**

In `FiveCrowns/Model/Game.swift`, delete these three lines entirely:

```swift
puts("data = '\(String(data: data, encoding: .utf8) ?? "unknown")'")
puts("Saving game data...")
puts("done.")
```

The first one logs the entire save file to the console and must not be replaced with a `Logger` equivalent — delete it.

- [ ] **Step 3: Replace both `fatalError` calls in `FiveCrownsApp.swift`**

Replace the body of the `WindowGroup` closure's error handling:

```swift
ScorecardView(round: 1) {
    Task {
        do {
            try await game.save(players: game.players)
        } catch {
            AppLog.persistence.error("Save failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}
```

and:

```swift
.task {
    do {
        try await game.load()
    } catch {
        AppLog.persistence.error("Load failed, starting empty: \(error.localizedDescription, privacy: .public)")
    }
}
```

- [ ] **Step 4: Verify no crash paths remain**

```bash
grep -rn --include="*.swift" "fatalError" FiveCrowns/
```

Expected: **no output.**

```bash
grep -rn --include="*.swift" "puts(" FiveCrowns/
```

Expected: **exactly 8 hits**, all inside `#Preview` blocks — 4 in `Views/ScorecardRow.swift` and 4 in `Views/Components/ScorecardHeaders.swift`, passed as `scoreChanged:` / `playerDeleted:` closures. Leave them. They are preview scaffolding, not crash paths, and both files' previews are rewritten later: `ScorecardRow` in Task 13 (its initialiser signature changes, so the previews *must* be updated to compile) and `ScorecardHeaders` in Task 13 for the same reason. Task 21 verifies the count has reached zero by then.

Do **not** expand this task's scope to fix them — view code belongs to Task 13.

- [ ] **Step 5: Build and test**

```bash
xcodebuild test -project FiveCrowns.xcodeproj -scheme FiveCrowns \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:FiveCrownsTests -quiet 2>&1 | tail -15
```

Expected: `BUILD SUCCEEDED`, 11 tests pass.

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "fix: remove fatalError crash paths and console logging of save data

A corrupt save file previously crashed the app on every launch, bricking
the install permanently. Load failure now starts empty and save failure
is logged. Also deletes the puts() call that printed the entire save file
to the console.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

## Task 7: Fix invalid frames, scroll gating, and the Next button

**Files:**
- Modify: `FiveCrowns/Views/ScorecardView.swift`

- [ ] **Step 1: Fix the two invalid frame modifiers**

`width:` takes a fixed dimension; passing `.infinity` produces a runtime "Invalid frame dimension (negative or non-finite)" log. Both occurrences become `maxWidth:`:

```swift
// was: .frame(width: .infinity, alignment: .center)
.frame(maxWidth: .infinity, alignment: .center)
```

```swift
// was: .frame(width: .infinity)
.frame(maxWidth: .infinity)
```

- [ ] **Step 2: Delete the scroll gate**

Remove this line entirely:

```swift
.scrollDisabled(round < 6)
```

It gated scrolling on round number rather than content height, putting the Add Player button out of reach with six or more players.

- [ ] **Step 3: Disable Next on the final round**

The Next button silently no-ops at round 11 while still appearing tappable. Add the modifier alongside the existing `.tint`:

```swift
Button(action: nextRound) {
    Label("Next", systemImage: "arrow.forward")
        .fontWeight(.semibold)
        .labelStyle(.titleAndIcon)
}
.disabled(round == 11)
.tint(Color("ButtonColour", bundle: .main).opacity(0.8))
.buttonStyle(.borderedProminent)
.padding(.vertical, 8)
.padding(.horizontal, 16)
```

This also removes the `Label("   Next   ", ...)` whitespace-padding hack and the stacked empty-icon `Label` beneath it.

- [ ] **Step 4: Verify no invalid frames remain**

```bash
grep -rn --include="*.swift" "frame(width: .infinity" FiveCrowns/
```

Expected: **no output.**

- [ ] **Step 5: Build and test**

```bash
xcodebuild test -project FiveCrowns.xcodeproj -scheme FiveCrowns \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:FiveCrownsTests -quiet 2>&1 | tail -15
```

Expected: `BUILD SUCCEEDED`, 11 tests pass.

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "fix: invalid frame dimensions, scroll gating, and Next button state

- .frame(width: .infinity) is invalid and logged at runtime; use maxWidth
- .scrollDisabled(round < 6) made Add Player unreachable with 6+ players
- Next stayed enabled on round 11 while doing nothing

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

## Task 8: Add Cancel to the score entry alert

Alerts cannot be dismissed by tapping outside, so a mis-tap on a score cell currently forces the user to either write a zero or re-confirm.

**Files:**
- Modify: `FiveCrowns/Views/ScorecardRow.swift`

- [ ] **Step 1: Add the cancel button**

```swift
.alert("Enter Score", isPresented: $showingAddScore, actions: {
    Button("Cancel", role: .cancel, action: {})
    Button("Went Down!", role: .none, action: wentDown)
    Button("Confirm", role: .none, action: addScore)
    TextField("Score", text: $newScore)
        .keyboardType(.numberPad)
        .focused($scoreFieldIsFocused)
}, message: {
    Text("Enter score for \(player.name)")
})
```

- [ ] **Step 2: Build and test**

```bash
xcodebuild test -project FiveCrowns.xcodeproj -scheme FiveCrowns \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:FiveCrownsTests -quiet 2>&1 | tail -15
```

Expected: `BUILD SUCCEEDED`, 11 tests pass.

- [ ] **Step 3: Commit**

```bash
git add -A
git commit -m "fix: add Cancel to the score entry alert

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

# Phase 3 — Model and persistence restructure

The core of the plan. Each task is TDD: test first, watch it fail, implement, watch it pass.

## Execution order: 9 → 11 → 12 → (10 + 13)

Tasks are **executed** in a different order than they are numbered, because Tasks 11 and 12 only *add* files and can each land green on their own:

| Order | Task | Buildable alone? |
|---|---|---|
| 1st | 9 — `Round` enum | Yes — new type, nothing adopts it yet |
| 2nd | 11 — `GameSnapshot` DTO + migration | Yes — new files only; needs `Round` |
| 3rd | 12 — `GameStore` actor | Yes — new files only; needs `GameSnapshot` and `AppLog` |
| 4th | 10 + 13 — `Player` rewrite and `Game` rules | **No** — Task 10 breaks the app target until Task 13 restores it |

Only the final pair is genuinely coupled, so only that pair shares a commit. This gives three extra green checkpoints and shrinks the one unavoidable big-bang commit.

## Task 9: Introduce `Round` as an enum

`Round.wildcardFor` is deleted rather than carried over — it is unused, displaying the wild card is an explicit non-goal, and "no dead code" is an acceptance criterion. It remains in git history.

**Files:**
- Rewrite: `FiveCrowns/Model/Round.swift`
- Create: `FiveCrownsTests/RoundTests.swift`

- [ ] **Step 1: Write the failing test**

`FiveCrownsTests/RoundTests.swift`:

```swift
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
```

- [ ] **Step 2: Run and watch it fail**

```bash
xcodebuild test -project FiveCrowns.xcodeproj -scheme FiveCrowns \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:FiveCrownsTests/RoundTests -quiet 2>&1 | tail -20
```

Expected: compilation failure — `Round.allCases`, `cardCount`, `first`, `last`, `next`, `previous` do not exist.

- [ ] **Step 3: Implement**

Replace the entire contents of `FiveCrowns/Model/Round.swift`:

```swift
import Foundation

/// A round of Five Crowns. Eleven rounds are played, dealing three cards in
/// the first and thirteen in the last.
enum Round: Int, CaseIterable, Codable, Sendable, Comparable {
    case one = 1, two, three, four, five, six, seven, eight, nine, ten, eleven

    static let first = Round.one
    static let last = Round.eleven

    /// Cards dealt this round: three in round one, up to thirteen in round eleven.
    var cardCount: Int { rawValue + 2 }

    var next: Round? { Round(rawValue: rawValue + 1) }
    var previous: Round? { Round(rawValue: rawValue - 1) }

    static func < (lhs: Round, rhs: Round) -> Bool { lhs.rawValue < rhs.rawValue }
}
```

- [ ] **Step 4: Run and watch it pass**

```bash
xcodebuild test -project FiveCrowns.xcodeproj -scheme FiveCrowns \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:FiveCrownsTests/RoundTests -quiet 2>&1 | tail -20
```

Expected: 6 tests pass. The app target will not yet use `Round` — that happens in Task 13.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "refactor: replace Round static class with an enum

Retires the magic 11 and round+2 scattered through the views. Drops the
unused wildcardFor(round:) — displaying the wild card is a non-goal and
it remains in git history.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

## Task 10: Simplify `Player`

**Files:**
- Rewrite: `FiveCrowns/Model/Player.swift`
- Modify: `FiveCrownsTests/PlayerTests.swift`
- Modify: `FiveCrowns/Views/ScorecardRow.swift`, `FiveCrowns/Model/Game.swift` (call sites)

- [ ] **Step 1: Update the tests to the new API**

Rewrite `FiveCrownsTests/PlayerTests.swift`:

```swift
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
```

- [ ] **Step 2: Run and watch it fail**

Expected: compilation failure — `Player(name:)` without `order:`, `score(for:)`, `setScore(_:for:)`, `resetScores()` do not exist.

- [ ] **Step 3: Implement**

Replace the entire contents of `FiveCrowns/Model/Player.swift`:

```swift
import Foundation
import Observation

/// One player's identity and per-round scores for a single game.
///
/// Deliberately not `Codable`: persistence goes through `PlayerSnapshot` so
/// the save format does not track the `@Observable` macro's backing storage.
@Observable
final class Player: Identifiable {
    let id: UUID
    var name: String
    private(set) var scores: [Round: Int]

    init(id: UUID = UUID(), name: String, scores: [Round: Int] = [:]) {
        self.id = id
        self.name = name
        self.scores = scores
    }

    /// Derived rather than stored, so it can never drift out of sync.
    var totalPoints: Int { scores.values.reduce(0, +) }

    func score(for round: Round) -> Int? { scores[round] }

    /// Passing `nil` clears the entry, which is how "no score yet" is represented.
    func setScore(_ points: Int?, for round: Round) {
        if let points {
            scores[round] = points
        } else {
            scores.removeValue(forKey: round)
        }
    }

    func resetScores() { scores = [:] }
}
```

- [ ] **Step 4: Update the two call sites**

In `FiveCrowns/Views/ScorecardRow.swift` the row still takes `round: Int`. Change the property to `let round: Round` and update the score accessors as shown below. This is an **intermediate state** — Task 13 replaces the file entirely, dropping `round` in favour of reading `Game` from the environment. The point here is only to keep the change reviewable in sequence.

```swift
var points: String {
    if let points = player.score(for: round) { "\(points)" } else { "-" }
}

func wentDown() {
    player.setScore(0, for: round)
    scoreChanged()
}

func addScore() {
    player.setScore(Int(newScore), for: round)
    scoreChanged()
}

func showAddScore() {
    newScore = player.score(for: round).map(String.init) ?? ""
    showingAddScore = true
    scoreFieldIsFocused = true
}
```

The redundant `player.updateTotal()` calls are deleted — the total is computed now.

In `FiveCrowns/Model/Game.swift`, update `addPlayer` and `reset`:

```swift
func addPlayer(name: String) {
    players.append(Player(name: name))
}

func reset() {
    players.forEach { $0.resetScores() }
}
```

`Game.load()` and `save(players:)` will not compile because `Player` is no longer `Codable`. Leave them broken **only if** Task 11 follows immediately; otherwise temporarily stub them to no-ops and note it. Prefer completing Tasks 11–13 in sequence.

- [ ] **Step 5: Commit once Task 13 restores a building state**

This task intentionally leaves the app target non-building, because `Player` stops being `Codable` while `Game.load()`/`save(players:)` still expect it to be. Do not commit alone — **Tasks 10 and 13 land as a single commit** at the end of Task 13.

Execute this task only *after* Tasks 9, 11 and 12 are committed, so the window in which the project does not build is as short as possible.

---

## Task 11: Persistence DTO with v1 migration

**Files:**
- Create: `FiveCrowns/Persistence/GameSnapshot.swift`
- Create: `FiveCrownsTests/GameSnapshotTests.swift`

- [ ] **Step 1: Write the failing tests**

`FiveCrownsTests/GameSnapshotTests.swift`:

```swift
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
```

- [ ] **Step 2: Run and watch it fail**

Expected: compilation failure — `GameSnapshot` does not exist.

- [ ] **Step 3: Implement**

`FiveCrowns/Persistence/GameSnapshot.swift`:

```swift
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
        self.init(
            round: Round.first.rawValue,   // v1 never persisted the round
            players: legacy.map {
                PlayerSnapshot(id: $0.id, name: $0.name, scores: $0.scores)
            }
        )
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
```

- [ ] **Step 4: Run and watch it pass**

```bash
xcodebuild test -project FiveCrowns.xcodeproj -scheme FiveCrowns \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:FiveCrownsTests/GameSnapshotTests -quiet 2>&1 | tail -25
```

Expected: 5 tests pass. `decodesLegacyFixture` is the important one — if `ada.scores[2]` comes back `nil` instead of `0`, the `compactMapValues` is discarding real zeros and must be fixed.

- [ ] **Step 5: Commit**

Task 11 adds only new files, so it lands green on its own — execute it *before* Task 10.

```bash
git add -A
git commit -m "feat: add GameSnapshot DTO with v1 save migration

Decouples the save format from @Observable's backing storage, which was
leaking _name and _\$observationRegistrar into the JSON. Reads genuine v1
files, verified against a fixture captured from the pre-refactor build.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

## Task 12: `GameStore` actor

**Files:**
- Create: `FiveCrowns/Persistence/GameStore.swift`
- Create: `FiveCrownsTests/GameStoreTests.swift`

- [ ] **Step 1: Write the failing tests**

`FiveCrownsTests/GameStoreTests.swift`:

```swift
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
}
```

- [ ] **Step 2: Run and watch it fail**

Expected: compilation failure — `GameStore` does not exist.

- [ ] **Step 3: Implement**

`FiveCrowns/Persistence/GameStore.swift`:

```swift
import Foundation

/// Reads and writes the game file. An actor so file I/O stays off the main
/// thread — the previous implementation wrapped I/O in `Task { }`, which
/// inherits the caller's executor and therefore did not.
actor GameStore {
    private let fileURL: URL
    private let debounce: Duration
    private var pendingSave: Task<Void, Never>?
    private var pendingSnapshot: GameSnapshot?
    /// Set when the file on disk was written by a newer build. Writing would
    /// destroy data this build cannot represent, so all saves become no-ops.
    private var isReadOnly = false

    init(fileURL: URL, debounce: Duration = .milliseconds(500)) {
        self.fileURL = fileURL
        self.debounce = debounce
    }

    /// The app's real store, in the documents directory.
    static func documents() throws -> GameStore {
        let directory = try FileManager.default.url(
            for: .documentDirectory, in: .userDomainMask,
            appropriateFor: nil, create: true)
        return GameStore(fileURL: directory.appendingPathComponent("game.data"))
    }

    func load() -> GameSnapshot? {
        guard let data = try? Data(contentsOf: fileURL), !data.isEmpty else {
            return nil
        }
        if let snapshot = try? JSONDecoder().decode(GameSnapshot.self, from: data) {
            guard !snapshot.isFromFutureVersion else {
                // Written by a newer build. Loading would silently drop fields
                // we do not understand, and saving would destroy them. Start
                // empty and leave the file untouched so the newer build can
                // still read it.
                isReadOnly = true
                AppLog.persistence.error(
                    "Save file is schema v\(snapshot.schemaVersion) but this build reads v\(GameSnapshot.currentSchemaVersion); refusing to load or overwrite.")
                return nil
            }
            return snapshot
        }
        if let migrated = GameSnapshot(legacyData: data) {
            AppLog.persistence.info("Migrated a v1 save file to v2.")
            return migrated
        }
        quarantine(data)
        return nil
    }

    func save(_ snapshot: GameSnapshot) throws {
        guard !isReadOnly else { return }
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(snapshot)
        try data.write(to: fileURL, options: .atomic)
    }

    /// Coalesces rapid mutations into one write.
    func scheduleSave(_ snapshot: GameSnapshot) {
        pendingSnapshot = snapshot
        pendingSave?.cancel()
        pendingSave = Task { [debounce] in
            try? await Task.sleep(for: debounce)
            guard !Task.isCancelled else { return }
            self.writePending()
        }
    }

    /// Writes any pending snapshot immediately rather than waiting out the
    /// debounce. Call before the app goes to the background.
    func flush() {
        pendingSave?.cancel()
        pendingSave = nil
        writePending()
    }

    private func writePending() {
        guard let snapshot = pendingSnapshot else { return }
        pendingSnapshot = nil
        do {
            try save(snapshot)
        } catch {
            AppLog.persistence.error(
                "Save failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Moves an undecodable file aside so the app can still launch. Previously
    /// a corrupt file crashed on every launch, bricking the install.
    private func quarantine(_ data: Data) {
        var candidate = fileURL.appendingPathExtension("corrupt")
        var suffix = 1
        while FileManager.default.fileExists(atPath: candidate.path) {
            candidate = fileURL.appendingPathExtension("corrupt-\(suffix)")
            suffix += 1
        }
        try? data.write(to: candidate, options: .atomic)
        try? FileManager.default.removeItem(at: fileURL)
        AppLog.persistence.error(
            "Save file was unreadable; quarantined to \(candidate.lastPathComponent, privacy: .public)")
    }
}
```

**Why `flush()` writes rather than waits:** holding the pending snapshot separately from the timer means the flush can cancel the debounce and write immediately. Awaiting the timer instead would block for up to 500ms at exactly the moment iOS is suspending the app.

- [ ] **Step 4: Run and watch it pass**

```bash
xcodebuild test -project FiveCrowns.xcodeproj -scheme FiveCrowns \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:FiveCrownsTests/GameStoreTests -quiet 2>&1 | tail -25
```

Expected: 5 tests pass.

- [ ] **Step 5: Commit**

Task 12 also adds only new files, so it lands green on its own — execute it *before* Task 10.

```bash
git add -A
git commit -m "feat: add GameStore actor for persistence

File I/O moves off the main thread - the previous Task {} wrappers
inherited the caller's executor and did not. Atomic writes, debounced
coalescing saves, and corrupt files quarantined rather than crashing
the app on every launch.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

## Task 13: `Game` owns the rules

**Files:**
- Rewrite: `FiveCrowns/Model/Game.swift`
- Rewrite: `FiveCrowns/Model/Ranking.swift` (replacing `RankedPlayer.swift`)
- Create: `FiveCrownsTests/GameTests.swift`
- Modify: `FiveCrowns/App/FiveCrownsApp.swift`, `FiveCrowns/Views/ScorecardView.swift`, `FiveCrowns/Views/ScorecardRow.swift`, `FiveCrowns/Views/LeaderboardView.swift`

- [ ] **Step 1: Write the failing tests**

`FiveCrownsTests/GameTests.swift`:

```swift
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
```

- [ ] **Step 2: Run and watch it fail**

Expected: compilation failure across the whole new API.

- [ ] **Step 3: Implement `Ranking`**

Delete `FiveCrowns/Model/RankedPlayer.swift` and create `FiveCrowns/Model/Ranking.swift`:

```swift
import Foundation

struct RankedPlayer: Identifiable {
    let player: Player
    let rank: Int
    var id: Player.ID { player.id }
}

enum Ranking {
    /// Dense ranking: tied players share a rank and the next distinct score
    /// takes the immediately following rank (1, 1, 2 — not 1, 1, 3).
    static func rank(_ players: [Player]) -> [RankedPlayer] {
        let sorted = players.sorted { $0.totalPoints < $1.totalPoints }
        let rankByScore = Dictionary(
            uniqueKeysWithValues: Set(sorted.map(\.totalPoints)).sorted()
                .enumerated().map { ($1, $0 + 1) }
        )
        return sorted.map { RankedPlayer(player: $0, rank: rankByScore[$0.totalPoints] ?? 1) }
    }
}
```

Update `FiveCrownsTests/RankingTests.swift` to call `Ranking.rank(_:)` and build players with `Player(name:)` / `setScore(_:for:)`.

- [ ] **Step 4: Implement `Game`**

Replace the entire contents of `FiveCrowns/Model/Game.swift`:

```swift
import Foundation
import Observation

/// The state and rules of one game of Five Crowns.
@MainActor
@Observable
final class Game {
    private(set) var players: [Player] = []
    private(set) var round: Round = .first
    /// Set when a background save fails, so the UI can say so without crashing.
    private(set) var saveFailed = false

    private var announcedRounds: Set<Round> = []
    private let store: GameStore

    init(store: GameStore) {
        self.store = store
    }

    // MARK: Roster

    func addPlayer(named name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        players.append(Player(name: trimmed))
        autosave()
    }

    func removePlayer(id: Player.ID) {
        players.removeAll { $0.id == id }
        autosave()
    }

    func rename(id: Player.ID, to name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let player = players.first(where: { $0.id == id }) else { return }
        player.name = trimmed
        autosave()
    }

    // MARK: Scoring

    func setScore(_ points: Int?, for id: Player.ID) {
        players.first { $0.id == id }?.setScore(points, for: round)
        autosave()
    }

    func score(for id: Player.ID) -> Int? {
        players.first { $0.id == id }?.score(for: round)
    }

    // MARK: Rules

    var isRoundComplete: Bool {
        !players.isEmpty && players.allSatisfy { $0.score(for: round) != nil }
    }

    var isGameOver: Bool { round == .last && isRoundComplete }

    /// True the first time a round becomes complete, false after it has been
    /// acknowledged — so correcting a score does not re-announce.
    var needsRoundCompleteAnnouncement: Bool {
        isRoundComplete && !announcedRounds.contains(round)
    }

    func acknowledgeRound() {
        announcedRounds.insert(round)
    }

    var canAdvance: Bool { round.next != nil }
    var canRetreat: Bool { round.previous != nil }

    func advance() {
        guard let next = round.next else { return }
        round = next
        autosave()
    }

    func retreat() {
        guard let previous = round.previous else { return }
        round = previous
        autosave()
    }

    func startNewGame() {
        players.forEach { $0.resetScores() }
        round = .first
        announcedRounds = []
        autosave()
    }

    var leaderboard: [RankedPlayer] { Ranking.rank(players) }
    var winner: Player? { leaderboard.first?.player }

    // MARK: Persistence

    func snapshot() -> GameSnapshot {
        GameSnapshot(
            round: round.rawValue,
            players: players.map {
                PlayerSnapshot(
                    id: $0.id,
                    name: $0.name,
                    scores: Dictionary(uniqueKeysWithValues:
                        $0.scores.map { ($0.key.rawValue, $0.value) })
                )
            }
        )
    }

    func apply(_ snapshot: GameSnapshot) {
        round = snapshot.clampedRound
        players = snapshot.players.map { snap in
            Player(
                id: snap.id,
                name: snap.name,
                scores: Dictionary(uniqueKeysWithValues:
                    snap.scores.compactMap { key, value in
                        Round(rawValue: key).map { ($0, value) }
                    })
            )
        }
        announcedRounds = []
    }

    func loadFromDisk() async {
        if let snapshot = await store.load() {
            apply(snapshot)
        }
    }

    /// Flushes any pending debounced write. Call on scene-phase change.
    func flush() async {
        await store.flush()
    }

    private func autosave() {
        let snapshot = snapshot()
        Task { await store.scheduleSave(snapshot) }
    }
}
```

- [ ] **Step 5: Update the views and app entry point**

`FiveCrowns/App/FiveCrownsApp.swift`:

```swift
import SwiftUI

@main
struct FiveCrownsApp: App {
    @State private var game: Game

    init() {
        // A store that cannot reach the documents directory still lets the app
        // run; it simply will not persist.
        let store = (try? GameStore.documents())
            ?? GameStore(fileURL: FileManager.default.temporaryDirectory
                .appendingPathComponent("game.data"))
        _game = State(initialValue: Game(store: store))
    }

    var body: some Scene {
        WindowGroup {
            ScorecardView()
                .environment(game)
                .background(
                    Gradient(colors: [
                        Color("BackgroundDark", bundle: .main),
                        Color("BackgroundMiddle", bundle: .main),
                        Color("Background", bundle: .main),
                    ]).opacity(0.8)
                )
                .task { await game.loadFromDisk() }
        }
    }
}
```

Replace the entire contents of `FiveCrowns/Views/ScorecardView.swift`:

```swift
import SwiftUI

struct ScorecardView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(Game.self) private var game

    @State private var showingAddPlayer = false
    @State private var newPlayerName = ""
    @FocusState private var playerFieldIsFocused: Bool

    @State private var showingLeaderboard = false
    @State private var showingRoundComplete = false
    @State private var showingGameOver = false
    @State private var showingNewGameConfirmation = false

    var body: some View {
        VStack(spacing: 0) {
            RoundHeader(round: game.round)
            scorecard
            Spacer(minLength: 0)
            roundNavigation
            if game.round > .one { leaderboardButton }
        }
        .popover(isPresented: $showingLeaderboard) {
            LeaderboardView(showView: $showingLeaderboard)
        }
        .alert("Add Player", isPresented: $showingAddPlayer) {
            Button("Cancel", role: .cancel) { newPlayerName = "" }
            Button("Confirm", action: addPlayer)
            TextField("Player name", text: $newPlayerName)
                .keyboardType(.asciiCapable)
                .focused($playerFieldIsFocused)
        }
        .alert("Round Complete!", isPresented: $showingRoundComplete) {
            Button("Cancel", role: .cancel) { game.acknowledgeRound() }
            Button("OK") { game.acknowledgeRound(); game.advance() }
        } message: {
            Text("Ready to move on?")
        }
        .alert("Game Over!", isPresented: $showingGameOver) {
            Button("Cancel", role: .cancel) { game.acknowledgeRound() }
            Button("View Leaderboard") { game.acknowledgeRound(); showingLeaderboard = true }
        } message: {
            if let winner = game.winner { Text("\(winner.name) is the winner!") }
        }
        .alert("Start New Game?", isPresented: $showingNewGameConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("OK") { game.startNewGame() }
        } message: {
            Text("Are you sure?")
        }
        .onChange(of: game.needsRoundCompleteAnnouncement) { _, needsAnnouncement in
            guard needsAnnouncement else { return }
            if game.isGameOver { showingGameOver = true } else { showingRoundComplete = true }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase != .active { Task { await game.flush() } }
        }
    }

    @ViewBuilder
    private var scorecard: some View {
        if game.players.isEmpty { addPlayerButton } else { ScorecardHeaders() }

        ScrollView {
            VStack(spacing: 0) {
                ForEach(game.players) { player in
                    ScorecardRow(player: player, editMode: game.round == .one)
                    Divider().overlay(Theme.headerRow)
                }
                if !game.players.isEmpty && game.round == .one {
                    addPlayerButton.padding(.top, 16)
                }
                if game.isGameOver {
                    Button { showingNewGameConfirmation = true } label: {
                        Label("New Game", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.button)
                    .padding()
                }
            }
        }
        .frame(minHeight: 0)
    }

    private var roundNavigation: some View {
        HStack {
            Button(action: game.retreat) {
                Label("Previous", systemImage: "arrow.backward").fontWeight(.semibold)
            }
            .disabled(!game.canRetreat)
            Spacer()
            Button(action: game.advance) {
                Label("Next", systemImage: "arrow.forward").fontWeight(.semibold)
            }
            .disabled(!game.canAdvance)
        }
        .labelStyle(.titleAndIcon)
        .buttonStyle(.borderedProminent)
        .tint(Theme.button)
        .padding()
    }

    private var leaderboardButton: some View {
        Button { showingLeaderboard = true } label: {
            Label("Leaderboard", systemImage: "list.star")
                .fontWeight(.semibold)
                .padding(.vertical, 8)
                .padding(.horizontal, 16)
        }
        .buttonStyle(.borderedProminent)
        .tint(Theme.button)
        .padding(8)
    }

    private var addPlayerButton: some View {
        Button {
            showingAddPlayer = true
            playerFieldIsFocused = true
        } label: {
            Label("Add Player", systemImage: "plus")
                .fontWeight(.semibold)
                .padding(.vertical, 8)
                .padding(.horizontal, 16)
        }
        .buttonStyle(.borderedProminent)
        .tint(Theme.button)
    }

    private func addPlayer() {
        withAnimation { game.addPlayer(named: newPlayerName) }
        newPlayerName = ""
    }
}
```

The `.frame(maxWidth:)` pair and the background gradient are added in Task 17 — leave them out here.

Replace `FiveCrowns/Views/ScorecardRow.swift`. It now reads `Game` from the environment rather than taking callbacks, so `round`, scoring and deletion all route through the model:

```swift
import SwiftUI

struct ScorecardRow: View {
    @Environment(Game.self) private var game
    let player: Player
    let editMode: Bool

    @State private var showingAddScore = false
    @State private var newScore = ""
    @FocusState private var scoreFieldIsFocused: Bool

    @State private var showingRename = false
    @State private var newName = ""

    private var points: Int? { player.score(for: game.round) }

    var body: some View {
        HStack(spacing: 0) {
            if editMode {
                Button { game.removePlayer(id: player.id) } label: {
                    Image(systemName: "trash").padding(.vertical, 8).padding(.leading, 8)
                }
                .foregroundColor(.red)
            }

            Text(player.name)
                .foregroundStyle(Theme.primaryText)
                .fontWeight(.medium)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
                .onTapGesture(perform: showRename)

            Text(points.map(String.init) ?? "-")
                .foregroundStyle(Theme.primaryText)
                .fontWeight(.medium)
                .frame(minWidth: 44)
                .padding(8)
                .border(points == nil ? Color.gray : Color.accentColor)
                .background(points == 0 ? Color.accentColor.opacity(0.2) : Color.clear)
                .onTapGesture(perform: showAddScore)

            Text("\(player.totalPoints)")
                .foregroundStyle(Theme.primaryText)
                .fontWeight(.semibold)
                .frame(minWidth: 44)
                .padding(8)
        }
        .frame(maxWidth: .infinity)
        .padding(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
        .background(Theme.row)
        .alert("Enter Score", isPresented: $showingAddScore) {
            Button("Cancel", role: .cancel) {}
            Button("Went Down!") { game.setScore(0, for: player.id) }
            Button("Confirm") { game.setScore(Int(newScore), for: player.id) }
            TextField("Score", text: $newScore)
                .keyboardType(.numberPad)
                .focused($scoreFieldIsFocused)
        } message: {
            Text("Enter score for \(player.name)")
        }
        .alert("Rename Player", isPresented: $showingRename) {
            Button("Cancel", role: .cancel) {}
            Button("Confirm") { game.rename(id: player.id, to: newName) }
            TextField("Player name", text: $newName).keyboardType(.asciiCapable)
        }
    }

    private func showAddScore() {
        newScore = points.map(String.init) ?? ""
        showingAddScore = true
        scoreFieldIsFocused = true
    }

    private func showRename() {
        newName = player.name
        showingRename = true
    }
}
```

In `FiveCrowns/Views/LeaderboardView.swift`, replace `game.leaderboardPlayers()` with `game.leaderboard` and the hardcoded colours with `Theme` equivalents.

**`ScorecardHeaders.swift` must also be updated.** Its `#Preview` constructs `ScorecardRow(player:round:scoreChanged:playerDeleted:editMode:)`, which no longer exists — the file will not compile until the preview is rewritten. Replace both previews in `Views/Components/ScorecardHeaders.swift` and `Views/ScorecardRow.swift` with the new signature, which also clears the 8 leftover `puts(...)` debug calls those previews pass as closures:

```swift
#Preview {
    @Previewable @State var game = Game(store: GameStore(
        fileURL: FileManager.default.temporaryDirectory.appendingPathComponent("preview.data")))
    VStack(spacing: 0) {
        ScorecardHeaders()
        ScorecardRow(player: Player(name: "Ada"), editMode: true)
        Divider()
        ScorecardRow(player: Player(name: "Grace"), editMode: true)
    }
    .environment(game)
}
```

After this task, `grep -rn --include="*.swift" "puts(" FiveCrowns/` must return **no output**.

- [ ] **Step 6: Run the full unit suite**

```bash
xcodebuild test -project FiveCrowns.xcodeproj -scheme FiveCrowns \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:FiveCrownsTests -quiet 2>&1 | tail -30
```

Expected: all tests pass across PlayerTests, RankingTests, RoundTests, GameSnapshotTests, GameStoreTests, GameTests, LegacyFixtureTests.

- [ ] **Step 7: Manually verify round persistence — the data-loss fix**

```bash
xcrun simctl boot "iPhone 17 Pro" 2>/dev/null || true
open -a Simulator
xcodebuild -project FiveCrowns.xcodeproj -scheme FiveCrowns \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -quiet build
xcrun simctl install booted "$(xcodebuild -project FiveCrowns.xcodeproj -scheme FiveCrowns \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -showBuildSettings 2>/dev/null \
  | awk -F' = ' '/ BUILT_PRODUCTS_DIR/{d=$2} / FULL_PRODUCT_NAME/{n=$2} END{print d"/"n}')"
xcrun simctl launch booted com.challengr.FiveCrowns
```

In the simulator: add two players, enter scores, advance to round 4, background the app with Cmd+Shift+H, then relaunch. **Expected: the app reopens on round 4 with scores intact.** Before this change it reopened on round 1.

- [ ] **Step 8: Commit Tasks 10 and 13 together**

```bash
git add -A
git commit -m "refactor: extract game rules into Game, adopt the persistence layer

Player:
- drops the [Int: Int?] double optional, the unused order field, and the
  stored totalPoints (now computed, so it cannot drift out of sync)
- no longer Codable; persistence goes through GameSnapshot

Game:
- owns the round number, navigation, completion and game-over rules
- round acknowledgement stops the completion alert re-firing on every edit
- Ranking becomes a pure function on a struct; dense semantics preserved
- autosaves through GameStore instead of only saving on background

Views become layout and wiring only; ScorecardRow reads Game from the
environment rather than taking callbacks.

Fixes the round number not surviving relaunch - the app previously
reopened on round 1 with scores intact.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

# Phase 4 — Swift 6 (abandonable)

## Task 14: Enable Swift 6 language mode

If this task produces more than roughly a dozen diagnostics or requires design changes to the model, **stop and report** rather than forcing it. Falling back to Swift 5 with strict concurrency as warnings is an acceptable outcome and disturbs nothing else.

**Files:**
- Modify: `FiveCrowns.xcodeproj/project.pbxproj`

- [ ] **Step 1: Survey the damage before committing to it**

```bash
xcodebuild -project FiveCrowns.xcodeproj -scheme FiveCrowns \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  SWIFT_VERSION=6.0 clean build 2>&1 | grep -E "error:" | sort -u
```

Record the count. If it is zero, go to Step 3.

- [ ] **Step 2: Resolve diagnostics**

Expected shapes and their fixes:
- *"Main actor-isolated property cannot be referenced from a nonisolated context"* in `#Preview` blocks — annotate the preview body `@MainActor`.
- *"Type 'Player' does not conform to 'Sendable'"* crossing into `GameStore` — it should not be crossing; only `GameSnapshot` goes to the store. If `Player` appears in a store signature, that is a real design error to fix.
- *"Capture of 'self' with non-Sendable type"* in `Game.autosave()` — the `Task` captures the already-built `snapshot` value, not `self`; ensure it reads `Task { [store] in await store.scheduleSave(snapshot) }`.

- [ ] **Step 3: Set the build setting**

In `project.pbxproj`, change `SWIFT_VERSION = 5.0;` to `SWIFT_VERSION = 6.0;` in **both** `XCBuildConfiguration` blocks that contain it (Debug and Release).

- [ ] **Step 4: Verify a clean build and full tests**

```bash
xcodebuild -project FiveCrowns.xcodeproj -scheme FiveCrowns \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' clean build 2>&1 | grep -c "warning:"
xcodebuild test -project FiveCrowns.xcodeproj -scheme FiveCrowns \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -quiet 2>&1 | tail -20
```

Expected: warning count 0 (or only the `@Previewable` ones, which Task 19 clears); all tests pass.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "build: adopt Swift 6 language mode

Game and Player are @MainActor; GameStore is an actor with Sendable
snapshots crossing the boundary. The compiler now verifies the isolation
the previous Task {} wrappers only implied.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

# Phase 5 — Theme and dark mode

## Task 15: Author the dark palette

All six custom colorsets currently carry a dark variant of pure white — Xcode placeholders never filled in. In dark mode the header row renders white text on white.

**Files:**
- Modify: `FiveCrowns/Assets.xcassets/{Background,BackgroundMiddle,BackgroundDark,RowColour,HeaderRowBackground,ButtonColour}.colorset/Contents.json`
- Create: `FiveCrowns/Assets.xcassets/{PrimaryText,SecondaryText,OnHeader}.colorset/Contents.json`

- [ ] **Step 1: Update the six existing colorsets**

For each, replace the dark-appearance `components` block with these values. Keep the light values untouched.

| Colorset | Dark red | Dark green | Dark blue |
|---|---|---|---|
| `Background` | `0x1C` | `0x26` | `0x20` |
| `BackgroundMiddle` | `0x1F` | `0x2A` | `0x26` |
| `BackgroundDark` | `0x22` | `0x30` | `0x2B` |
| `RowColour` | `0x23` | `0x32` | `0x3A` |
| `HeaderRowBackground` | `0x0D` | `0x3A` | `0x52` |
| `ButtonColour` | `0xE0` | `0x95` | `0x1A` |

Each dark entry has this shape:

```json
{
  "appearances" : [ { "appearance" : "luminosity", "value" : "dark" } ],
  "color" : {
    "color-space" : "srgb",
    "components" : { "alpha" : "1.000", "red" : "0x1C", "green" : "0x26", "blue" : "0x20" }
  },
  "idiom" : "universal"
}
```

- [ ] **Step 2: Create the three text colorsets**

`PrimaryText`: light `0x00/0x00/0x00` at alpha `0.700`, dark `0xFF/0xFF/0xFF` at alpha `0.900`.
`SecondaryText`: light `0x00/0x00/0x00` at alpha `0.550`, dark `0xFF/0xFF/0xFF` at alpha `0.700`.
`OnHeader`: light `0xFF/0xFF/0xFF` at alpha `0.900`, dark `0xFF/0xFF/0xFF` at alpha `0.920`.

- [ ] **Step 3: Verify contrast meets WCAG AA**

```bash
python3 - <<'PY'
def lin(c):
    c = c/255
    return c/12.92 if c <= 0.03928 else ((c+0.055)/1.055)**2.4
def lum(rgb): 
    r,g,b = (lin(v) for v in rgb)
    return 0.2126*r + 0.7152*g + 0.0722*b
def blend(fg, bg, a):
    return tuple(fg[i]*a + bg[i]*(1-a) for i in range(3))
def ratio(fg, bg):
    l1, l2 = sorted((lum(fg), lum(bg)), reverse=True)
    return (l1+0.05)/(l2+0.05)

pairs = [
  ("light row text",    (0,0,0),       0.70, (0xB2,0xDA,0xF1)),
  ("dark row text",     (255,255,255), 0.90, (0x23,0x32,0x3A)),
  ("light header text", (255,255,255), 0.90, (0x06,0x4F,0x7A)),
  ("dark header text",  (255,255,255), 0.92, (0x0D,0x3A,0x52)),
]
ok = True
for name, fg, alpha, bg in pairs:
    r = ratio(blend(fg, bg, alpha), bg)
    status = "PASS" if r >= 4.5 else "FAIL"
    if r < 4.5: ok = False
    print(f"{status}  {name}: {r:.2f}:1")
print("ALL PASS" if ok else "CONTRAST FAILURE - adjust the palette")
PY
```

Expected: `ALL PASS`. If any pair fails, darken the surface or raise the text alpha until it clears 4.5:1, and update the table above to match.

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "fix: author real dark variants for every colorset

All six custom colours had dark variants of pure white - Xcode placeholders
never filled in - so the header row rendered white-on-white. Adds a card-table
dark palette plus PrimaryText/SecondaryText/OnHeader for adaptive text.
All text/surface pairs verified at WCAG AA 4.5:1.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

## Task 16: Introduce `Theme` and remove hardcoded colours

**Files:**
- Create: `FiveCrowns/Support/Theme.swift`
- Modify: all files under `FiveCrowns/Views/`, `FiveCrowns/App/FiveCrownsApp.swift`

- [ ] **Step 1: Create `Theme`**

```swift
import SwiftUI

/// Semantic colours over the asset catalog. Xcode generates a symbol per
/// colorset, so these are checked at compile time rather than by string.
enum Theme {
    static let background = Color(.background)
    static let backgroundMiddle = Color(.backgroundMiddle)
    static let backgroundDark = Color(.backgroundDark)
    static let row = Color(.rowColour)
    static let headerRow = Color(.headerRowBackground)
    static let button = Color(.buttonColour)

    static let primaryText = Color(.primaryText)
    static let secondaryText = Color(.secondaryText)
    static let onHeader = Color(.onHeader)

    static let backgroundGradient = Gradient(colors: [backgroundDark, backgroundMiddle, background])
}
```

- [ ] **Step 2: Replace every stringly-typed colour and hardcoded text colour**

**Also settle the accent colour.** Task 13 introduced `Color.accentColor` in `ScorecardRow`'s score cell where the old code used a literal `.blue`. The `AccentColor` colorset in the asset catalog is **empty** (no colour defined), so it currently falls through to the system default. Give it explicit light and dark values as part of this task, or replace those two uses with a `Theme` colour — either is fine, but do not leave an empty colorset driving visible UI.

- `Color("ButtonColour", bundle: .main).opacity(0.8)` → `Theme.button`
- `Color("RowColour", bundle: .main).opacity(0.8)` → `Theme.row`
- `Color("HeaderRowBackground", bundle: .main).opacity(0.8)` → `Theme.headerRow`
- `.foregroundStyle(.black.opacity(0.7))` → `.foregroundStyle(Theme.primaryText)`
- `.foregroundStyle(.white.opacity(0.9))` → `.foregroundStyle(Theme.onHeader)`

The `.opacity(0.8)` calls are dropped — opacity now lives in the colorset alpha, so the same colour is not being dimmed twice.

- [ ] **Step 3: Verify nothing stringly-typed remains**

```bash
grep -rn --include="*.swift" -E 'Color\("|\.black\.opacity|\.white\.opacity' FiveCrowns/
```

Expected: **no output.**

- [ ] **Step 4: Verify both appearances render**

```bash
xcodebuild test -project FiveCrowns.xcodeproj -scheme FiveCrowns \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -quiet 2>&1 | tail -15
xcrun simctl ui booted appearance dark
xcrun simctl launch booted com.challengr.FiveCrowns
```

Add two players and confirm by eye that the **Player / Score / Total header text is legible**. Then:

```bash
xcrun simctl ui booted appearance light
```

Confirm the light theme is unchanged from before this phase.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "refactor: route all colours through Theme

Replaces Color(\"Name\", bundle: .main) string lookups with generated asset
symbols, and the hardcoded .black/.white text colours with adaptive ones.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

# Phase 6 — Layout

## Task 17: Fix the view hierarchy and constrain width

**Files:**
- Modify: `FiveCrowns/Views/ScorecardView.swift`
- Create: `FiveCrowns/Views/Components/RoundHeader.swift`

- [ ] **Step 1: Extract the round header**

`FiveCrowns/Views/Components/RoundHeader.swift`:

```swift
import SwiftUI

struct RoundHeader: View {
    let round: Round

    var body: some View {
        HStack(spacing: 0) {
            logo
            Spacer()
            Text("\(round.cardCount) Card Round")
                .foregroundStyle(Theme.primaryText)
                .fontWeight(.bold)
                .font(.title2)
                .padding()
            Spacer()
            logo
        }
        .padding(.vertical)
        .frame(maxWidth: .infinity)
    }

    private var logo: some View {
        Image(.scorecardLogo)
            .resizable()
            .frame(width: 66, height: 66)
            .padding(.horizontal, 8)
            .accessibilityHidden(true)
    }
}
```

- [ ] **Step 2: Cap the content width and own the background**

Task 13 already replaced the loose sibling views with a `VStack`. What remains is constraining the width so content does not stretch on iPad, and moving the gradient off the app entry point so it can extend under the safe areas.

Add to the `VStack` in `ScorecardView.body`, immediately after the closing brace and before `.popover`:

```swift
        .frame(maxWidth: 560)
        .frame(maxWidth: .infinity)
        .background(Theme.backgroundGradient.opacity(0.8).ignoresSafeArea())
```

The doubled `frame` is deliberate: the first caps content width at 560pt, the second centres that block in the available space.

Then delete the now-duplicated `.background(...)` modifier from `FiveCrowns/App/FiveCrownsApp.swift`, leaving:

```swift
WindowGroup {
    ScorecardView()
        .environment(game)
        .task { await game.loadFromDisk() }
}
```

- [ ] **Step 3: Verify on iPad**

```bash
xcodebuild -project FiveCrowns.xcodeproj -scheme FiveCrowns \
  -destination 'platform=iOS Simulator,name=iPad Pro 11-inch (M5)' -quiet build
xcrun simctl boot "iPad Pro 11-inch (M5)" 2>/dev/null || true
```

Install and launch on the iPad simulator. **Expected:** content is a centred column, not stretched edge to edge with the score columns marooned at the right.

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "fix: wrap view hierarchy in an explicit container and cap content width

ScorecardView emitted five loose sibling views and relied on undefined
TupleView root layout. Content is now capped at 560pt and centred, so it
no longer stretches across an iPad.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

## Task 18: Landscape and compact-height layout

**Files:**
- Modify: `FiveCrowns/Views/ScorecardView.swift`

- [ ] **Step 1: Adapt to vertical size class**

In landscape on iPhone the vertical size class is `.compact`; a pinned bottom bar plus a `Spacer()` leaves the controls off-screen. Read the size class and move navigation inline:

```swift
@Environment(\.verticalSizeClass) private var verticalSizeClass

private var isCompactHeight: Bool { verticalSizeClass == .compact }

var body: some View {
    VStack(spacing: 0) {
        if isCompactHeight {
            HStack {
                previousButton
                RoundHeader(round: game.round)
                nextButton
            }
        } else {
            RoundHeader(round: game.round)
        }

        scorecard

        if !isCompactHeight {
            Spacer(minLength: 0)
            roundNavigation
        }
        if game.round > .one { leaderboardButton }
    }
    // ... modifiers unchanged
}
```

- [ ] **Step 2: Verify across the device matrix**

For each of `iPhone 17e`, `iPhone 17 Pro`, `iPad Pro 11-inch (M5)`:

```bash
xcodebuild -project FiveCrowns.xcodeproj -scheme FiveCrowns \
  -destination "platform=iOS Simulator,name=<DEVICE>" -quiet build
```

Launch each, add three players, and check in **both orientations** and **both appearances**:
- All round controls reachable without scrolling the chrome
- Score and Total columns not clipped
- Header text legible

Rotate with Cmd+Left Arrow in the simulator.

- [ ] **Step 3: Verify Dynamic Type at XL**

```bash
xcrun simctl ui booted content_size extra-extra-large
```

Relaunch and confirm player names truncate gracefully rather than pushing the Score and Total columns off-screen. Reset with:

```bash
xcrun simctl ui booted content_size medium
```

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "feat: adapt layout for landscape and compact height

Round navigation moves inline with the header when vertical size class is
compact, so the controls stay reachable in iPhone landscape.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

# Phase 7 — Accessibility and project configuration

## Task 19: Accessibility

**Files:**
- Modify: `FiveCrowns/Views/ScorecardRow.swift`
- Create: `FiveCrowns/Views/Components/ScoreCell.swift`
- Modify: every file containing a `#Preview`

- [ ] **Step 1: Make tap targets real buttons**

The score cell and player name are `Text` with `.onTapGesture`, so VoiceOver announces static text with no hint they are interactive. Create `FiveCrowns/Views/Components/ScoreCell.swift`:

```swift
import SwiftUI

struct ScoreCell: View {
    let points: Int?
    let playerName: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(points.map(String.init) ?? "-")
                .foregroundStyle(Theme.primaryText)
                .fontWeight(.medium)
                .frame(minWidth: 44, minHeight: 44)
                .padding(8)
                .border(points == nil ? Color.gray : Color.accentColor)
                .background(points == 0 ? Color.accentColor.opacity(0.2) : Color.clear)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Score for \(playerName)")
        .accessibilityValue(points.map { "\($0) points" } ?? "No score entered")
        .accessibilityHint("Double tap to enter a score")
    }
}
```

- [ ] **Step 2: Label the delete button and the name button**

`Label("", systemImage: "trash")` reads as nothing to VoiceOver. Replace:

```swift
Button(action: { playerDeleted(player) }) {
    Image(systemName: "trash")
        .padding(.vertical, 8)
        .padding(.leading, 8)
}
.foregroundColor(.red)
.accessibilityLabel("Remove \(player.name)")
```

and the name:

```swift
Button(action: showUpdatePlayer) {
    Text(player.name)
        .foregroundStyle(Theme.primaryText)
        .fontWeight(.medium)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
}
.buttonStyle(.plain)
.accessibilityLabel("Player \(player.name)")
.accessibilityHint("Double tap to rename")
```

- [ ] **Step 3: Fix the seven `@Previewable` warnings**

Every `#Preview` using inline `@State` needs the annotation, otherwise the preview silently does not work:

```swift
#Preview {
    @Previewable @State var game = Game(store: GameStore(
        fileURL: FileManager.default.temporaryDirectory.appendingPathComponent("preview.data")))
    ScorecardView().environment(game)
}
```

- [ ] **Step 4: Verify zero warnings**

```bash
xcodebuild -project FiveCrowns.xcodeproj -scheme FiveCrowns \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' clean build 2>&1 | grep "warning:" | sort -u
```

Expected: **no output.**

- [ ] **Step 5: Wire up `saveFailed`, which is currently dead state**

`Game.saveFailed` was declared in Task 13 but nothing ever assigns it, and nothing reads it — dead state, which the acceptance criteria forbid. The spec promised a non-blocking banner on save failure, so wire it rather than delete it.

In `GameStore`, record the outcome of the last write:

```swift
    /// Whether the most recent write attempt failed. Read after `flush()`.
    private(set) var lastWriteFailed = false

    private func writePending() {
        guard let snapshot = pendingSnapshot else { return }
        pendingSnapshot = nil
        do {
            try save(snapshot)
            lastWriteFailed = false
        } catch {
            lastWriteFailed = true
            AppLog.persistence.error(
                "Save failed: \(error.localizedDescription, privacy: .public)")
        }
    }
```

In `Game`, pick it up at the moment it matters — when the app is being backgrounded:

```swift
    func flush() async {
        await store.flush()
        saveFailed = await store.lastWriteFailed
    }
```

`saveFailed` must lose its `private(set)`-only-internal status only if the view cannot read it; `private(set) var` is already readable from the view, so leave the declaration as is.

In `ScorecardView`, surface it without blocking anything:

```swift
            if game.saveFailed {
                Label("Couldn't save this game", systemImage: "exclamationmark.triangle.fill")
                    .font(.footnote)
                    .foregroundStyle(.white)
                    .padding(.vertical, 6)
                    .frame(maxWidth: .infinity)
                    .background(.red.opacity(0.85))
                    .accessibilityAddTraits(.isStaticText)
            }
```

Place it directly under `RoundHeader` in the `VStack`. Add a test that a store pointed at an unwritable location sets the flag after `flush()`.

- [ ] **Step 6: Replace the UI test boilerplate with a real smoke test**

Both UI test files contain only Xcode boilerplate — `testExample()` with an empty body and a launch performance measurement that adds ~24s to every run for no signal.

```bash
git rm -q FiveCrownsUITests/FiveCrownsUITests.swift
```

Replace the contents of `FiveCrownsUITests/FiveCrownsUITestsLaunchTests.swift`:

```swift
import XCTest

/// One smoke test: the app launches and presents a usable scorecard.
/// Deeper behaviour is covered by the unit suite, which runs in a fraction
/// of the time.
final class FiveCrownsUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testLaunchesToAUsableScorecard() throws {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(
            app.buttons["Add Player"].waitForExistence(timeout: 10),
            "Expected the Add Player button on a scorecard with no players"
        )
    }
}
```

Run it:

```bash
xcodebuild test -project FiveCrowns.xcodeproj -scheme FiveCrowns \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:FiveCrownsUITests -quiet 2>&1 | tail -15
```

Expected: 1 test passes. If the app has a save file from earlier manual testing, the button will not appear — reset first with `xcrun simctl uninstall booted com.challengr.FiveCrowns`.

- [ ] **Step 7: Verify with VoiceOver**

```bash
xcrun simctl spawn booted notifyutil -s com.apple.VoiceOver4/EnabledWhenApplicationsLaunch 1
```

Swipe through the scorecard and confirm each score cell announces "Score for <name>, N points" rather than a bare number. Disable afterwards by setting the flag to `0`.

- [ ] **Step 8: Commit**

```bash
git add -A
git commit -m "fix: make tap targets accessible and clear all build warnings

Score cells and player names become Buttons so VoiceOver identifies them
as interactive; the trash button gains a real label. Fixes the seven
@Previewable warnings, which meant those previews never worked.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

## Task 20: Project configuration for submission

**Files:**
- Modify: `FiveCrowns.xcodeproj/project.pbxproj`, `FiveCrowns/Info.plist`
- Create: `FiveCrowns/PrivacyInfo.xcprivacy`

- [ ] **Step 1: Align signing and bundle identifiers**

In `project.pbxproj`:
- Set `DEVELOPMENT_TEAM = 79242RQ384;` in **every** occurrence (the test targets currently use `K465DYH4Z2`, which will fail signing).
- Change `com.colharris.FiveCrownsTests` → `com.challengr.FiveCrownsTests` and `com.colharris.FiveCrownsUITests` → `com.challengr.FiveCrownsUITests`.
- Change `IPHONEOS_DEPLOYMENT_TARGET = 17.4;` → `17.0;` in both configurations. Nothing in use requires 17.4.

- [ ] **Step 2: Declare export compliance**

Add to `FiveCrowns/Info.plist` inside the top-level `<dict>`:

```xml
<key>ITSAppUsesNonExemptEncryption</key>
<false/>
```

- [ ] **Step 3: Add the privacy manifest**

`FiveCrowns/PrivacyInfo.xcprivacy`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>NSPrivacyTracking</key>
	<false/>
	<key>NSPrivacyTrackingDomains</key>
	<array/>
	<key>NSPrivacyCollectedDataTypes</key>
	<array/>
	<key>NSPrivacyAccessedAPITypes</key>
	<array/>
</dict>
</plist>
```

- [ ] **Step 4: Verify the settings took**

```bash
xcodebuild -project FiveCrowns.xcodeproj -scheme FiveCrowns \
  -showBuildSettings 2>/dev/null | grep -E "IPHONEOS_DEPLOYMENT_TARGET|DEVELOPMENT_TEAM|PRODUCT_BUNDLE_IDENTIFIER"
grep -c "K465DYH4Z2\|com.colharris" FiveCrowns.xcodeproj/project.pbxproj
```

Expected: deployment target `17.0`, team `79242RQ384`, and a count of `0` for the old values.

- [ ] **Step 5: Verify the archive builds**

```bash
xcodebuild -project FiveCrowns.xcodeproj -scheme FiveCrowns \
  -destination 'generic/platform=iOS' -archivePath /tmp/FiveCrowns.xcarchive \
  archive -quiet 2>&1 | tail -10
```

Expected: `ARCHIVE SUCCEEDED`. This is the closest proxy for "App Store Connect will accept it" available locally. If signing fails, report — it may need a device-side login rather than a code change.

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "build: align signing, add privacy manifest and export compliance

- DEVELOPMENT_TEAM was inconsistent between app and test targets
- Test bundle IDs move to com.challengr to match the app
- ITSAppUsesNonExemptEncryption avoids the export prompt on every submission
- Deployment target drops to 17.0; nothing in use requires 17.4

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

## Task 21: Final verification against acceptance criteria

**Files:** none — verification only.

- [ ] **Step 1: Run every check**

```bash
echo "=== no crash paths or console logging ==="
grep -rn --include="*.swift" -E "fatalError|puts\(" FiveCrowns/ || echo "CLEAN"

echo "=== no dead code ==="
grep -rn --include="*.swift" -E "AddPlayerView|UpdatePlayerView|UpdateScoreView|SubmitButtonStyle|wildcardFor" FiveCrowns/ || echo "CLEAN"

echo "=== no stringly-typed colours ==="
grep -rn --include="*.swift" -E 'Color\("|\.black\.opacity|\.white\.opacity' FiveCrowns/ || echo "CLEAN"

echo "=== ScorecardView size ==="
wc -l FiveCrowns/Views/ScorecardView.swift

echo "=== warnings ==="
xcodebuild -project FiveCrowns.xcodeproj -scheme FiveCrowns \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' clean build 2>&1 | grep -c "warning:"

echo "=== tests ==="
xcodebuild test -project FiveCrowns.xcodeproj -scheme FiveCrowns \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -quiet 2>&1 | tail -20
```

Expected: `CLEAN` for the first three, `ScorecardView.swift` under 120 lines, warning count `0`, all tests passing.

- [ ] **Step 2: Manual acceptance run**

On `iPhone 17 Pro`, in **dark mode**:
1. Launch with no save file → empty scorecard, Add Player visible.
2. Add three players, score round 1 → "Round Complete!" appears **once**.
3. Correct a score → **no** repeat announcement.
4. Advance to round 4, background, relaunch → **opens on round 4, scores intact**.
5. Corrupt the save file, relaunch:
   ```bash
   APP_DATA=$(xcrun simctl get_app_container booted com.challengr.FiveCrowns data)
   echo "garbage" > "$APP_DATA/Documents/game.data"
   xcrun simctl launch booted com.challengr.FiveCrowns
   ```
   → **launches empty, does not crash**, and `game.data.corrupt` exists alongside.
6. Advance to round 11 and score it → "Game Over!" with the winner named; Next is disabled.

- [ ] **Step 3: Update the PR**

```bash
gh pr ready  # take it out of draft only if all criteria pass
```

Tick every checkbox in the PR description that is now satisfied, and note anything deferred.

---

## Deferred / follow-up

- **Trademark.** "Five Crowns" is registered to Set Enterprises, Inc. Resolve before store artwork and listing copy. Not a code change.
- **Swift 6.** If Task 14 was abandoned, record why in the PR and leave `SWIFT_VERSION = 5.0` with `SWIFT_STRICT_CONCURRENCY = complete` as warnings.
- **Localization.** Out of scope by decision; the String Catalog migration is a clean follow-up when a second language is actually wanted.
