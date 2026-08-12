//
//  Round.swift
//  FiveCrowns
//
//  Created by Colin Harris on 15/4/24.
//

import Foundation

/// A round of Five Crowns. Eleven rounds are played, dealing three cards in
/// the first and thirteen in the last.
enum Round: Int, CaseIterable, Codable, Sendable, Comparable {
    case one = 1, two, three, four, five, six, seven, eight, nine, ten, eleven

    static let first = Round.one
    static let last = Round.eleven

    /// Cards dealt this round: three in round one, up to thirteen in round eleven.
    var cardCount: Int { rawValue + 2 }

    var next: Round? { Round(rawValue: rawValue + 1) }
    var previous: Round? { Round(rawValue: rawValue - 1) }

    static func < (lhs: Round, rhs: Round) -> Bool { lhs.rawValue < rhs.rawValue }
}
