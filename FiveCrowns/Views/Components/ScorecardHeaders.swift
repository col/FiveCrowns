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
                .foregroundStyle(Theme.onHeader)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
//                .padding(.horizontal, 8)
            
            Text("Score")
                .foregroundStyle(Theme.onHeader)
                .fontWeight(.semibold)
                .frame(minWidth: 44)
                .padding(8)
//                .padding(.horizontal, 8)
            
            Text("Total")
                .foregroundStyle(Theme.onHeader)
                .fontWeight(.semibold)
                .frame(minWidth: 44)
                .padding(8)
//                .padding(.horizontal, 8)
            
        }
        .frame(maxWidth: .infinity)
        .padding(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
        .background(Theme.headerRow)
    }
}

#Preview {
    @Previewable @State var game = Game(store: GameStore(
        fileURL: FileManager.default.temporaryDirectory.appendingPathComponent("preview.data")))
    VStack(spacing: 0) {
        ScorecardHeaders()
        ScorecardRow(player: Player(name: "Ada"), editMode: false)
        Divider()
        ScorecardRow(player: Player(name: "Grace"), editMode: false)
        Divider()
    }
    .environment(game)
}
