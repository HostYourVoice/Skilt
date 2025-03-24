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
        
        // Don't save to Supabase immediately - we'll do it after evaluation
        // with the scoring data included
        
        // Simulate evaluation process
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            self.submissionStatuses[questionId] = .evaluating
            
            // Simulate evaluation time
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                // Find the question
                guard let questionIndex = self.questions.firstIndex(where: { $0.id == questionId }) else { return }
                let question = self.questions[questionIndex]                
                let maxPoints = question.points
                let score = Int.random(in: (maxPoints * 6/10)...maxPoints)
                
                // Create a Task to handle the async feedback generation
                Task {
                    let feedback = await self.generateFeedback(
                        score: score,
                        maxPoints: maxPoints,
                        questionTitle: question.title,
                        scenario: question.scenario,
                        rubricPoints: question.rubricPoints,
                        userResponse: text
                    )
                    
                    // Get AI-generated feedback and score
                    if let aiResult = await self.generateAIFeedback(
                        score: score,
                        maxPoints: maxPoints,
                        questionTitle: question.title,
                        scenario: question.scenario,
                        rubricPoints: question.rubricPoints,
                        userResponse: text
                    ) {
                        // Update status with the complete feedback and AI score
                        self.submissionStatuses[questionId] = .completed(score: aiResult.aiScore, feedback: feedback)
                        
                        // Save to Supabase with scoring data
                        // Create the scoring JSON object
                        let scoringData: [String: Any] = [
                            "score": aiResult.aiScore,
                            "scoreMax": maxPoints,
                            "feedback": feedback
                        ]
                        
                        // Get the submission text that was previously saved
                        guard let submissionText = self.submissions[questionId] else { return }
                        
                        // Get the user's ID from UserProfile or fallback to ChatterID
                        let userProfile = UserProfile.shared
                        let userId = userProfile.userId ?? ChatterID.shared.id
                        
                        // Submit to Supabase with scoring data
                        let submissionWithContext = "\(self.course.name) - \(self.course.code):\n\(submissionText)"
                        
                        // Get the module ID from the courseData instead of using question.id (UUID)
                        let exerciseId = self.courseData?.course.modules.first(where: { $0.title == question.title })?.id ?? question.id.uuidString
                        
                        let success = await SubmissionStore.shared.upsertSubmission(
                            submissionText: submissionWithContext, 
                            userId: userId,
                            scoringData: scoringData,
                            exerciseId: exerciseId
                        )
                        
                        // Convert score and points to Double for percentage calculation
                        let newTotalSubmissions = question.totalSubmissions + 1
                        
                        // Calculate the current total score percentage
                        let currentTotalScorePercentage = question.averageScorePercentage * Double(question.totalSubmissions)
                        
                        // Calculate the new score percentage
                        let newScorePercentage = Double(score) / Double(question.points)
                        
                        // Calculate the new average score percentage
                        let newAverageScorePercentage = (currentTotalScorePercentage + newScorePercentage) / Double(newTotalSubmissions)
    
                        let newDifficulty: Int
                        if newAverageScorePercentage >= 0.8 {
                            newDifficulty = 1
                        } else if newAverageScorePercentage >= 0.6 {
                            newDifficulty = 2
                        } else if newAverageScorePercentage >= 0.4 {
                            newDifficulty = 3
                        } else if newAverageScorePercentage >= 0.2 {
                            newDifficulty = 4
                        } else {
                            newDifficulty = 5
                        }
                        
                    
                             
                    } else {
                        // Fallback to random score if AI feedback fails
                        self.submissionStatuses[questionId] = .completed(score: score, feedback: feedback)
                        
                        // Save to Supabase with scoring data
                        let scoringData: [String: Any] = [
                            "score": score,
                            "scoreMax": maxPoints,
                            "feedback": feedback
                        ]
                        
                        // Get the submission text that was previously saved
                        guard let submissionText = self.submissions[questionId] else { return }
                        
                        // Get the user's ID from UserProfile or fallback to ChatterID
                        let userProfile = UserProfile.shared
                        let userId = userProfile.userId ?? ChatterID.shared.id
                        
                        // Submit to Supabase with scoring data
                        let submissionWithContext = "\(self.course.name) - \(self.course.code):\n\(submissionText)"
                        
                        // Get the module ID from the courseData instead of using question.id (UUID)
                        let exerciseId = self.courseData?.course.modules.first(where: { $0.title == question.title })?.id ?? question.id.uuidString
                        
                        let success = await SubmissionStore.shared.upsertSubmission(
                            submissionText: submissionWithContext, 
                            userId: userId,
                            scoringData: scoringData,
                            exerciseId: exerciseId
                        )
                        
                        if !success {
                            print("Failed to save submission with scoring data to Supabase")
                        }
                    }
                }
            }
        }
    }
    
    private func generateFeedback(score: Int, maxPoints: Int, questionTitle: String, scenario: String, rubricPoints: [String: Int], userResponse: String) async -> String {
        let percentage = Double(score) / Double(maxPoints)
        
        // Build detailed feedback based on rubric points
        var feedbackParts: [String] = []
        
        // Add scenario context
        //feedbackParts.append("Based on the scenario: \"\(scenario.prefix(100))...\"")
        
        // Add overall assessment
        /*if percentage >= 0.9 {
            feedbackParts.append("Excellent work! Your response demonstrates a thorough understanding of the concepts and excellent application to the scenario.")
        } else if percentage >= 0.8 {
            feedbackParts.append("Great job! Your response shows good comprehension and application, with minor areas for improvement.")
        } else if percentage >= 0.7 {
            feedbackParts.append("Good effort! Your submission addresses the main points, but could use more depth in applying concepts to the scenario.")
        } else {
            feedbackParts.append("Your response shows basic understanding, but needs more development in relating concepts to the practical scenario.")
        }*/
        
        // Add rubric-based feedback
       /* feedbackParts.append("\nDetailed feedback based on rubric:")
        for (category, points) in rubricPoints {
            let categoryPercentage = Double(points) / Double(maxPoints / 4)
            let categoryFeedback = generateCategoryFeedback(category: category, percentage: categoryPercentage)
            feedbackParts.append("• \(category): \(categoryFeedback)")
        }*/
        
        // Get AI-generated feedback
        if let aiResult = await generateAIFeedback(score: score, maxPoints: maxPoints, questionTitle: questionTitle, scenario: scenario, rubricPoints: rubricPoints, userResponse: userResponse) {
            //feedbackParts.append("\nAI-Generated Feedback:")
            //feedbackParts.append("AI Score: \(aiResult.aiScore)/\(maxPoints)")
            feedbackParts.append(aiResult.feedback)
        }
        
        return feedbackParts.joined(separator: "\n")
    }
    
    private func generateAIFeedback(score: Int, maxPoints: Int, questionTitle: String, scenario: String, rubricPoints: [String: Int], userResponse: String) async -> (feedback: String, aiScore: Int)? {
        let encodedApiKey = "c2stc3ZjYWNjdC11SnZYWERIRVVRbTBTMjVGa2pNWDdVN0lJWWF2Z1J0QjI5dWNROFlxOWtBTF9XbjNTdmJraDF2V0U4czhxdmlTbEFBSl94UlNOeVQzQmxia0ZKZFhGbGFYOFFoSlVvMjZiZzVIVzFpcV9jV3g5bmJXWFU1dl84ZVJSMEotUVNIZkFQd3kwVVp5bVowT0Iwb2NxTWw3QVNURDhja0E="
        
        guard let apiKeyData = Data(base64Encoded: encodedApiKey),
              let apiKey = String(data: apiKeyData, encoding: .utf8) else {
            print("Error: Failed to decode API key")
            return nil
        }
        
        let url = URL(string: "https://api.openai.com/v1/chat/completions")!
        
        // Define the simplified function schema
        let functionSchema: [String: Any] = [
            "name": "generate_feedback",
            "description": "Generate feedback for a student's response",
            "parameters": [
                "type": "object",
                "properties": [
                    "score": [
                        "type": "integer",
                        "description": "The score awarded for the response"
                    ],
                    "maxScore": [
                        "type": "integer",
                        "description": "The maximum possible score"
                    ],
                    "feedback": [
                        "type": "string",
                        "description": "Detailed feedback for the student's response"
                    ]
                ],
                "required": ["score", "maxScore", "feedback"]
            ]
        ]
        
        // Prepare the prompt
        let prompt = """
Student's Response:
\'\(userResponse)\'

Please evaluate this response and provide comprehensive feedback.
"""
        
        // Prepare the request body
        let requestBody: [String: Any] = [
            "model": "gpt-4o",
            "messages": [
                ["role": "system", "content": """
You are an expert evaluator assessing student responses to professional scenarios. Your role is to:
1. Carefully evaluate the student's response against the provided rubric
2. Consider the specific scenario and question context
3. Provide detailed, constructive feedback
4. Award an appropriate score based on the rubric criteria

Current Scenario:
\(scenario)

Question:
\(questionTitle)

Max score possible: \(maxPoints)

Rubric Categories and Points:
\(rubricPoints.map { "• \($0.key): \($0.value)" }.joined(separator: "\n"))

Focus on evaluating:
- Understanding and application of concepts
- Practical relevance to the scenario
- Clarity and organization of the response
- Creativity and effectiveness of the solution
"""],
                ["role": "user", "content": prompt]
            ],
            "functions": [functionSchema],
            "function_call": ["name": "generate_feedback"],
            "temperature": 0.7,
            "max_tokens": 1000
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            // Log the raw response data
            if let responseString = String(data: data, encoding: .utf8) {
                print("OpenAI API Response:")
                print(responseString)
            }
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                print("Error: Invalid response from OpenAI API")
                return nil
            }
            
            guard let jsonResponse = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let choices = jsonResponse["choices"] as? [[String: Any]],
                  let firstChoice = choices.first,
                  let message = firstChoice["message"] as? [String: Any],
                  let functionCall = message["function_call"] as? [String: Any],
                  let arguments = functionCall["arguments"] as? String,
                  let feedbackData = try? JSONSerialization.jsonObject(with: arguments.data(using: .utf8)!) as? [String: Any] else {
                print("Error: Invalid JSON response from OpenAI API")
                return nil
            }
            
            // Extract both feedback and score
            guard let feedback = feedbackData["feedback"] as? String,
                  let aiScore = feedbackData["score"] as? Int else {
                return nil
            }
            
            // Log the extracted feedback and score
            print("AI Generated Score: \(aiScore)")
            print("AI Generated Feedback:")
            print(feedback)
            
            return (feedback: feedback, aiScore: aiScore)
            
        } catch {
            print("Error calling OpenAI API: \(error)")
            return nil
        }
    }
    
    private func generateCategoryFeedback(category: String, percentage: Double) -> String {
        switch category {
        case "Understanding of concepts":
            return percentage >= 0.8 ? "Strong grasp of core concepts demonstrated." : "Consider reviewing the module materials to strengthen conceptual understanding."
        case "Application to scenario":
            return percentage >= 0.8 ? "Excellent practical application to the scenario." : "Try to make more direct connections to the scenario context."
        case "Clarity and organization":
            return percentage >= 0.8 ? "Well-structured and clearly presented response." : "Focus on organizing your thoughts more systematically."
        case "Creativity and effectiveness":
            return percentage >= 0.8 ? "Creative and effective solution proposed." : "Consider exploring more innovative approaches to the problem."
        default:
            return percentage >= 0.8 ? "Well done in this area." : "Room for improvement in this aspect."
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
        var contentCards: [String] = []
        var resourceCards: [String] = []
        
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
        
        // Extract content and resource cards
        if let contentCardsData = module.contentCards {
            contentCards = contentCardsData
        }
        if let resourceCardsData = module.resourceCards {
            resourceCards = resourceCardsData
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
                averageScorePercentage: Double(difficulty),
                totalSubmissions: Int(0.0),
                difficulty: 0,
                points: points,
                altRow: false,
                rubricPoints: rubricPoints,
                checklistItems: checklistItems,
                aiFeedbackPoints: aiFeedbackPoints,
                contentCards: contentCards,
                resourceCards: resourceCards
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
                    averageScorePercentage: Double(difficulty),
                    totalSubmissions: Int(Double.random(in: 0...1)),
                    difficulty: Int.random(in: 0...50), // Random number of submissions for mock data
                    points: points,
                    altRow: i % 2 == 1,
                    rubricPoints: rubricPoints,
                    checklistItems: [],
                    aiFeedbackPoints: [],
                    contentCards: [],
                    resourceCards: []
                )
            )
        }
        
        return mockQuestions
    }
} 
