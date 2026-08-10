//
//  UpdateScoreView.swift
//  FiveKings
//
//  Created by Colin Harris on 14/4/24.
//

import SwiftUI

struct UpdateScoreView: View {
    @State var player: Player
    let round: Int
    
    @Binding var showView: Bool
    @State var score: String = ""
    @FocusState private var scoreFieldIsFocused: Bool
    
    init(player: Player, round: Int, showView: Binding<Bool>) {
        self.player = player
        self.round = round
        self._showView = showView
        if let points = player.pointsFor(round: round) {
            self.score = "\(points)"
        } else {
            self.score = ""
        }
        self.scoreFieldIsFocused = true
    }
    
    var body: some View {
        VStack {
            Text("Add Score for \(player.name)")
                .font(.title)
            
            TextField("Score", text: $score)
                .padding()
                .border(.black)
                .focused($scoreFieldIsFocused)
                .keyboardType(.numberPad)
            
            HStack(spacing: 20) {
                Button(action: wentDown) {
                    Text("Went Down")
                }.buttonStyle(SubmitButtonStyle(color: .gray))
                
                Button(action: addScore) {
                    Text("Confirm")
                }.buttonStyle(SubmitButtonStyle())
            }
            
        }
        .padding()
        .onAppear {
            scoreFieldIsFocused = true
        }
    }
    
    func wentDown() {
        player.setScore(round: round, points: 0)
        showView = false
    }
    
    func addScore() {
        player.setScore(round: round, points: Int(score))
        showView = false
    }
}

#Preview {
    let player = Player(name: "Player 1", order: 1)
    @State var showView = true
    return UpdateScoreView(player: player, round: 1, showView: $showView)
}
