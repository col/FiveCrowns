//
//  ScorecardHeaders.swift
//  FiveCrowns
//
//  Created by Colin Harris on 14/4/24.
//

import SwiftUI

struct ScorecardHeaders: View {
    var body: some View {
        HStack(spacing: 0) {
            Text("Player")
                .foregroundStyle(.white.opacity(0.9))
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
//                .padding(.horizontal, 8)
            
            Text("Score")
                .foregroundStyle(.white.opacity(0.9))
                .fontWeight(.semibold)
                .frame(minWidth: 44)
                .padding(8)
//                .padding(.horizontal, 8)
            
            Text("Total")
                .foregroundStyle(.white.opacity(0.9))
                .fontWeight(.semibold)
                .frame(minWidth: 44)
                .padding(8)
//                .padding(.horizontal, 8)
            
        }
        .frame(maxWidth: .infinity)
        .padding(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
        .background(Color("HeaderRowBackground", bundle: .main).opacity(0.8))
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
            editMode: false
        )
        Divider()
        ScorecardRow(
            player: player,
            round: 1,
            scoreChanged: { puts("Score changed!!!") },
            playerDeleted: { player in puts("Player Deleted!!!") },
            editMode: false
        )
        Divider()
    }
}
