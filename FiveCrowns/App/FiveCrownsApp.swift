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
