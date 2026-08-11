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
                        AppLog.persistence.error("Save failed: \(error.localizedDescription, privacy: .public)")
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
                    AppLog.persistence.error("Load failed, starting empty: \(error.localizedDescription, privacy: .public)")
                }
            }
        }.environment(game)
    }
}
