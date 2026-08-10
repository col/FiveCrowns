//
//  FiveCrownsApp.swift
//  FiveCrowns
//
//  Created by Colin Harris on 14/4/24.
//

import SwiftUI

@main
struct FiveCrownsApp: App {
    @State private var game = Game()
    
    var body: some Scene {
        WindowGroup {
            ScorecardView(round: 1) {
                Task {
                    do {
                        try await game.save(players: game.players)
                    } catch {
                        fatalError(error.localizedDescription)
                    }
                }
            }.background(Gradient(colors: [
                Color("BackgroundDark", bundle: .main),
                Color("BackgroundMiddle", bundle: .main),
                Color("Background", bundle: .main)
            ]).opacity(0.8))
            .task {
                do {
                    try await game.load()
                } catch {
                    fatalError(error.localizedDescription)
                }
            }
        }.environment(game)
    }
}
