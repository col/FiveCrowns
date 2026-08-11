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
                .accessibilityLabel("Remove \(player.name)")
            }

            Button(action: showRename) {
                Text(player.name)
                    .foregroundStyle(Theme.primaryText)
                    .fontWeight(.medium)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Player \(player.name)")
            .accessibilityHint("Double tap to rename")

            ScoreCell(points: points, playerName: player.name, action: showAddScore)

            Text("\(player.totalPoints)")
                .foregroundStyle(Theme.primaryText)
                .fontWeight(.semibold)
                .frame(minWidth: 44)
                .padding(8)
                .accessibilityLabel("Total for \(player.name)")
                .accessibilityValue("\(player.totalPoints) points")
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
