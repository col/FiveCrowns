# Five Crowns — App Store Polish Pass

**Date:** 2026-08-11
**Status:** Approved
**Branch:** `polish/app-store-readiness`

## Context

FiveCrowns is a SwiftUI scorekeeping app for the card game Five Crowns, built in April 2024 for family use. The goal is to publish it to the App Store. This spec covers a quality pass over the existing code: fixing defects a stranger would hit, restructuring the codebase into clear layers, and closing the gap between what the project *declares* and what it *delivers*.

The app works. Its owner reports no complaints from real use. This is therefore a code-quality exercise, not a product exercise.

## Goals

1. Remove every crash path and data-loss path.
2. Restructure into layers with single responsibilities.
3. Make dark mode work.
4. Make iPad and landscape work, as the build settings already claim.
5. Establish real test coverage over the game rules and persistence.
6. Reach App Store submission readiness.

## Non-goals

Explicitly out of scope, and not to be added opportunistically:

- Game history / past-game storage
- Saved player rosters
- Displaying the round's wild card (`Round.wildcardFor` exists but is unused)
- Haptics
- Localization / String Catalog
- SwiftData migration
- Any change to the score-entry interaction model (alerts stay alerts)

Rationale: the owner's stated goal is cleaning up code, and no user has asked for features. Each of the above is a product bet that should follow real usage data, not precede it.

## Decisions

| Decision | Choice | Rationale |
|---|---|---|
| Release ambition | Small product | Comfortable receiving reviews and bug reports from strangers |
| Dark mode | Author a real dark theme | Card games get played in dim rooms |
| Restructure depth | Layered folders + Swift 6 | The persistence DTO is needed regardless; layering is then nearly free |
| iPad / landscape | Support properly | Build settings already promise it |
| Ranking semantics | Keep dense ranking | Current behaviour, nobody has complained; document and test rather than change |
| Score entry UI | Keep alerts | No complaints; redesigning it would be feature work |
| Delivery | One branch, staged commits | Each phase independently green and independently abandonable |

---

## Current state

Verified by reading all 16 Swift files, building against Xcode 26.4.1, and round-tripping the persistence layer.

```
FiveCrowns/
  FiveCrownsApp.swift        entry point; two fatalError calls on save/load failure
  ScorecardView.swift        256 lines: round state + 5 alerts + player CRUD + rules + layout
  ScorecardRow.swift         142 lines: score alert, rename alert
  ScorecardHeaders.swift
  LeaderboardView.swift
  AddPlayerView.swift        dead — referenced only by its own #Preview
  UpdatePlayerView.swift     dead
  UpdateScoreView.swift      dead
  Styles.swift               dead — both button styles used only by the dead views
  Models/
    Game.swift               player list and file I/O in one class
    Player.swift             @Observable + Codable; leaks macro storage into JSON
    Round.swift              class of statics, never called
    RankedPlayer.swift
```

Build is clean apart from 8 warnings: 7 missing `@Previewable`, and one from the `@Observable` macro expansion on `Player` reporting that an immutable property will not be decoded.

### The persistence problem

`@Observable` rewrites stored properties into underscore-prefixed backing storage *before* `Codable` synthesis runs. The saved file is therefore:

```json
[{"_order":1,"_scores":{"1":7,"2":null},"_totalPoints":7,
  "_name":"Ada","_$observationRegistrar":{},"_id":"1138C844-..."}]
```

This round-trips correctly today but the schema is an undocumented implementation detail of a compiler macro. It is also the source of the build warning. A dedicated DTO is the fix.

---

## Architecture

```
FiveCrowns/
  App/
    FiveCrownsApp.swift        @main; injects GameStore + Game; root chrome
  Model/
    Game.swift                 @MainActor @Observable — players, round, rules
    Player.swift               @Observable — identity, name, scores
    Round.swift                enum Round: Int, CaseIterable (1...11)
    Ranking.swift              struct RankedPlayer + pure ranking function
  Persistence/
    GameSnapshot.swift         versioned Codable DTO
    GameStore.swift            actor — load/save, atomic write, v1 migration
  Views/
    ScorecardView.swift        layout and wiring only
    ScorecardRow.swift
    LeaderboardView.swift
    Components/
      ScoreCell.swift
      RoundHeader.swift
      ScorecardHeaders.swift
  Support/
    Theme.swift                semantic colours over generated asset symbols
```

### Model layer

`Game` owns the rules. Round number moves out of the view and into the model, where it is persisted — this fixes the reopen-at-round-1 data loss.

```swift
@MainActor @Observable
final class Game {
    private(set) var players: [Player]
    private(set) var round: Round
    private var acknowledgedRounds: Set<Round>

    var isRoundComplete: Bool
    var isGameOver: Bool
    var canAdvance: Bool
    var canRetreat: Bool
    var leaderboard: [RankedPlayer]

    func addPlayer(named: String)
    func removePlayer(id: Player.ID)
    func setScore(for: Player.ID, points: Int?)   // nil clears the entry
    func advance()
    func retreat()
    func acknowledgeRound(_ round: Round)
    func startNewGame()
}
```

`acknowledgedRounds` makes the completion alert fire once per round rather than on every subsequent edit.

Model cleanups:

- `Player.scores` becomes `[Int: Int]`. The current `[Int: Int?]` double optional distinguishes nothing — "cleared" and "never entered" both read as absent.
- `Player.totalPoints` becomes computed. It is currently both stored and derived, which is a desync bug waiting to happen.
- `Player.order` is removed. Written at init, never read, and goes stale on delete (removing player 1 of 3 leaves orders 2,3; the next add reuses 3).
- `Player.setName` is removed; `name` is a plain `var`.
- `Round` becomes `enum Round: Int, CaseIterable` with `cardCount` and `wildcard` properties, retiring the magic `11` and `round + 2` scattered through the view.
- `RankedPlayer` becomes a struct; ranking becomes a pure function.
- `Game.removePlayer` matches on `id`, not name. The current name match deletes every player sharing a name.
- `Game.addPlayer` trims whitespace and rejects empty names. Duplicate names remain allowed.

### Persistence layer

```swift
struct GameSnapshot: Codable, Sendable {
    var schemaVersion: Int = 2
    var round: Int                 // Round.rawValue; clamped to 1...11 on load
    var players: [PlayerSnapshot]
}

struct PlayerSnapshot: Codable, Sendable {
    var id: UUID
    var name: String
    var scores: [Int: Int]     // totalPoints is derived, never persisted
}

actor GameStore {
    func load() -> GameSnapshot?
    func save(_ snapshot: GameSnapshot) throws
    func scheduleSave(_ snapshot: GameSnapshot)   // debounced ~0.5s, coalescing
    func flush() async
}
```

**Migration.** `load()` attempts v2, then falls back to decoding the legacy array-of-players shape using explicit `_`-prefixed `CodingKeys`, and maps it into a `GameSnapshot`. Legacy files carry no round, so they open at round 1 — which is what happens today regardless.

**Corruption.** A file that decodes as neither format is moved aside to `game.data.corrupt-<n>` and `load()` returns `nil`. The app opens empty rather than crash-looping. This replaces the current behaviour, where a corrupt file bricks the install permanently via `fatalError`.

**Writes** use `Data.write(to:options:.atomic)`.

**Cadence.** Saves are debounced ~0.5s after each mutation and coalesced, with a flush on scene-phase change. Currently the app saves only on `scenePhase == .inactive`, so a crash or force-quit loses the session.

### Error handling

No `fatalError` anywhere. Both call sites in `FiveCrownsApp.swift` are removed.

- Load failure → start empty, log at `.error`.
- Save failure → log at `.error`, set a `saveFailed` flag on `Game`, surface a non-blocking banner in `ScorecardView`.

All three `puts` calls are replaced with `os.Logger`. The call at `Game.swift:52` currently prints the entire save file to the console and is deleted outright.

### View layer

`ScorecardView` keeps layout and wiring only, targeting under 120 lines. Its body is wrapped in an explicit `VStack` — it currently emits five loose sibling views and relies on undefined `TupleView` root layout.

Defect fixes carried in the view layer:

- `.frame(width: .infinity)` at lines 40 and 47 becomes `.frame(maxWidth: .infinity)`. `width:` takes a fixed dimension; `.infinity` produces a runtime "invalid frame dimension" log.
- `.scrollDisabled(round < 6)` is deleted. It gates scrolling on round number rather than content size, which puts the Add Player button out of reach with six or more players.
- The Next button gains `.disabled(round == 11)`. It currently stays enabled and silently does nothing.
- The score-entry alert gains a Cancel button. Alerts cannot be dismissed by tapping outside, so a mis-tap currently forces the user to write a value.
- `Label("   Next   ", ...)` loses its whitespace padding and stacked empty-icon hack.
- The gradient background gains `.ignoresSafeArea()`.

The three dead views and `Styles.swift` are deleted. With alerts confirmed as the retained interaction, they have no path back.

### Theme

Six colorsets currently have dark variants of pure white — Xcode placeholders never filled in. In dark mode the header row renders white text on white background.

New dark palette ("card table at night"):

| Role | Light | Dark |
|---|---|---|
| Background | `#E6D4C0` | `#1C2620` |
| Background middle | `#E2C9B3` | `#1F2A26` |
| Background dark | `#DBB99E` | `#22302B` |
| Row fill | `#B2DAF1` | `#23323A` |
| Header row | `#064F7A` | `#0D3A52` |
| Button | `#FBA11C` | `#E0951A` |

Three new adaptive colorsets — `PrimaryText`, `SecondaryText`, `OnHeader` — replace every hardcoded `.black.opacity(0.7)` and `.white.opacity(0.9)`.

`Theme.swift` wraps Xcode's generated asset symbols so `Color("ButtonColour", bundle: .main)` becomes `Theme.button`, making typos compile errors.

Every text-on-surface pair must clear WCAG AA contrast (4.5:1) in both appearances. This is a verification step, not a suggestion.

### iPad and landscape

- Content sits in a readable-width container (~560pt), centred, so it stops stretching across a 10-inch display with 44pt score columns marooned at the right edge.
- Compact-height layouts (iPhone landscape) move round controls inline with the header rather than below a `Spacer()`.
- Scrolling is always enabled.

Verification matrix: iPhone SE, iPhone 17 Pro, iPad 11" — each in portrait and landscape, light and dark, at Dynamic Type XL.

### Concurrency

`Game` and `Player` are `@MainActor`. `GameStore` is an `actor`, moving file I/O off the main thread — the current `Task { }` wrappers inherit the caller's actor and do not. `GameSnapshot` and `PlayerSnapshot` are `Sendable`.

`SWIFT_VERSION` moves to 6.0 so the compiler verifies this.

---

## Testing

Swift Testing (`@Test` / `#expect`), not XCTest. Both existing test files contain only unmodified Xcode boilerplate.

| Area | Cases |
|---|---|
| Ranking | Ties, all-equal, empty, single player, dense-rank semantics |
| Scoring | Set, clear, total recomputation, reset |
| `Round` | `cardCount` and `wildcard` across all 11 rounds; boundary behaviour |
| Game rules | Advance/retreat bounds, `isRoundComplete`, `isGameOver`, `startNewGame`, acknowledgement |
| Persistence | v2 round-trip; **v1 legacy fixture decodes**; corrupt file quarantined; atomic write |

The v1 fixture must be captured from a genuine current-format save file, not hand-authored, so the migration is tested against reality.

UI test boilerplate is replaced with a single launch smoke test.

---

## Project configuration

| Item | Current | Target |
|---|---|---|
| `DEVELOPMENT_TEAM` | App `79242RQ384`, tests `K465DYH4Z2` | Aligned across all three targets |
| Test bundle IDs | `com.colharris.*` | `com.challengr.*` |
| `ITSAppUsesNonExemptEncryption` | absent | `false` |
| Privacy manifest | absent | Minimal `PrivacyInfo.xcprivacy`, no tracking, no collection |
| `IPHONEOS_DEPLOYMENT_TARGET` | 17.4 | 17.0 — nothing in use requires 17.4 |
| `SWIFT_VERSION` | 5.0 | 6.0 |
| `@Previewable` warnings | 7 | 0 |
| `TARGETED_DEVICE_FAMILY` | `1,2` | unchanged, now honest |

---

## Delivery plan

One branch, staged commits. Each phase builds green and passes tests before the next begins.

| # | Phase | Abandonable |
|---|---|---|
| 1 | Characterisation tests over current behaviour | No — safety net |
| 2 | Defect fixes: crash paths, frames, Cancel, alert nagging, Next disabled, scroll | No |
| 3 | Model + persistence restructure: DTO, migration, computed total | No |
| 4 | Swift 6 language mode + actor isolation | **Yes** |
| 5 | Theme + dark palette | No |
| 6 | iPad + landscape layout | No |
| 7 | Accessibility + project configuration | No |

Phase 1 runs first so that phases 2–7 have a regression net. Phase 4 is positioned so it can be dropped — falling back to Swift 5 with `SWIFT_STRICT_CONCURRENCY=complete` as warnings — without disturbing any other phase.

### Accessibility (phase 7)

- The score cell and player name become `Button`s with `.buttonStyle(.plain)`. They are currently `Text` with `.onTapGesture`, so VoiceOver announces them as static text with no indication they are interactive.
- `Label("", systemImage: "trash")` gains a real accessibility label; the empty title currently reads as nothing.
- Dynamic Type verified at XL; fixed `minWidth: 44` columns must not clip.

---

## Risks

**Swift 6 concurrency may expand beyond estimate.** `@MainActor` on the model and an `actor` store is the correct shape and should be quiet, but strict concurrency surfaces surprises. Mitigated by position in the sequence: phase 4 is droppable in isolation.

**Migration could lose real save data.** Mitigated by building the v1 fixture from a genuine file produced by the current build, and by writing the migration test before the migration code.

**Dark palette may fail contrast.** Mitigated by explicit WCAG AA verification as an acceptance criterion rather than a review note.

## Open item — not blocking

"Five Crowns" is a registered trademark of Set Enterprises, Inc. Publishing under that exact name carries takedown risk. This affects store listing and artwork, not any code in this spec, but it is cheaper to resolve before submission than after.

## Acceptance criteria

- [ ] No `fatalError`, no `puts`, in shipping code
- [ ] Corrupt save file does not prevent launch
- [ ] Round number survives app relaunch
- [ ] Legacy v1 save file loads with scores intact
- [ ] Zero build warnings
- [ ] All tests pass
- [ ] Header text legible in dark mode; all text/surface pairs clear WCAG AA
- [ ] Layout correct on iPhone SE, iPhone 17 Pro, iPad 11", portrait and landscape
- [ ] `ScorecardView` under 120 lines
- [ ] No dead code
