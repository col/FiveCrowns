//
//  ScorecardView.swift
//  FiveCrowns
//
//  Created by Colin Harris on 15/4/24.
//

import SwiftUI

struct ScorecardView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(Game.self) private var game: Game
    @State var round: Int
    let saveAction: ()->Void
    
    @State private var showingAddPlayer = false
    @State private var newPlayer: String = ""
    @FocusState private var playerFieldIsFocused: Bool
    
    @State private var showingLeaderboard = false
    @State private var showingNextRound = false
    @State private var showingEndGame = false
    
    @State private var showingNewGameButton = false
    @State private var showingNewGameConfirmation = false
    
    var body: some View {
//        @Bindable var bindableGame = game
        
        HStack(spacing: 0) {
            Image("ScorecardLogo", bundle: .main).resizable()
                .frame(width: 66, height: 66)
                .padding(.leading, 8)
            Spacer()
            Text("\(round+2) Card Round")
                .foregroundStyle(.black.opacity(0.7))
                .fontWeight(.bold)
                .font(.title2)
                .padding()
                .frame(maxWidth: .infinity, alignment: .center)
            Spacer()
            Image("ScorecardLogo", bundle: .main).resizable()
                .frame(width: 66, height: 66)
                .padding(.trailing, 8)
        }
        .padding(.vertical)
        .frame(maxWidth: .infinity)
        
        
        
        VStack(spacing: 0) {
            
            if game.players.count > 0 {
                ScorecardHeaders()
            } else {
                Button(action: {
                    showingAddPlayer = true
                    playerFieldIsFocused = true
                }) {
                    Label("Add Player", systemImage: "plus")
                        .fontWeight(.semibold)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 16)
                }
                .tint(Color("ButtonColour", bundle: .main).opacity(0.8))
                .buttonStyle(.borderedProminent)
            }
            
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(game.players) { player in
                        ScorecardRow(
                            player: player,
                            round: round,
                            scoreChanged: scoreChanged,
                            playerDeleted: playerDeleted,
                            editMode: round == 1
                        ).padding(0)
                        Divider().overlay(Color("HeaderRowBackground", bundle: .main))
                    }
                }
                
//            List($bindableGame.players, editActions: .delete) { $player in
//                ScorecardRow(player: player, round: round, scoreChanged: scoreChanged)
//                    .listRowInsets(EdgeInsets(top: 8, leading: 4, bottom: 8, trailing: 0))
//            }.listStyle(.plain)
                
                if game.players.count > 0 && round == 1 {
//                    HStack(spacing: 6) {
//                        Button(action: { showingAddPlayer = true }) {
//                            Label("Add Player", systemImage: "plus")
//                        }.padding().frame(maxWidth: .infinity, alignment: .leading)
//                        
//                        Text("").frame(minWidth: 44).padding()
//                        
//                        Text("").frame(minWidth: 44).padding()
//                    }
//                    .frame(maxWidth: .infinity)
//                    .padding(EdgeInsets(top: 0, leading: 6, bottom: 0, trailing: 6))
                    
                    Button(action: {
                        showingAddPlayer = true
                        playerFieldIsFocused = true
                    }) {
                        Label("Add Player", systemImage: "plus")
                            .fontWeight(.semibold)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 16)
                    }
                    .tint(Color("ButtonColour", bundle: .main).opacity(0.8))
                    .buttonStyle(.borderedProminent)
                    .padding(.top, 16)
                }
                
            }
            .frame(minHeight: 0)

            if showingNewGameButton {
                Button(action: { showingNewGameConfirmation = true }) {
                    Label("New Game", systemImage: "arrow.clockwise")
                }.buttonStyle(.borderedProminent).padding()
            }
            
        }
        .popover(isPresented: $showingLeaderboard) {
            LeaderboardView(showView: $showingLeaderboard)
        }
        .alert("Add Player", isPresented: $showingAddPlayer, actions: {
            Button("Cancel", role: .cancel, action: { showingAddPlayer = false })
            Button("Confirm", role: .none, action: addPlayer)
            TextField("Player name", text: $newPlayer).keyboardType(.asciiCapable).focused($playerFieldIsFocused)
        })
        .alert("Round Complete!", isPresented: $showingNextRound, actions: {
            Button("Cancel", role: .cancel, action: {})
            Button("OK", role: .none, action: nextRound)
        }) {
            Text("Ready to move on?")
        }
        .alert("Game Over!", isPresented: $showingEndGame, actions: {
            Button("Cancel", role: .cancel, action: {})
            Button("View Leaderboard", role: .none, action: { showingLeaderboard = true })
        }) {
            if let winner = game.winningPlayer() {
                Text("\(winner.name) is the winner!")
            }
        }
        .alert("Start New Game?", isPresented: $showingNewGameConfirmation, actions: {
            Button("Cancel", role: .cancel, action: {})
            Button("OK", role: .none, action: startNewGame)
        }) {
            Text("Are you sure?")
        }
        .onChange(of: scenePhase, initial: true) { _oldPhase, newPhase in
            if newPhase == .inactive {
                saveAction()
            }
        }
        
        Spacer()
        
        HStack {
            Button(action: previousRound) {
                Label("Previous", systemImage: "arrow.backward").labelStyle(.titleAndIcon).fontWeight(.semibold)
            }
            .disabled(round == 1)
            .tint(Color("ButtonColour", bundle: .main).opacity(0.8))
            .buttonStyle(.borderedProminent)
            .padding(.vertical, 8)
            .padding(.horizontal, 16)
            
            Spacer()
            
            Button(action: nextRound) {
                Label("Next", systemImage: "arrow.forward")
                    .fontWeight(.semibold)
                    .labelStyle(.titleAndIcon)
            }
            .disabled(round == 11)
            .tint(Color("ButtonColour", bundle: .main).opacity(0.8))
            .buttonStyle(.borderedProminent)
            .padding(.vertical, 8)
            .padding(.horizontal, 16)
        }
        
        if round > 1 {
            Button(action: { showingLeaderboard = true }) {
                Label("Leaderboard", systemImage: "list.star")
                    .fontWeight(.semibold)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 16)
            }
            .tint(Color("ButtonColour", bundle: .main).opacity(0.8))
            .buttonStyle(.borderedProminent)
            .padding(8)
        }
    }
    
    func startNewGame() {
        showingNewGameButton = false
        game.reset()
        round = 1
    }
    
    func scoreChanged() {
        let playersWithNoScore = game.players.filter { $0.pointsFor(round: round) == nil }
        if playersWithNoScore.count == 0 {
            if round == 11 {
                showingEndGame = true
                showingNewGameButton = true
            } else {
                showingNextRound = true
            }
        }
    }
    
    func playerDeleted(player: Player) {
        withAnimation {
            game.players.removeAll(where: { $0.id == player.id })
        }
    }
    
    func addPlayer() {
        withAnimation {
            game.addPlayer(name: newPlayer)
            newPlayer = ""
            showingAddPlayer = false
        }
    }
    
    func previousRound() {
        if round == 1 {
            return
        }
        
        withAnimation {
            round -= 1
        }
    }
    
    func nextRound() {
        if round == 11 {
            return
        }
        
        withAnimation {
            round += 1
        }
    }
}

#Preview {
    @State var game = Game()
    game.addPlayer(name: "Player 1")
    game.addPlayer(name: "Player 2")
    return ScorecardView(round: 2, saveAction: {})
        .environment(game)
}
