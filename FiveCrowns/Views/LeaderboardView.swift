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
            ForEach(game.leaderboardPlayers()) { rankedPlayer in
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
    @State var game = Game()
    game.addPlayer(name: "Player 1")
    game.addPlayer(name: "Player 2")
    game.addPlayer(name: "Player 3")
    
    game.players[0].setScore(round: 1, points: 3)
    game.players[1].setScore(round: 1, points: 20)
    game.players[2].setScore(round: 1, points: 0)
    
    @State var showView = true
    return LeaderboardView(showView: $showView).environment(game)
}
