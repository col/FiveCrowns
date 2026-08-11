//
//  AppLog.swift
//  FiveCrowns
//

import OSLog

enum AppLog {
    static let persistence = Logger(subsystem: "com.challengr.FiveCrowns", category: "persistence")
    static let game = Logger(subsystem: "com.challengr.FiveCrowns", category: "game")
}
