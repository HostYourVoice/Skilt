//
//  ModuleQuestion.swift
//  swiftUIChatter
//
//  Created by AI Assistant on 2/15/25.
//

import Foundation

struct ModuleQuestion: Identifiable {
    let id: UUID = UUID()
    let title: String
    let scenario: String
    let question: String
    let options: [String]
    let correctAnswer: Int
    let explanation: String
    let averageScorePercentage: Double
    let totalSubmissions: Int
    let difficulty: Int
    let points: Int
    let altRow: Bool
    
    // A rubric for evaluating free-text submissions
    let rubricPoints: [String: Int]
    
    // Detailed rubric criteria
    let checklistItems: [ChecklistItem]
    let aiFeedbackPoints: [String]
    
    // Content and resource cards
    let contentCards: [String]
    let resourceCards: [String]
}

// Struct for detailed checklist items
struct ChecklistItem: Identifiable {
    let id: String
    let description: String
} 