//
//  ChattStore.swift
//  swiftUIChatter
//
//  Created by BlessedAmulya Parmar on 1/29/25.
//


import Observation
import Dispatch
import Foundation
import os

@Observable
final class ChattStore: @unchecked Sendable {
    
    func getChatts() async {
        // only one outstanding retrieval
        mutex.withLock {
            guard !self.isRetrieving else {
                return
            }
            self.isRetrieving = true
        }

        defer { // allow subsequent retrieval
            mutex.withLock {
                self.isRetrieving = false
            }
        }
        
        // Supabase API endpoint
        guard let apiUrl = URL(string: "https://oozwwgcihpunaaatfjwn.supabase.co/rest/v1/submissions?select=*&order=created_at.desc") else {
            print("getChatts: Bad URL")
            return
        }
        
        var request = URLRequest(url: apiUrl)
        request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Accept") // expect response in JSON
        // Add Supabase API key and authorization headers
        request.setValue("eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im9vend3Z2NpaHB1bmFhYXRmanduIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc0MjE3NjE5MiwiZXhwIjoyMDU3NzUyMTkyfQ.KjcU_btA7LBYLgxGA_5iRGNzmBcR2Dx4eYkw3wp-nfc", forHTTPHeaderField: "apikey")
        request.setValue("Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im9vend3Z2NpaHB1bmFhYXRmanduIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc0MjE3NjE5MiwiZXhwIjoyMDU3NzUyMTkyfQ.KjcU_btA7LBYLgxGA_5iRGNzmBcR2Dx4eYkw3wp-nfc", forHTTPHeaderField: "authorization")
        request.httpMethod = "GET"

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
                
            if let httpStatus = response as? HTTPURLResponse, httpStatus.statusCode != 200 {
                print("getChatts: HTTP STATUS: \(httpStatus.statusCode)")
                return
            }
                
            guard let submissionsReceived = try? JSONDecoder().decode([SubmissionData].self, from: data) else {
                print("getChatts: failed JSON deserialization")
                return
            }
            
            var idx = 0
            var _chatts = [Chatt]()
            for submission in submissionsReceived {
                let formattedDate = formatDate(submission.created_at)
                
                // Create username with score if available
                var username = "#\(submission.id)"
                if let scoring = submission.scoring, let score = scoring.score, let scoreMax = scoring.scoreMax {
                    username = "#\(submission.id) (\(score)/\(scoreMax))"
                }
                
                _chatts.append(Chatt(
                    username: username,
                    message: submission.submission_str,
                    id: UUID(),
                    timestamp: formattedDate,
                    altRow: idx % 2 == 0
                ))
                idx += 1
            }
            self.chatts = _chatts
        } catch {
            print("getChatts: NETWORKING ERROR \(error.localizedDescription)")
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

    func postChatt(_ chatt: Chatt) async -> Data? {
        let jsonObj = ["chatterID": ChatterID.shared.id,
                       "message": chatt.message]
        guard let jsonData = try? JSONSerialization.data(withJSONObject: jsonObj) else {
            print("postChatt: jsonData serialization error")
            return nil
        }
                
        guard let apiUrl = URL(string: "\(serverUrl)postauth/") else {
            print("postChatt: Bad URL")
            return nil
        }
        
        var request = URLRequest(url: apiUrl)
        request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.httpMethod = "POST"
        request.httpBody = jsonData

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, http.statusCode != 200 {
                print("postChatt: \(HTTPURLResponse.localizedString(forStatusCode: http.statusCode))")
            } else {
                return data
            }
        } catch {
            print("postChatt: NETWORKING ERROR")
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
    
    static let shared = ChattStore() // create one instance of the class to be shared
    private init() {}                // and make the constructor private so no other
                                     // instances can be created

    private var isRetrieving = false
    private let mutex = OSAllocatedUnfairLock()

    private(set) var chatts = [Chatt]()
    private let nFields = Mirror(reflecting: Chatt()).children.count-1

    private let serverUrl = "https://24.199.89.71/"
}

// Add a new function to insert a submission to Supabase
extension ChattStore {
    func upsertSubmission(submissionText: String, userId: String? = nil, scoringData: [String: Any]? = nil) async -> Bool {
        // Prepare the submission data
        var submission: [String: Any] = [
            "submission_str": submissionText,
            "user_id": userId ?? ChatterID.shared.id ?? "anonymous"
        ]
        
        // Add scoring data if provided
        if let scoringData = scoringData {
            submission["scoring"] = scoringData
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
        // Add Supabase API key and authorization headers (using the same keys as in getChatts)
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
    let scoring: ScoringData?
    
    enum CodingKeys: String, CodingKey {
        case id, created_at, submission_str, user_id, scoring
    }
}

// Structured scoring data
struct ScoringData: Codable {
    let score: Int?
    let scoreMax: Int?
    let feedback: String?
    
    // This init is needed for decoding empty JSON objects
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // All fields are optional
        score = try container.decodeIfPresent(Int.self, forKey: .score)
        scoreMax = try container.decodeIfPresent(Int.self, forKey: .scoreMax)
        feedback = try container.decodeIfPresent(String.self, forKey: .feedback)
    }
    
    enum CodingKeys: String, CodingKey {
        case score, scoreMax, feedback
    }
}

// Type to handle empty JSON objects - keeping for backward compatibility
struct EmptyJSONObject: Codable {
    // This is an empty struct to represent an empty JSON object
    // It will allow the decoder to handle {} in the JSON
}
