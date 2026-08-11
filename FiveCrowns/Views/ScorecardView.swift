import SwiftUI

struct ScorecardView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(Game.self) private var game

    @State private var showingLeaderboard = false
    @State private var showingRoundComplete = false
    @State private var showingGameOver = false

    private let buttonTint = Theme.button

    /// Landscape on iPhone. There is no room for a navigation row of its own,
    /// so the round controls move up beside the header.
    private var isCompactHeight: Bool { verticalSizeClass == .compact }

    var body: some View {
        VStack(spacing: 0) {
            if isCompactHeight {
                HStack(spacing: 8) {
                    previousButton
                    RoundHeader(round: game.round)
                    nextButton
                }
                .padding(.horizontal)
            } else {
                RoundHeader(round: game.round)
            }
            if game.saveFailed { SaveFailedBanner() }
            ScorecardList()
            if !isCompactHeight {
                Spacer(minLength: 0)
                roundNavigation
            }
            if game.round > .one { leaderboardButton }
        }
        .frame(maxWidth: 560)
        .frame(maxWidth: .infinity)
        .background(Theme.backgroundGradient.opacity(0.8), ignoresSafeAreaEdges: .all)
        .popover(isPresented: $showingLeaderboard) {
            LeaderboardView(showView: $showingLeaderboard)
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
        .onChange(of: game.needsRoundCompleteAnnouncement) { _, needsAnnouncement in
            guard needsAnnouncement else { return }
            if game.isGameOver { showingGameOver = true } else { showingRoundComplete = true }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase != .active { Task { await game.flush() } }
        }
    }

    private var previousButton: some View {
        Button(action: game.retreat) {
            Label("Previous", systemImage: "arrow.backward")
                .fontWeight(.semibold)
                .foregroundStyle(Theme.onButton)
        }
        .disabled(!game.canRetreat)
        .labelStyle(.titleAndIcon)
        .buttonStyle(.borderedProminent)
        .tint(buttonTint)
    }

    private var nextButton: some View {
        Button(action: game.advance) {
            Label("Next", systemImage: "arrow.forward")
                .fontWeight(.semibold)
                .foregroundStyle(Theme.onButton)
        }
        .disabled(!game.canAdvance)
        .labelStyle(.titleAndIcon)
        .buttonStyle(.borderedProminent)
        .tint(buttonTint)
    }

    private var roundNavigation: some View {
        HStack {
            previousButton
            Spacer()
            nextButton
        }
        .padding()
    }

    private var leaderboardButton: some View {
        Button { showingLeaderboard = true } label: {
            Label("Leaderboard", systemImage: "list.star")
                .fontWeight(.semibold)
                .foregroundStyle(Theme.onButton)
                .padding(.vertical, 8)
                .padding(.horizontal, 16)
        }
        .buttonStyle(.borderedProminent)
        .tint(buttonTint)
        .padding(8)
    }
}

#Preview {
    @Previewable @State var game = Game(store: GameStore(
        fileURL: FileManager.default.temporaryDirectory.appendingPathComponent("preview.data")))
    ScorecardView().environment(game)
}
