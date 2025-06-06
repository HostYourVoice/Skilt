//
//  SubmissionStore.swift
//  swiftUIChatter
//
//  Created by BlessedAmulya Parmar on 1/29/25.
//

import Observation
import Dispatch
import Foundation
import os

@Observable
final class SubmissionStore: @unchecked Sendable {
    
    // Add streak properties
    private(set) var currentStreak: Int = 0
    private(set) var largestStreak: Int = 0
    private var lastSubmissionDate: Date?
    // Add a flag to prevent recursive getSubmissions calls
    private var isRefreshingAfterSubmission = false
    
    func getSubmissions() async {
        print("DEBUG: Starting getSubmissions()") // Debug logging
        
        // only one outstanding retrieval
        mutex.withLock {
            guard !self.isRetrieving else {
                print("DEBUG: Already retrieving - exiting early")
                return
            }
            self.isRetrieving = true
        }

        defer { // allow subsequent retrieval
            mutex.withLock {
                self.isRetrieving = false
                // Reset the refresh flag when getSubmissions completes
                self.isRefreshingAfterSubmission = false
            }
        }
        
        // Generate fallback mock data in case the real API fails
        Task { 
            // Wait for 3 seconds to let the real API attempt complete
            try? await Task.sleep(for: .seconds(3))
            
            // If submissions are still empty after API call, generate mock data
            if self.submissions.isEmpty {
                print("DEBUG: API call appears to have failed or returned no data. Generating mock data.")
                self.generateMockSubmissions()
            }
        }
        
        // Supabase API endpoint
        guard let apiUrl = URL(string: "https://oozwwgcihpunaaatfjwn.supabase.co/rest/v1/submissions?select=*&order=created_at.desc") else {
            print("getSubmissions: Bad URL")
            return
        }
        
        print("DEBUG: Preparing request to Supabase") // Debug logging
        
        var request = URLRequest(url: apiUrl)
        request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Accept") // expect response in JSON
        // Add Supabase API key and authorization headers
        request.setValue("eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im9vend3Z2NpaHB1bmFhYXRmanduIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc0MjE3NjE5MiwiZXhwIjoyMDU3NzUyMTkyfQ.KjcU_btA7LBYLgxGA_5iRGNzmBcR2Dx4eYkw3wp-nfc", forHTTPHeaderField: "apikey")
        request.setValue("Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im9vend3Z2NpaHB1bmFhYXRmanduIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc0MjE3NjE5MiwiZXhwIjoyMDU3NzUyMTkyfQ.KjcU_btA7LBYLgxGA_5iRGNzmBcR2Dx4eYkw3wp-nfc", forHTTPHeaderField: "authorization")
        request.httpMethod = "GET"

        do {
            print("DEBUG: Sending request to Supabase") // Debug logging
            let (data, response) = try await URLSession.shared.data(for: request)
            
            print("DEBUG: Response received with \(data.count) bytes") // Debug logging
                
            if let httpStatus = response as? HTTPURLResponse {
                print("DEBUG: HTTP Status: \(httpStatus.statusCode)") // Debug logging
                
                if httpStatus.statusCode != 200 {
                    print("getSubmissions: HTTP STATUS: \(httpStatus.statusCode)")
                    return
                }
            }
            
            // Print raw JSON for debugging
            if let jsonString = String(data: data, encoding: .utf8) {
                print("DEBUG: JSON Response: \(jsonString.prefix(200))...") // Print first 200 chars
            }
                
            guard let submissionsReceived = try? JSONDecoder().decode([SubmissionData].self, from: data) else {
                print("getSubmissions: failed JSON deserialization")
                // Try to identify the specific decoding error
                do {
                    _ = try JSONDecoder().decode([SubmissionData].self, from: data)
                } catch {
                    print("DEBUG: JSON Decoding error: \(error)")
                }
                return
            }
            
            print("DEBUG: Successfully decoded \(submissionsReceived.count) submissions") // Debug logging
            
            var idx = 0
            var _submissions = [Submission]()
            for submission in submissionsReceived {
                let formattedDate = formatDate(submission.created_at)
                
                var username = "#\(submission.id)"
                
                // Add score if available
                if let scoring = submission.scoring, let score = scoring.score, let scoreMax = scoring.scoreMax {
                    username = "\(username) (\(score)/\(scoreMax))"
                }
                
                _submissions.append(Submission(
                    username: username,
                    message: submission.submission_str,
                    id: UUID(),
                    timestamp: formattedDate,
                    altRow: idx % 2 == 0,
                    userEmail: submission.user_email
                ))
                idx += 1
            }
            
            print("DEBUG: Created \(_submissions.count) submission objects") // Debug logging
            
            self.submissions = _submissions
            
            // Update streak after receiving submissions
            updateSubmissionStreak()
            
            print("DEBUG: Updated store.submissions with \(self.submissions.count) items") // Debug logging
        } catch {
            print("getSubmissions: NETWORKING ERROR \(error.localizedDescription)")
            print("DEBUG: Detailed error: \(error)") // More detailed error info
        }
    }
    
    // Helper function to format the date from Supabase
    private func formatDate(_ dateString: String) -> String {
        // Create a date formatter to parse the ISO 8601 date
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        // Create a formatter for the output
        let outputFormatter = DateFormatter()
        outputFormatter.dateStyle = .short
        outputFormatter.timeStyle = .short
        
        // Convert the date string to Date and then to the desired format
        if let date = isoFormatter.date(from: dateString) {
            return outputFormatter.string(from: date)
        }
        return "Unknown date"
    }

    func postSubmission(_ submission: Submission) async -> Data? {
        let jsonObj = ["chatterID": ChatterID.shared.id,
                       "message": submission.message]
        guard let jsonData = try? JSONSerialization.data(withJSONObject: jsonObj) else {
            print("postSubmission: jsonData serialization error")
            return nil
        }
                
        guard let apiUrl = URL(string: "\(serverUrl)postauth/") else {
            print("postSubmission: Bad URL")
            return nil
        }
        
        var request = URLRequest(url: apiUrl)
        request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.httpMethod = "POST"
        request.httpBody = jsonData

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, http.statusCode != 200 {
                print("postSubmission: \(HTTPURLResponse.localizedString(forStatusCode: http.statusCode))")
            } else {
                return data
            }
        } catch {
            print("postSubmission: NETWORKING ERROR")
        }
        return nil
    }
    
    func addUser(_ idToken: String?) async -> String? {
        guard let idToken else {
            return nil
        }
        
        let jsonObj = ["clientID": "764691104830-r1sgun4nvii575mfad2g0g84lcj749e9.apps.googleusercontent.com",
                    "idToken" : idToken]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: jsonObj) else {
            print("addUser: jsonData serialization error")
            return nil
        }

        guard let apiUrl = URL(string: "\(serverUrl)adduser/") else {
            print("addUser: Bad URL")
            return nil
        }
        
        var request = URLRequest(url: apiUrl)
        request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Accept") // expect response in JSON
        request.httpMethod = "POST"
        request.httpBody = jsonData
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpStatus = response as? HTTPURLResponse, httpStatus.statusCode != 200 {
                print("addUser: HTTP STATUS: \(httpStatus.statusCode)")
                return nil
            }

            guard let jsonObj = try? JSONSerialization.jsonObject(with: data) as? [String:Any] else {
                print("addUser: failed JSON deserialization")
                return nil
            }

            ChatterID.shared.id = jsonObj["chatterID"] as? String
            ChatterID.shared.expiration = Date()+(jsonObj["lifetime"] as! TimeInterval)
            
            return ChatterID.shared.id
        } catch {
            print("addUser: NETWORKING ERROR")
            return nil
        }
    }
    
    static let shared = SubmissionStore() // create one instance of the class to be shared
    private init() {}                // and make the constructor private so no other
                                     // instances can be created

    private var isRetrieving = false
    private let mutex = OSAllocatedUnfairLock()

    private(set) var submissions = [Submission]()
    private let nFields = Mirror(reflecting: Submission()).children.count-1

    private let serverUrl = "https://24.199.89.71/"

    // For testing - create mock submissions when API fails
    private func generateMockSubmissions() {
        print("DEBUG: Generating mock submission data")
        var mockSubmissions = [Submission]()
        
        // Create 5 mock submissions
        for i in 0..<5 {
            let mockSubmission = Submission(
                username: "#\(1000 + i) (85/100)",
                message: "This is a mock submission #\(i+1) created for testing. The real API connection may be failing or there might be no data in the database.",
                id: UUID(),
                timestamp: "2/18/24, 10:\(i*10) AM",
                altRow: i % 2 == 0
            )
            mockSubmissions.append(mockSubmission)
        }
        
        self.submissions = mockSubmissions
        print("DEBUG: Added \(mockSubmissions.count) mock submissions to the store")
    }

    func updateELOscore(exerciseId: String, score: Int) {
        // Call the UserProfile method to update the exercise score
        UserProfile.shared.updateExerciseScore(exerciseId: exerciseId, score: score)
    }

    // Add function to calculate and update submission streak
    private func updateSubmissionStreak() {
        guard !submissions.isEmpty else {
            currentStreak = 0
            return
        }
        
        // Group submissions by date
        let calendar = Calendar.current
        var submissionDates = [Date]()
        let currentUserEmail = UserProfile.shared.email
        
        for submission in submissions {
            if let timestamp = submission.timestamp, 
               let date = parseSubmissionDate(timestamp) {
                
                // If we don't have a user email, count all submissions
                if currentUserEmail == nil {
                    submissionDates.append(date)
                }
                // If we have current user email and it matches this submission
                else if submission.userEmail == currentUserEmail {
                    submissionDates.append(date)
                }
            }
        }
        
        // Handle case where no submissions match current user
        guard !submissionDates.isEmpty else {
            currentStreak = 0
            return
        }
        
        // Sort dates from newest to oldest
        submissionDates.sort(by: >)
        
        // Initialize streak counter to 0 instead of 1
        var streak = 0
        let today = calendar.startOfDay(for: Date())
        
        // Check if most recent submission is from today or yesterday
        if let mostRecentDate = submissionDates.first {
            let mostRecentDay = calendar.startOfDay(for: mostRecentDate)
            let dayDifference = calendar.dateComponents([.day], from: mostRecentDay, to: today).day ?? 0
            
            if dayDifference <= 1 {
                // Valid streak - submission is today or yesterday
                streak = 1
                
                // Calculate consecutive days
                for i in 0..<submissionDates.count-1 {
                    let currentDate = calendar.startOfDay(for: submissionDates[i])
                    let nextDate = calendar.startOfDay(for: submissionDates[i+1])
                    
                    let daysBetween = calendar.dateComponents([.day], from: nextDate, to: currentDate).day ?? 0
                    
                    if daysBetween == 1 {
                        // Consecutive day
                        streak += 1
                    } else if daysBetween > 1 {
                        // Streak broken
                        break
                    }
                }
            }
            // If dayDifference > 1, streak remains 0
            
            lastSubmissionDate = mostRecentDate
        }
        
        currentStreak = streak
        if currentStreak > largestStreak {
            largestStreak = currentStreak
        }
    }
    
    // Helper function to parse a submission timestamp string into a Date
    private func parseSubmissionDate(_ dateString: String) -> Date? {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .short
        dateFormatter.timeStyle = .short
        return dateFormatter.date(from: dateString)
    }
}

// Add a new function to insert a submission to Supabase
extension SubmissionStore {
    func upsertSubmission(submissionText: String, userId: String? = nil, scoringData: [String: Any]? = nil, exerciseId: String? = nil) async -> Bool {
        // Get user profile information
        let userProfile = UserProfile.shared
        
        // Prepare the submission data
        var submission: [String: Any] = [
            "submission_str": submissionText,
            "user_id": userId ?? userProfile.userId ?? ChatterID.shared.id ?? "anonymous"
        ]
        
        // Add email if available
        if let email = userProfile.email {
            submission["user_email"] = email
        }
        
        // Add user's display name if available
        if userProfile.displayName != "Anonymous User" {
            submission["user_name"] = userProfile.displayName
        }
        
        // Add scoring data if provided
        if let scoringData = scoringData {
            submission["scoring"] = scoringData
        }
        
        // Add exercise ID if provided
        if let exerciseId = exerciseId {
            submission["exercise_id"] = exerciseId
        }
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: submission) else {
            print("upsertSubmission: JSON serialization error")
            return false
        }
        
        // Supabase API endpoint for the submissions table
        guard let apiUrl = URL(string: "https://oozwwgcihpunaaatfjwn.supabase.co/rest/v1/submissions") else {
            print("upsertSubmission: Bad URL")
            return false
        }
        
        var request = URLRequest(url: apiUrl)
        // Headers for Supabase
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        // Add Supabase API key and authorization headers
        request.setValue("eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im9vend3Z2NpaHB1bmFhYXRmanduIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc0MjE3NjE5MiwiZXhwIjoyMDU3NzUyMTkyfQ.KjcU_btA7LBYLgxGA_5iRGNzmBcR2Dx4eYkw3wp-nfc", forHTTPHeaderField: "apikey")
        request.setValue("Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im9vend3Z2NpaHB1bmFhYXRmanduIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc0MjE3NjE5MiwiZXhwIjoyMDU3NzUyMTkyfQ.KjcU_btA7LBYLgxGA_5iRGNzmBcR2Dx4eYkw3wp-nfc", forHTTPHeaderField: "authorization")
        // For upsert, we use the POST method with Prefer: resolution=merge header
        request.setValue("resolution=merge-duplicates", forHTTPHeaderField: "Prefer")
        request.httpMethod = "POST"
        request.httpBody = jsonData
        
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            
            if let httpStatus = response as? HTTPURLResponse {
                let success = (200...299).contains(httpStatus.statusCode)
                if !success {
                    print("upsertSubmission: HTTP STATUS: \(httpStatus.statusCode)")
                } else {
                    // Update streak after successful submission
                    // Check flag before calling getSubmissions to prevent loops
                    if !isRefreshingAfterSubmission {
                        isRefreshingAfterSubmission = true
                        await getSubmissions() // Refresh submissions to update streak
                    } else {
                        print("DEBUG: Skipping getSubmissions to prevent recursive loop")
                    }
                    
                    // If submission was successful and we have exercise ID and scoring data
                    if let exerciseId = exerciseId, 
                       let scoringData = scoringData,
                       let score = scoringData["score"] as? Int {
                        // Update the ELO score
                        updateELOscore(exerciseId: exerciseId, score: score)
                        
                    }
                }
                return success
            }
            
            return false
        } catch {
            print("upsertSubmission: NETWORKING ERROR \(error.localizedDescription)")
            return false
        }
    }
}

// Model for the Supabase submissions data
struct SubmissionData: Codable {
    let id: Int
    let created_at: String
    let submission_str: String
    let user_id: String?
    let user_email: String?
    let user_name: String?
    let scoring: ScoringData?
    
    enum CodingKeys: String, CodingKey {
        case id, created_at, submission_str, user_id, user_email, user_name, scoring
    }
    
    // Custom initializer with defaults for nullable fields
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(Int.self, forKey: .id)
        created_at = try container.decode(String.self, forKey: .created_at)
        submission_str = try container.decode(String.self, forKey: .submission_str)
        user_id = try container.decodeIfPresent(String.self, forKey: .user_id)
        user_email = try container.decodeIfPresent(String.self, forKey: .user_email)
        user_name = try container.decodeIfPresent(String.self, forKey: .user_name)
        scoring = try container.decodeIfPresent(ScoringData.self, forKey: .scoring)
    }
}

struct ScoringData: Codable {
    let score: Int?
    let scoreMax: Int?
    let feedback: String?
    let rubricPoints: [String]?
    
    enum CodingKeys: String, CodingKey {
        case score, scoreMax, feedback, rubricPoints
    }
    
    // Custom initializer for more resilient decoding
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        score = try container.decodeIfPresent(Int.self, forKey: .score)
        scoreMax = try container.decodeIfPresent(Int.self, forKey: .scoreMax)
        feedback = try container.decodeIfPresent(String.self, forKey: .feedback)
        rubricPoints = try container.decodeIfPresent([String].self, forKey: .rubricPoints)
    }
} 