//
//  Player.swift
//  FiveCrowns
//
//  Created by Colin Harris on 14/4/24.
//

import Foundation

@Observable
class Player: Codable, Identifiable {
    var id = UUID()
    var name: String
    var order: Int
    var scores: [Int: Int?] = [:]
    var totalPoints: Int = 0
    
    init(name: String, order: Int) {
        self.name = name
        self.order = order
    }
    
    func setName(name: String) {
        self.name = name
    }
    
    func setScore(round: Int, points: Int? = nil) {
        scores[round] = points    
        updateTotal()
    }
    
    func updateTotal() {
        totalPoints = scores.values.reduce(0) { total, points in
            return total + (points ?? 0)
        }
    }
    
    func pointsFor(round: Int) -> Int? {
        if let points = scores[round] {
            return points
        }
        return nil
    }
    
    func reset() {
        scores = [:]
        totalPoints = 0
    }
}
