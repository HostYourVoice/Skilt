//
//  SubmissionListRow.swift
//  swiftUIChatter
//
//  Created by BlessedAmulya Parmar on 1/29/25.
//

import SwiftUI

struct SubmissionListRow: View {
    let submission: Submission
    @Environment(AudioPlayer.self) private var audioPlayer
    @State private var isPresenting = false
    @State private var isExpanded = false
    
    // Parse username to extract submission ID and score
    private var submissionInfo: (id: String, score: String?) {
        guard let username = submission.username else {
            return (id: "Unknown", score: nil)
        }
        
        // Parse username like "#1234 (85/100)"
        if let idEndIndex = username.firstIndex(of: " "),
           let scoreStartIndex = username.firstIndex(of: "("),
           let scoreEndIndex = username.firstIndex(of: ")") {
            
            let id = String(username.prefix(upTo: idEndIndex))
            let scoreString = username[username.index(after: scoreStartIndex)..<scoreEndIndex]
            return (id: id, score: String(scoreString))
        } else if username.hasPrefix("#") {
            // Just ID without score
            return (id: username, score: nil)
        }
        
        return (id: username, score: nil)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header section with submission ID, timestamp, and score if available
            HStack(alignment: .center) {
                // Left side - ID
                Text(submissionInfo.id)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.primary)
                
                Spacer()
                
                // Right side - Score and timestamp
                HStack(spacing: 12) {
                    if let score = submissionInfo.score {
                        HStack(spacing: 4) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.yellow)
                            
                            Text(score)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.primary)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.yellow.opacity(0.1))
                        .cornerRadius(12)
                    }
                    
                    if let timestamp = submission.timestamp {
                        Text(timestamp)
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)
            .padding(.bottom, 8)
            
            // Divider
            Rectangle()
                .fill(Color.secondary.opacity(0.1))
                .frame(height: 1)
                .padding(.horizontal, 8)
            
            // Message content
            if let message = submission.message {
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        isExpanded.toggle()
                    }
                } label: {
                    Text(message)
                        .font(.system(size: 15))
                        .foregroundColor(.primary)
                        .lineLimit(isExpanded ? nil : 3)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            // Audio Button (if available) and Expand/Collapse Button
            if submission.audio != nil || isExpanded {
                HStack {
                    if let audio = submission.audio {
                        Button {
                            audioPlayer.setupPlayer(audio)
                            isPresenting.toggle()
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "play.circle.fill")
                                    .foregroundColor(.blue)
                                    .imageScale(.medium)
                                
                                Text("Play Recording")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.blue)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(16)
                        }
                        .fullScreenCover(isPresented: $isPresenting) {
                            AudioView(isPresented: $isPresenting, autoPlay: true)
                        }
                    }
                    
                    Spacer()
                    
                    // Show/Hide full text button if text is long
                    if let message = submission.message, message.count > 150 {
                        Button {
                            withAnimation {
                                isExpanded.toggle()
                            }
                        } label: {
                            Text(isExpanded ? "Show Less" : "Show More")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.blue)
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
            }
        }
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
        .padding(.vertical, 4)
        .padding(.horizontal, 4)
    }
} 