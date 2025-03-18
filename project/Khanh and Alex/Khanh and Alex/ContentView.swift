//
//  ContentView.swift
//  Khanh and Alex
//
//  Created by Khanh Luong on 3/16/25.
//

import SwiftUI

//struct ContentView: View {
//    var body: some View {
//        VStack {
//            Image(systemName: "globe")
//                .imageScale(.large)
//                .foregroundStyle(.tint)
//            Text("Hello, world!")
//        }
//        .padding()
//    }
//}

struct ContentView: View {
    @State private var streakManager = StreakManager()
    @State private var currentStreak: Int = 0
    
    var body: some View {
        VStack {
            // Display the streak count
            Text("Current Streak: \(currentStreak)")
                .font(.title)
                .padding()
            
            Button(action: {
                streakManager.updateStreak() // Update streak on button press
                currentStreak = streakManager.streakCount // Update the current streak to reflect the new count
                print("Current Streak: \(currentStreak)") // Print updated streak
            }) {
                Text("Press Me")
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
        }
        .onAppear {
            // Probably don't need it, keeping it just in case
            // Set the initial streak count when the view appears
            currentStreak = streakManager.streakCount
        }
        .padding()
    }
}

//#Preview {
//    ContentView()
//}

