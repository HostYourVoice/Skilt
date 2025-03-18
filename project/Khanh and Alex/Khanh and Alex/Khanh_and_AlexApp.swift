//
//  Khanh_and_AlexApp.swift
//  Khanh and Alex
//
//  Created by Khanh Luong on 3/16/25.
//

import SwiftUI
import Foundation

@main
struct YourApp: App {
    @State private var streakManager = StreakManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
//                .onAppear {
//                    streakManager.updateStreak()
//                    print("Current Streak: \(streakManager.streakCount)")
//                }
        }
    }
}



struct StreakManager {
    private let streakKey = "streakCount"
    private let lastOpenedKey = "lastOpened"
    private let cooldownHours: TimeInterval = 2  // 2 seconds for testing cooldown (change to 12 hours as needed)
    private let maxGapHours: TimeInterval = 5  // 5 seconds for testing max gap (change to 24 hours as needed)
    
//    private let cooldownHours: TimeInterval = 12 * 60 * 60  // 2 seconds for testing cooldown (change to 12 hours as needed)
//    private let maxGapHours: TimeInterval = 28 * 60 * 60  // 5 seconds for testing max gap (change to 24 hours as needed)
    
    private var userDefaults: UserDefaults { .standard }
    
    var streakCount: Int {
        return userDefaults.integer(forKey: streakKey)
    }
    
    var lastOpened: Date? {
        return userDefaults.object(forKey: lastOpenedKey) as? Date
    }
    
    mutating func updateStreak() {
        let now = Date()
        
        if let lastDate = lastOpened {
            let timeSinceLast = now.timeIntervalSince(lastDate)
            
            // Check if enough time has passed to increment the streak
            if timeSinceLast >= cooldownHours {
                // If more than the max gap time has passed, reset the streak
                if timeSinceLast >= maxGapHours {
                    userDefaults.set(1, forKey: streakKey)
                } else {
                    // Increment the streak if it's within the cooldown period
                    userDefaults.set(streakCount + 1, forKey: streakKey)
                }
                
                // Update the last opened time only after incrementing the streak
                userDefaults.set(now, forKey: lastOpenedKey)
            }
        } else {
            // First time opening the app
            userDefaults.set(1, forKey: streakKey)
            userDefaults.set(now, forKey: lastOpenedKey)
        }
    }
}

