//
//  ModuleQuestionsStore.swift
//  swiftUIChatter
//
//  Created by AI Assistant on 2/15/25.
//

import Observation
import Foundation
import SwiftUI

@Observable
final class ModuleQuestionsStore {
    private(set) var questions: [ModuleQuestion] = []
    private(set) var isLoading: Bool = false
    private(set) var course: Course
    
    // Track submissions for each question
    private(set) var submissions: [UUID: String] = [:]
    private(set) var submissionStatuses: [UUID: SubmissionStatus] = [:]
    
    // Cached JSON data
    private var courseData: CourseData?
    
    enum SubmissionStatus {
        case notSubmitted
        case submitted
        case evaluating
        case completed(score: Int, feedback: String)
    }
    
    init(course: Course) {
        self.course = course
        loadJSONData()
        loadQuestions()
    }
    
    // Load the CoursesTYG.json data
    private func loadJSONData() {
        guard let url = Bundle.main.url(forResource: "CoursesTYG", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            print("Error loading JSON file")
            return
        }
        
        do {
            let decoder = JSONDecoder()
            self.courseData = try decoder.decode(CourseData.self, from: data)
        } catch {
            print("Error decoding JSON: \(error)")
        }
    }
    
    func loadQuestions() {
        isLoading = true
        
        // Simulate network delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.questions = self.generateQuestionsFromJSON()
            self.isLoading = false
        }
    }
    
    func submitResponse(for questionId: UUID, text: String) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        // Store the submission locally
        submissions[questionId] = text
        submissionStatuses[questionId] = .submitted
        
        // Save submission to Supabase
        let submissionWithContext = "\(course.name) - \(course.code):\n\(text)"
        Task {
            let success = await SubmissionStore.shared.upsertSubmission(submissionText: submissionWithContext)
            if !success {
                print("Failed to save submission to Supabase")
            }
        }
        
        // Simulate evaluation process
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            self.submissionStatuses[questionId] = .evaluating
            
            // Simulate evaluation time
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                // Find the question
                guard let question = self.questions.first(where: { $0.id == questionId }) else { return }
                
                // Generate a random score between 60-100% of max points
                let maxPoints = question.points
                let score = Int.random(in: (maxPoints * 6/10)...maxPoints)
                
                // Generate feedback
                let feedback = self.generateFeedback(score: score, maxPoints: maxPoints, questionTitle: question.title)
                
                // Update status
                self.submissionStatuses[questionId] = .completed(score: score, feedback: feedback)
                
                // Save the scoring data to Supabase
                Task {
                    // Create the scoring JSON object
                    let scoringData: [String: Any] = [
                        "score": score,
                        "scoreMax": maxPoints,
                        "feedback": feedback
                    ]
                    
                    // Get the submission text that was previously saved
                    guard let submissionText = self.submissions[questionId] else { return }
                    
                    // Update the submission with scoring data
                    let submissionWithContext = "\(self.course.name) - \(self.course.code):\n\(submissionText)"
                    let success = await SubmissionStore.shared.upsertSubmission(
                        submissionText: submissionWithContext, 
                        scoringData: scoringData
                    )
                    
                    if !success {
                        print("Failed to save scoring data to Supabase")
                    }
                }
            }
        }
    }
    
    private func generateFeedback(score: Int, maxPoints: Int, questionTitle: String) -> String {
        let percentage = Double(score) / Double(maxPoints)
        
        if percentage >= 0.9 {
            return "Excellent work! Your response demonstrates a thorough understanding of the concepts covered in this module."
        } else if percentage >= 0.8 {
            return "Great job! Your response shows good comprehension of the key concepts, with minor areas for improvement."
        } else if percentage >= 0.7 {
            return "Good effort! Your submission addresses the main points, but could use more depth in some areas."
        } else {
            return "Your response shows basic understanding, but needs more development. Review the module materials and try again."
        }
    }
    
    private func generateQuestionsFromJSON() -> [ModuleQuestion] {
        var questions: [ModuleQuestion] = []
        
        // Find the module matching our course's moduleId
        guard let courseData = courseData,
              let module = courseData.course.modules.first(where: { $0.id == course.moduleId }),
              let scenario = module.scenario else {
            // Fallback to mock questions if no scenario found
            return generateMockQuestions()
        }
        
        // Instead of creating multiple questions with different titles,
        // create just one question using the module's title
        let difficulty = module.difficulty.score
        let points = difficulty * 20
        
        // Create rubric points for evaluating submissions
        let rubricPoints: [String: Int] = [
            "Understanding of concepts": points / 4,
            "Application to scenario": points / 4,
            "Clarity and organization": points / 4,
            "Creativity and effectiveness": points / 4
        ]
        
        // Extract detailed rubric items if available
        var checklistItems: [ChecklistItem] = []
        var aiFeedbackPoints: [String] = []
        
        if let rubric = module.rubric {
            // Extract checklist items
            if let items = rubric.checklistItems {
                checklistItems = items.map { ChecklistItem(id: $0.id, description: $0.description) }
            }
            
            // Extract AI feedback points
            if let feedbackPoints = rubric.aiFeedbackPoints {
                aiFeedbackPoints = feedbackPoints
            }
        }
        
        // Format question based on requirements
        let requirementsText = scenario.requirements.map { "- \($0)" }.joined(separator: "\n")
        let questionText = """
        How would you approach this scenario to achieve the best outcome?
        
        Consider these requirements:
        \(requirementsText)
        
        Describe your strategy and rationale.
        """
        
        // Add the single question to the list
        questions.append(
            ModuleQuestion(
                title: module.title, // Use the module title directly
                scenario: scenario.context,
                question: questionText,
                options: [
                    "Option A: First approach",
                    "Option B: Second approach",
                    "Option C: Third approach",
                    "Option D: Fourth approach"
                ],
                correctAnswer: Int.random(in: 0...3),
                explanation: "This scenario tests your understanding of \(course.category) principles and best practices in email communication.",
                difficulty: difficulty,
                points: points,
                altRow: false,
                rubricPoints: rubricPoints,
                checklistItems: checklistItems,
                aiFeedbackPoints: aiFeedbackPoints
            )
        )
        
        return questions
    }
    
    // Keep the original function as a fallback
    private func generateMockQuestions() -> [ModuleQuestion] {
        var mockQuestions: [ModuleQuestion] = []
        
        // Scenarios based on course category
        let scenarios = [
            "You are a marketing specialist at a tech company launching a new product. The CEO wants to maximize email open rates for the product announcement.",
            "As a customer service representative, you need to respond to a customer complaint email about a delayed shipment.",
            "Your team is preparing a monthly newsletter for subscribers, and you need to decide on the email structure and content.",
            "You're managing email communications for an upcoming virtual conference with attendees from different time zones.",
            "A customer has emailed with concerns about their account security after receiving a suspicious email.",
            "Your company is rebranding, and you need to create an email announcement to inform customers of the changes.",
            "You're preparing a sales email campaign for a seasonal promotion with limited-time offers.",
            "As an HR manager, you need to send an important policy update to all employees via email.",
            "You're launching a win-back email campaign targeting customers who haven't made a purchase in 6 months.",
            "Your company has experienced a data breach, and you need to send a notification email to affected users."
        ]
        
        // Generate 5-7 questions based on the course
        let questionCount = Int.random(in: 5...7)
        
        for i in 0..<questionCount {
            let difficulty = Int.random(in: 1...course.maxDifficulty)
            let points = difficulty * 20
            let scenarioIndex = i % scenarios.count
            
            // Create a question title
            let titles = [
                "Email Subject Line Strategy",
                "Customer Response Protocol",
                "Content Personalization",
                "Email Delivery Timing",
                "Security Communication",
                "Call-to-Action Design",
                "Mobile Optimization",
                "A/B Testing Approach",
                "Compliance Guidelines",
                "Analytics Interpretation"
            ]
            
            let titleIndex = i % titles.count
            
            // Create rubric points for evaluating submissions
            let rubricPoints: [String: Int] = [
                "Understanding of concepts": points / 4,
                "Application to scenario": points / 4,
                "Clarity and organization": points / 4,
                "Creativity and effectiveness": points / 4
            ]
            
            mockQuestions.append(
                ModuleQuestion(
                    title: titles[titleIndex],
                    scenario: scenarios[scenarioIndex],
                    question: "How would you approach this scenario to achieve the best outcome? Describe your strategy and rationale.",
                    options: [
                        "Option A: First approach",
                        "Option B: Second approach",
                        "Option C: Third approach",
                        "Option D: Fourth approach"
                    ],
                    correctAnswer: Int.random(in: 0...3),
                    explanation: "This scenario tests your understanding of \(course.category) principles and best practices in email communication.",
                    difficulty: difficulty,
                    points: points,
                    altRow: i % 2 == 1,
                    rubricPoints: rubricPoints,
                    checklistItems: [],
                    aiFeedbackPoints: []
                )
            )
        }
        
        return mockQuestions
    }
} 