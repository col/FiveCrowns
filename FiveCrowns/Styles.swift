//
//  SubmitButtonStyle.swift
//  FiveCrowns
//
//  Created by Colin Harris on 14/4/24.
//

import SwiftUI

struct SubmitButtonStyle: ButtonStyle {
    var color: Color
    
    init(color: Color = .blue) {
        self.color = color
    }
    
    func makeBody(configuration: Configuration) -> some View {
        configuration
            .label
            .padding([.vertical], 16)
            .padding([.horizontal], 32)
            .background(color)
            .foregroundStyle(.white)
            .clipShape(Capsule())
            .scaleEffect(configuration.isPressed ? 1.1 : 1)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct DeleteButtonStyle: ButtonStyle {
     func makeBody(configuration: Configuration) -> some View {
         configuration
             .label
             .padding([.vertical], 16)
             .padding([.horizontal], 32)
             .foregroundStyle(.red)
             .clipShape(
                RoundedRectangle(cornerRadius: 12)
             )
             .overlay(
                RoundedRectangle(cornerRadius: 12).stroke(.red, lineWidth: 1)
             )
             .scaleEffect(configuration.isPressed ? 1.1 : 1)
             .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

