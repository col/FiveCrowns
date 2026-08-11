//
//  RankedPlayer.swift
//  FiveCrowns
//
//  Created by Colin Harris on 19/4/24.
//

import Foundation

class RankedPlayer: Identifiable {
    let player: Player
    let rank: Int
    
    var id: UUID {
        get {
            player.id
        }
    }
    
    init(player: Player, rank: Int) {
        self.player = player
        self.rank = rank
    }
    
    
    static func rankPlayers(players: [Player]) -> [RankedPlayer] {
        let sortedPlayers = players.sorted { $0.totalPoints < $1.totalPoints }
        let uniqueScores = Set( sortedPlayers.map { $0.totalPoints } ).sorted()
        
        return sortedPlayers.map { player in
            let rank = (uniqueScores.firstIndex(of: player.totalPoints) ?? 0) + 1
            return RankedPlayer(player: player, rank: rank)
        }
    }
}
