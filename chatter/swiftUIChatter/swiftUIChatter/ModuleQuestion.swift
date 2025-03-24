////
////  ModuleQuestion.swift
////  swiftUIChatter
////
////  Created by AI Assistant on 2/15/25.
////
//
//import Foundation
//
//struct ModuleQuestion: Identifiable, Codable {
//    let id: UUID
//    let moduleId: String
//    let title: String
//    let scenario: String
//    let question: String
//    let options: [String]
//    let correctAnswer: Int
//    let explanation: String
//    var difficulty: Int
//    var averageScorePercentage: Double
//    var totalSubmissions: Int
//    let points: Int
//    let altRow: Bool
//    
//    // A rubric for evaluating free-text submissions
//    let rubricPoints: [String: Int]
//    
//    // Detailed rubric criteria
//    let checklistItems: [ChecklistItem]
//    let aiFeedbackPoints: [String]
//    
//    init(
//        id: UUID = UUID(),
//        moduleId: String,
//        title: String,
//        scenario: String,
//        question: String,
//        options: [String],
//        correctAnswer: Int,
//        explanation: String,
//        difficulty: Int,
//        averageScorePercentage: Double = 0.0,
//        totalSubmissions: Int = 0,
//        points: Int,
//        altRow: Bool = false,
//        rubricPoints: [String: Int],
//        checklistItems: [ChecklistItem] = [],
//        aiFeedbackPoints: [String] = []
//    ) {
//        self.id = id
//        self.moduleId = moduleId
//        self.title = title
//        self.scenario = scenario
//        self.question = question
//        self.options = options
//        self.correctAnswer = correctAnswer
//        self.explanation = explanation
//        self.difficulty = difficulty
//        self.averageScorePercentage = averageScorePercentage
//        self.totalSubmissions = totalSubmissions
//        self.points = points
//        self.altRow = altRow
//        self.rubricPoints = rubricPoints
//        self.checklistItems = checklistItems
//        self.aiFeedbackPoints = aiFeedbackPoints
//    }
//    
//    // Helper method to create a question from a module
//    static func from(module: Module) -> ModuleQuestion {
//        let points = module.difficulty.score * 20
//        let rubricPoints: [String: Int] = [
//            "Understanding of concepts": points / 4,
//            "Application to scenario": points / 4,
//            "Clarity and organization": points / 4,
//            "Creativity and effectiveness": points / 4
//        ]
//        
//        let checklistItems = module.rubric?.checklistItems ?? []
//        let aiFeedbackPoints = module.rubric?.aiFeedbackPoints ?? []
//        
//        let scenario = module.scenario?.context ?? ""
//        let requirements = module.scenario?.requirements.map { "- \($0)" }.joined(separator: "\n") ?? ""
//        let questionText = """
//        How would you approach this scenario to achieve the best outcome?
//        
//        Consider these requirements:
//        \(requirements)
//        
//        Describe your strategy and rationale.
//        """
//        
//        return ModuleQuestion(
//            moduleId: module.id,
//            title: module.title,
//            scenario: scenario,
//            question: questionText,
//            options: [
//                "Option A: First approach",
//                "Option B: Second approach",
//                "Option C: Third approach",
//                "Option D: Fourth approach"
//            ],
//            correctAnswer: Int.random(in: 0...3),
//            explanation: "This scenario tests your understanding of the principles and best practices.",
//            difficulty: module.difficulty.score,
//            points: points,
//            rubricPoints: rubricPoints,
//            checklistItems: checklistItems,
//            aiFeedbackPoints: aiFeedbackPoints
//        )
//    }
//}
//
//// Struct for detailed checklist items
//struct ChecklistItem: Identifiable, Codable {
//    let id: String
//    let description: String
//} 
