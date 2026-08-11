//
//  LeaderboardView.swift
//  FiveKings
//
//  Created by Colin Harris on 14/4/24.
//

import SwiftUI

struct LeaderboardView: View {
    @Environment(Game.self) var game: Game
    @Binding var showView: Bool
    
    var body: some View {
        Text("Leaderboard")
            .foregroundStyle(.black.opacity(0.7))
            .fontWeight(.bold)
            .font(.title)
            .padding()
        
        VStack {
            ForEach(game.leaderboard) { rankedPlayer in
                HStack {
                    Text("\(rankedPlayer.rank). ").padding(.trailing, 16)
                    Text(rankedPlayer.player.name)
                    Spacer()
                    Text("\(rankedPlayer.player.totalPoints)")
                }.padding()
                Divider()
            }
        }.padding()
        
        Button(action: { showView = false }) {
            Label("Close", systemImage: "xmark")
                .fontWeight(.semibold)
                .padding(.vertical, 4)
                .padding(.horizontal, 16)
        }
        .tint(Color("ButtonColour", bundle: .main).opacity(0.8))
        .buttonStyle(.borderedProminent)
        
        Spacer()
    }
}

#Preview {
    @Previewable @State var showView = true
    @Previewable @State var game = Game(store: GameStore(
        fileURL: FileManager.default.temporaryDirectory.appendingPathComponent("preview.data")))
    LeaderboardView(showView: $showView)
        .environment(game)
        .onAppear {
            game.apply(GameSnapshot(round: 1, players: [
                PlayerSnapshot(id: UUID(), name: "Ada", scores: [1: 3]),
                PlayerSnapshot(id: UUID(), name: "Grace", scores: [1: 20]),
                PlayerSnapshot(id: UUID(), name: "Sam", scores: [1: 0]),
            ]))
        }
}
