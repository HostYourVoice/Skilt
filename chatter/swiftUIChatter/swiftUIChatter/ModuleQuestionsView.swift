//
//  ModuleQuestionsView.swift
//  swiftUIChatter
//
//  Created by AI Assistant on 2/15/25.
//

import SwiftUI

struct QuestionRow: View {
    let question: ModuleQuestion
    var store: ModuleQuestionsStore
    @State private var responseText: String = ""
    @State private var selectedOption: Int? = nil
    @State private var showExplanation: Bool = false
    @State private var isExpanded: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Question header - always visible
            Button(action: {
                isExpanded.toggle()
            }) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(question.title)
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text("Difficulty: \(question.difficulty) | Points: \(question.points)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    // Show submission status if available
                    if let status = store.submissionStatuses[question.id] {
                        switch status {
                        case .notSubmitted:
                            Text("Not Submitted")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        case .submitted:
                            Text("Submitted")
                                .foregroundColor(.blue)
                                .font(.caption)
                        case .evaluating:
                            HStack(spacing: 4) {
                                Text("Evaluating")
                                    .foregroundColor(.orange)
                                    .font(.caption)
                                ProgressView()
                                    .scaleEffect(0.7)
                            }
                        case .completed(let score, _):
                            Text("\(score)/\(question.points) pts")
                                .foregroundColor(.green)
                                .font(.caption.bold())
                        }
                    }
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(PlainButtonStyle())
            
            if isExpanded {
                // Scenario and question details
                VStack(alignment: .leading, spacing: 16) {
                    // Scenario
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Scenario:")
                            .font(.subheadline.bold())
                        
                        Text(question.scenario)
                            .font(.body)
                            .padding(.bottom, 4)
                        
                        Text(question.question)
                            .font(.body.italic())
                    }
                    .padding()
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(8)
                    
                    // Response area
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Your Response:")
                            .font(.subheadline.bold())
                        
                        if let status = store.submissionStatuses[question.id],
                           case .completed(let score, let feedback) = status,
                           let submission = store.submissions[question.id] {
                            // Show submitted response
                            VStack(alignment: .leading, spacing: 8) {
                                Text(submission)
                                    .padding()
                                    .background(Color.secondary.opacity(0.05))
                                    .cornerRadius(8)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                
                                // Score and feedback
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Text("Score:")
                                            .fontWeight(.bold)
                                        Text("\(score)/\(question.points) points")
                                            .foregroundColor(.green)
                                    }
                                    
                                    Divider()
                                    
                                    Text("Feedback:")
                                        .fontWeight(.bold)
                                    Text(feedback)
                                }
                                .padding()
                                .background(Color.green.opacity(0.1))
                                .cornerRadius(8)
                            }
                        } else if let status = store.submissionStatuses[question.id], 
                                  case .evaluating = status,
                                  let submission = store.submissions[question.id] {
                            // Show submitted response being evaluated
                            VStack(alignment: .center, spacing: 8) {
                                Text(submission)
                                    .padding()
                                    .background(Color.secondary.opacity(0.05))
                                    .cornerRadius(8)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                
                                HStack {
                                    ProgressView()
                                    Text("Evaluating your response...")
                                        .foregroundColor(.orange)
                                }
                                .padding()
                                .frame(maxWidth: .infinity)
                            }
                        } else if let status = store.submissionStatuses[question.id],
                                  case .submitted = status,
                                  let submission = store.submissions[question.id] {
                            // Show submitted response waiting for evaluation
                            Text(submission)
                                .padding()
                                .background(Color.secondary.opacity(0.05))
                                .cornerRadius(8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        } else {
                            // Text input for new submission
                            ZStack(alignment: .topLeading) {
                                if responseText.isEmpty {
                                    Text("Type your response here...")
                                        .foregroundColor(.gray)
                                        .padding(.top, 8)
                                        .padding(.leading, 4)
                                        .allowsHitTesting(false)
                                }
                                
                                TextEditor(text: $responseText)
                                    .frame(minHeight: 120)
                                    .padding(4)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                                    )
                            }
                            
                            // Submit button
                            Button(action: {
                                store.submitResponse(for: question.id, text: responseText)
                            }) {
                                Text("Submit Response")
                                    .fontWeight(.medium)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(
                                        responseText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?
                                            Color.blue.opacity(0.3) : Color.blue
                                    )
                                    .foregroundColor(.white)
                                    .cornerRadius(8)
                            }
                            .disabled(responseText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                    }
                    
                    // Rubric
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Grading Rubric:")
                            .font(.subheadline.bold())
                        
                        ForEach(Array(question.rubricPoints.keys.sorted()), id: \.self) { criterion in
                            if let points = question.rubricPoints[criterion] {
                                HStack {
                                    Text(criterion)
                                    Spacer()
                                    Text("\(points) pts")
                                        .foregroundColor(.secondary)
                                }
                                .font(.caption)
                                .padding(.vertical, 2)
                            }
                        }
                    }
                    .padding()
                    .background(Color.secondary.opacity(0.05))
                    .cornerRadius(8)
                    
                    // Detailed Rubric Checklist
                    if !question.checklistItems.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Detailed Evaluation Criteria:")
                                .font(.subheadline.bold())
                                .padding(.top, 8)
                            
                            ForEach(question.checklistItems) { item in
                                HStack(alignment: .top, spacing: 10) {
                                    Image(systemName: "checkmark.circle")
                                        .foregroundColor(.blue)
                                    Text(item.description)
                                        .font(.caption)
                                }
                                .padding(.vertical, 2)
                            }
                            
                            if !question.aiFeedbackPoints.isEmpty {
                                Divider()
                                    .padding(.vertical, 4)
                                
                                Text("Assessment Focus Areas:")
                                    .font(.caption.bold())
                                    .padding(.top, 4)
                                
                                ForEach(question.aiFeedbackPoints.indices, id: \.self) { index in
                                    HStack(alignment: .top, spacing: 10) {
                                        Text("\(index+1).")
                                            .font(.caption.bold())
                                            .foregroundColor(.purple)
                                        Text(question.aiFeedbackPoints[index])
                                            .font(.caption)
                                            .italic()
                                    }
                                    .padding(.vertical, 1)
                                }
                            }
                        }
                        .padding()
                        .background(Color.blue.opacity(0.05))
                        .cornerRadius(8)
                    }
                }
            }
        }
        .padding(.vertical, 8)
        .animation(.easeInOut, value: isExpanded)
        .onAppear {
            // Set initial expansion based on submission status
            if let status = store.submissionStatuses[question.id] {
                switch status {
                case .completed, .evaluating:
                    isExpanded = true
                default:
                    break
                }
            }
        }
    }
}

struct ModuleQuestionsView: View {
    let course: Course
    @State private var store: ModuleQuestionsStore
    @State private var showingTestAlert = false
    @State private var testSubmissionResult = false
    
    init(course: Course) {
        self.course = course
        self._store = State(initialValue: ModuleQuestionsStore(course: course))
    }
    
    // Test function to directly submit to Supabase
    func testSubmitToSupabase() async {
        let testSubmission = "Test submission from \(course.name) at \(Date().formatted())"
        testSubmissionResult = await SubmissionStore.shared.upsertSubmission(submissionText: testSubmission)
        showingTestAlert = true
    }
    
    var body: some View {
        List {
            Section(header: 
                VStack(alignment: .leading, spacing: 8) {
                    Text(course.name)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Code: \(course.code)")
                        .font(.subheadline)
                    
                    Text("Instructor: \(course.instructor)")
                        .font(.subheadline)
                    
                    Text(store.questions.count == 1 ? "This module contains a single scenario to complete." : "This module contains \(store.questions.count) scenarios to complete.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 4)
                }
                .padding(.bottom, 8)
            ) {
                if store.isLoading {
                    ProgressView("Loading questions...")
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding()
                } else if store.questions.isEmpty {
                    Text("No questions available for this module.")
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding()
                } else {
                    ForEach(store.questions) { question in
                        QuestionRow(question: question, store: store)
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color(question.altRow ?
                                .systemGray5 : .systemGray6))
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Module Scenarios")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable {
            store.loadQuestions()
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: {
                    Task {
                        await testSubmitToSupabase()
                    }
                }) {
                    Image(systemName: "square.and.arrow.up")
                }
            }
        }
        .alert("Supabase Submission Test", isPresented: $showingTestAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(testSubmissionResult ? "Submission successful!" : "Submission failed. Check console for details.")
        }
    }
}

#Preview {
    ModuleQuestionsView(course: Course(
        name: "Introduction to Email Design",
        code: "MOD101",
        instructor: "Prof. Marketing",
        altRow: false,
        difficulty: 3,
        maxDifficulty: 5,
        eloRequired: 100,
        category: "Marketing",
        moduleId: "email-design-101"
    ))
} 