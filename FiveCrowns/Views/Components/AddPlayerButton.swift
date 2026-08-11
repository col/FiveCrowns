import SwiftUI

/// The "Add Player" button and the alert it presents. Owns its own entry state
/// so `ScorecardView` does not have to.
struct AddPlayerButton: View {
    @Environment(Game.self) private var game

    @State private var showingAddPlayer = false
    @State private var newPlayerName = ""
    @FocusState private var playerFieldIsFocused: Bool

    var body: some View {
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
        .alert("Add Player", isPresented: $showingAddPlayer) {
            Button("Cancel", role: .cancel) { newPlayerName = "" }
            Button("Confirm", action: addPlayer)
            TextField("Player name", text: $newPlayerName)
                .keyboardType(.asciiCapable)
                .focused($playerFieldIsFocused)
        }
    }

    private func addPlayer() {
        withAnimation { game.addPlayer(named: newPlayerName) }
        newPlayerName = ""
    }
}

#Preview {
    @Previewable @State var game = Game(store: GameStore(
        fileURL: FileManager.default.temporaryDirectory.appendingPathComponent("preview.data")))
    AddPlayerButton().environment(game)
}
