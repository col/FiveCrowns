//
//  UpdatePlayerView.swift
//  FiveKings
//
//  Created by Colin Harris on 14/4/24.
//

import SwiftUI

struct UpdatePlayerView: View {
    @Environment(Game.self) var game: Game
    @State var player: Player
    
    @Binding var showView: Bool
    @State var name: String
    
    init(player: Player, showView: Binding<Bool>) {
        self.player = player
        self.name = player.name
        self._showView = showView
    }
    
    var body: some View {
        VStack {
            Text("Update Player").font(.title)
            
            TextField("Name", text: $name).padding().border(.black)
            
            Button(action: renamePlayer) {
                Text("Update")
                    .padding(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
            }.buttonStyle(SubmitButtonStyle())
            
            Button(action: deletePlayer) {
                Text("Remove")
                    .padding(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
            }.buttonStyle(DeleteButtonStyle())
            
        }.padding()
    }
    
    func renamePlayer() {
        player.setName(name: name)
        showView = false
    }
    
    func deletePlayer() {
        game.removePlayer(name: player.name)
        showView = false
    }
}

#Preview {
    @State var game = Game()
    @State var showView = true
    let player = Player(name: "Player 1", order: 1)
    return UpdatePlayerView(player: player, showView: $showView).environment(game)
}
