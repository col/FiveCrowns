//
//  ScoreRow.swift
//  FiveCrowns
//
//  Created by Colin Harris on 14/4/24.
//

import SwiftUI

struct ScorecardRow: View {
    @State var player: Player
    let round: Int
    let scoreChanged: (() -> Void)
    let playerDeleted: ((Player) -> Void)
    let editMode: Bool
    
    var points: String {
        if let points = player.pointsFor(round: round) {
            return "\(points)"
        } else {
            return "-"
        }
    }
    
    @State private var showingAddScore = false
    @State private var newScore: String = ""
    @FocusState private var scoreFieldIsFocused: Bool
    
    @State private var showingUpdatePlayer = false
    @State private var newName: String = ""
    @FocusState private var nameFieldIsFocused: Bool
    
    var body: some View {
        HStack(spacing: 0) {
            if editMode {
                Button(action: { playerDeleted(player) }) {
                    Label("", systemImage: "trash")
                        .padding(.vertical, 8)
                        .padding(.leading, 8)
                        .padding(.trailing, 0)
                }
                
                .foregroundColor(.red)
            }
            
            Text(player.name)
                .foregroundStyle(.black.opacity(0.7))
                .fontWeight(.medium)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
                .onTapGesture(count: 1, perform: showUpdatePlayer)
                .onLongPressGesture(perform: showUpdatePlayer)
                
            
            Text(points)
                .foregroundStyle(.black.opacity(0.7))
                .fontWeight(.medium)
                .frame(minWidth: 44)
                .padding(8)
                .border( player.pointsFor(round: round) == nil ? .gray : .blue)
                .background( player.pointsFor(round: round) == 0 ? .blue.opacity(0.2) : .clear )
                .onTapGesture(perform: showAddScore)
            
            Text("\(player.totalPoints)")
                .foregroundStyle(.black.opacity(0.7))
                .fontWeight(.semibold)
                .frame(minWidth: 44)
                .padding(8)
            
        }
        .frame(maxWidth: .infinity)
        .padding(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
        .background(Color("RowColour", bundle: .main).opacity(0.8))
        .alert("Enter Score", isPresented: $showingAddScore, actions: {
            Button("Cancel", role: .cancel, action: {})
            Button("Went Down!", role: .none, action: wentDown)
            Button("Confirm", role: .none, action: addScore)
            TextField("Score", text: $newScore)
                .keyboardType(.numberPad)
                .focused($scoreFieldIsFocused)
        }, message: {
            Text("Enter score for \(player.name)")
        })
        .alert("Rename Player", isPresented: $showingUpdatePlayer, actions: {
            Button("Cancel", role: .cancel, action: { showingUpdatePlayer = false })
            Button("Confirm", role: .none, action: updatePlayer)
            TextField("Player name", text: $newName).keyboardType(.asciiCapable).focused($nameFieldIsFocused)
        })
    }
    
    func wentDown() {
        player.setScore(round: round, points: 0)
        player.updateTotal()
        scoreChanged()
    }
    
    func addScore() {
        player.setScore(round: round, points: Int(newScore))
        player.updateTotal()
        scoreChanged()
    }
    
    func showAddScore() {
        if let score = player.pointsFor(round: round) {
            newScore = "\(score)"
        } else {
            newScore = ""
        }
        showingAddScore = true
        scoreFieldIsFocused = true
    }
    
    func showUpdatePlayer() {
        newName = player.name
        showingUpdatePlayer = true
        nameFieldIsFocused = true
    }
    
    func updatePlayer() {
        player.setName(name: newName)
    }
}

#Preview {
    let player = Player(name: "Player 1", order: 1)
    player.setScore(round: 1, points: 10)
    return VStack(spacing: 0) {
        ScorecardHeaders()
        ScorecardRow(
            player: player,
            round: 1,
            scoreChanged: { puts("Score changed!!!") },
            playerDeleted: { player in puts("Player Deleted!!!") },
            editMode: true
        )
        Divider()
        ScorecardRow(
            player: player,
            round: 1,
            scoreChanged: { puts("Score changed!!!") },
            playerDeleted: { player in puts("Player Deleted!!!") },
            editMode: true
        )
    }
}
