import SwiftUI

/// The column headers and the scrolling list of players. Owns the new-game
/// confirmation so `ScorecardView` does not have to.
struct ScorecardList: View {
    @Environment(Game.self) private var game

    @State private var showingNewGameConfirmation = false

    var body: some View {
        VStack(spacing: 0) {
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
                    if game.isGameOver { newGameButton }
                }
            }
            .frame(minHeight: 0)
        }
        .alert("Start New Game?", isPresented: $showingNewGameConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("OK") { game.startNewGame() }
        } message: {
            Text("Are you sure?")
        }
    }

    private var newGameButton: some View {
        Button { showingNewGameConfirmation = true } label: {
            Label("New Game", systemImage: "arrow.clockwise")
                .foregroundStyle(Theme.onButton)
        }
        .buttonStyle(.borderedProminent)
        .tint(Theme.button)
        .padding()
    }
}

#Preview {
    @Previewable @State var game = Game(store: GameStore(
        fileURL: FileManager.default.temporaryDirectory.appendingPathComponent("preview.data")))
    ScorecardList().environment(game)
}
