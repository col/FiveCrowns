//
//  AddPlayerView.swift
//  FiveCrowns
//
//  Created by Colin Harris on 14/4/24.
//

import SwiftUI

struct AddPlayerView: View {
    @Environment(Game.self) var game: Game
    
    @Binding var showView: Bool
    @State var name: String = ""
    @FocusState private var isFocused: Bool
    
    var body: some View {
        VStack {
            Text("Add Player")
            
            TextField("Name", text: $name)
                .padding()
                .border(.black)
                .focused($isFocused)
                .onSubmit(addPlayer)
            
            Button(action: addPlayer) {
                Text("Add Player")
            }.buttonStyle(SubmitButtonStyle())
        }
        .padding()
        .onAppear {
            isFocused = true
        }
    }
    
    func addPlayer() {
        game.addPlayer(name: name)
        reset()
    }
    
    func reset() {
        name = ""
        showView = false
    }
}

#Preview {
    let game = Game()
    @State var showView = true
    return AddPlayerView(showView: $showView).environment(game)
}
