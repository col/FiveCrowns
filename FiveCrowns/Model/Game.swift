//
//  Game.swift
//  FiveCrowns
//
//  Created by Colin Harris on 14/4/24.
//

import Foundation
import SwiftUI

@Observable class Game {
    var players: [Player] = []
    
    func addPlayer(name: String) {
        players.append(Player(name: name, order: players.count + 1))
    }
    
    func removePlayer(name: String) {
        players.removeAll { $0.name == name }
    }
    
    func leaderboardPlayers() -> [RankedPlayer] {
        return RankedPlayer.rankPlayers(players: players)
    }
    
    func winningPlayer() -> Player? {
        return leaderboardPlayers().first?.player
    }
    
    func reset() {
        players.forEach { $0.reset() }
    }
    
    func clearPlayers() {
        players = []
    }
    
    private static func fileURL() throws -> URL {
        try FileManager.default.url(for: .documentDirectory,
                                            in: .userDomainMask,
                                            appropriateFor: nil,
                                            create: false)
        .appendingPathComponent("game.data")
    }
    
    func load() async throws {
        let task = Task<[Player], Error> {
            let fileURL = try Self.fileURL()
            guard let data = try? Data(contentsOf: fileURL) else {
                return []
            }
            puts("data = '\(String(data: data, encoding: .utf8) ?? "unknown")'")
            if data.count != 0 {
                let players = try JSONDecoder().decode([Player].self, from: data)
                return players
            } else {
                return []
            }
        }
        let players = try await task.value
        self.players = players
    }
    
    func save(players: [Player]) async throws {
        puts("Saving game data...")
        let task = Task {
            let data = try JSONEncoder().encode(players)
            let outfile = try Self.fileURL()
            try data.write(to: outfile)
        }
        _ = try await task.value
        puts("done.")
    }
}
