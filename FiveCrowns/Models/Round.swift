//
//  Round.swift
//  FiveCrowns
//
//  Created by Colin Harris on 15/4/24.
//

import Foundation

class Round {    
    static func wildcardFor(round: Int) -> String {
        switch round {
        case 1:
            "Three"
        case 2:
            "Four"
        case 3:
            "Five"
        case 4:
            "Six"
        case 5:
            "Seven"
        case 6:
            "Eight"
        case 7:
            "Nine"
        case 8:
            "Ten"
        case 9:
            "Jack"
        case 10:
            "Queen"
        case 11:
            "King"
        default:
            ""
        }
    }
}
