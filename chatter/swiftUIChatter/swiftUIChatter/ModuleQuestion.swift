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
    let difficulty: Int
    let points: Int
    let altRow: Bool
    
    // A rubric for evaluating free-text submissions
    let rubricPoints: [String: Int]
} 