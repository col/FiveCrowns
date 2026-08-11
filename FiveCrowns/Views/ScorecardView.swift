import SwiftUI

struct ScorecardView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(Game.self) private var game

    @State private var showingLeaderboard = false
    @State private var showingRoundComplete = false
    @State private var showingGameOver = false
    @State private var showingNewGameConfirmation = false

    private let buttonTint = Theme.button

    var body: some View {
        VStack(spacing: 0) {
            RoundHeader(round: game.round)
            scorecard
            Spacer(minLength: 0)
            roundNavigation
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
        if game.players.isEmpty { AddPlayerButton() } else { ScorecardHeaders() }

        ScrollView {
            VStack(spacing: 0) {
                ForEach(game.players) { player in
                    ScorecardRow(player: player, editMode: game.round == .one)
                    Divider().overlay(Theme.headerRow)
                }
                if !game.players.isEmpty && game.round == .one {
                    AddPlayerButton().padding(.top, 16)
                }
                if game.isGameOver {
                    Button { showingNewGameConfirmation = true } label: {
                        Label("New Game", systemImage: "arrow.clockwise")
                            .foregroundStyle(Theme.onButton)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(buttonTint)
                    .padding()
                }
            }
        }
        .frame(minHeight: 0)
    }

    private var roundNavigation: some View {
        HStack {
            Button(action: game.retreat) {
                Label("Previous", systemImage: "arrow.backward")
                    .fontWeight(.semibold)
                    .foregroundStyle(Theme.onButton)
            }
            .disabled(!game.canRetreat)
            Spacer()
            Button(action: game.advance) {
                Label("Next", systemImage: "arrow.forward")
                    .fontWeight(.semibold)
                    .foregroundStyle(Theme.onButton)
            }
            .disabled(!game.canAdvance)
        }
        .labelStyle(.titleAndIcon)
        .buttonStyle(.borderedProminent)
        .tint(buttonTint)
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
