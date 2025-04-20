//
//  ModuleQuestionsView.swift
//  swiftUIChatter
//
//  Created by AI Assistant on 2/15/25.
//

import SwiftUI
import UIKit
import Speech
import Vision

@Observable
class SpeechRecognizer: NSObject, SFSpeechRecognizerDelegate {
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))!
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    
    var isRecording = false
    var transcribedText = ""
    private var existingText = ""
    private var latestTranscription = ""
    
    override init() {
        super.init()
        speechRecognizer.delegate = self
    }
    
    func startRecording(existingText: String, updateText: @escaping (String) -> Void) {
        self.existingText = existingText
        self.transcribedText = existingText
        self.latestTranscription = ""
        
        // Request authorization
        SFSpeechRecognizer.requestAuthorization { authStatus in
            DispatchQueue.main.async {
                if authStatus == .authorized {
                    do {
                        try self.startRecordingSession(updateText: updateText)
                    } catch {
                        print("Recording failed to start: \(error)")
                    }
                }
            }
        }
    }
    
    private func startRecordingSession(updateText: @escaping (String) -> Void) throws {
        // Cancel any ongoing tasks
        recognitionTask?.cancel()
        recognitionTask = nil
        
        // Configure audio session
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        
        // Create and configure recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        recognitionRequest?.shouldReportPartialResults = true
        
        // Start recognition task
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest!) { result, error in
            if let result = result {
                DispatchQueue.main.async {
                    // Update only the latest transcription
                    self.latestTranscription = result.bestTranscription.formattedString
                    
                    // Combine existing text with new transcription
                    let finalText = self.existingText.trimmingCharacters(in: .whitespacesAndNewlines)
                    let newText = self.latestTranscription.trimmingCharacters(in: .whitespacesAndNewlines)
                    
                    if finalText.isEmpty {
                        self.transcribedText = newText
                    } else {
                        self.transcribedText = finalText + " " + newText
                    }
                    
                    updateText(self.transcribedText)
                }
            }
            if error != nil {
                self.stopRecording()
            }
        }
        
        // Configure audio engine
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            self.recognitionRequest?.append(buffer)
        }
        
        audioEngine.prepare()
        try audioEngine.start()
        isRecording = true
    }
    
    func stopRecording() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil
        isRecording = false
        
        // Save the final transcribed text as the existing text for next recording
        existingText = transcribedText
    }
}

@Observable
class HandwritingRecognizer: NSObject {
    private let textRecognitionRequest = VNRecognizeTextRequest()
    var isProcessing = false
    
    override init() {
        super.init()
        textRecognitionRequest.recognitionLevel = .accurate
        textRecognitionRequest.usesLanguageCorrection = true
    }
    
    func recognizeText(from image: UIImage, completion: @escaping (String) -> Void) {
        guard let cgImage = image.cgImage else { return }
        
        isProcessing = true
        
        let requestHandler = VNImageRequestHandler(cgImage: cgImage)
        textRecognitionRequest.revision = VNRecognizeTextRequestRevision2
        
        do {
            try requestHandler.perform([textRecognitionRequest])
            if let observations = textRecognitionRequest.results {
                let recognizedStrings = observations.compactMap { observation in
                    observation.topCandidates(1).first?.string
                }
                let combinedText = recognizedStrings.joined(separator: " ")
                DispatchQueue.main.async {
                    completion(combinedText)
                    self.isProcessing = false
                }
            }
        } catch {
            print("Error recognizing text: \(error)")
            isProcessing = false
        }
    }
}

struct CustomTextEditor: UIViewRepresentable {
    @Binding var text: String
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.delegate = context.coordinator
        textView.font = .systemFont(ofSize: 16)
        textView.backgroundColor = .clear
        textView.textColor = .label
        // Only correct after space
        textView.autocorrectionType = .yes
        textView.smartQuotesType = .no
        textView.smartDashesType = .no
        textView.smartInsertDeleteType = .no
        return textView
    }
    
    func updateUIView(_ uiView: UITextView, context: Context) {
        if uiView.text != text {
            uiView.text = text
        }
    }
    
    class Coordinator: NSObject, UITextViewDelegate {
        var parent: CustomTextEditor
        
        init(_ parent: CustomTextEditor) {
            self.parent = parent
        }
        
        func textViewDidChange(_ textView: UITextView) {
            parent.text = textView.text
        }
        
        func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
            // Only apply autocorrect after space
            if text == " " {
                return true
            }
            // Disable autocorrect for non-space characters
            textView.autocorrectionType = .no
            // Re-enable autocorrect after a brief delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                textView.autocorrectionType = .yes
            }
            return true
        }
    }
}

struct ImagePickerView: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    @Environment(\.presentationMode) var presentationMode
    var sourceType: UIImagePickerController.SourceType
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePickerView
        
        init(_ parent: ImagePickerView) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.selectedImage = image
            }
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
}

struct QuestionRow: View {
    let question: ModuleQuestion
    @ObservedObject var store: ModuleQuestionsStore
    @Environment(AudioPlayer.self) private var audioPlayer
    @State private var speechRecognizer = SpeechRecognizer()
    @State private var handwritingRecognizer = HandwritingRecognizer()
    @State private var responseText: String = ""
    @State private var selectedOption: Int? = nil
    @State private var showExplanation: Bool = false
    @State private var isScenarioExpanded: Bool = true
    @State private var isContentCardsExpanded: Bool = false
    @State private var isResourceCardsExpanded: Bool = false
    @State private var isAudioPresenting: Bool = false
    @State private var showingImagePicker = false
    @State private var sourceType: UIImagePickerController.SourceType = .camera
    @State private var selectedImage: UIImage?
    @State private var isProcessingCleanup: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Content Cards Dropdown - always visible
            if !question.contentCards.isEmpty {
                VStack {
                    Button(action: {
                        withAnimation {
                            isContentCardsExpanded.toggle()
                        }
                    }) {
                        HStack {
                            Text("Key Points to Consider")
                                .font(.subheadline.bold())
                            Spacer()
                            Image(systemName: isContentCardsExpanded ? "chevron.up" : "chevron.down")
                                .foregroundColor(.secondary)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    if isContentCardsExpanded {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(question.contentCards, id: \.self) { card in
                                HStack(alignment: .top, spacing: 8) {
                                    Image(systemName: "lightbulb.fill")
                                        .foregroundColor(.yellow)
                                    Text(card)
                                        .font(.subheadline)
                                }
                            }
                        }
                        .padding(.top, 8)
                    }
                }
                .padding()
                .background(Color.yellow.opacity(0.1))
                .cornerRadius(8)
            }
            
            // Resource Cards Dropdown - always visible
            if !question.resourceCards.isEmpty {
                VStack {
                    Button(action: {
                        withAnimation {
                            isResourceCardsExpanded.toggle()
                        }
                    }) {
                        HStack {
                            Text("Helpful Resources")
                                .font(.subheadline.bold())
                            Spacer()
                            Image(systemName: isResourceCardsExpanded ? "chevron.up" : "chevron.down")
                                .foregroundColor(.secondary)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    if isResourceCardsExpanded {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(question.resourceCards, id: \.self) { card in
                                HStack(alignment: .top, spacing: 8) {
                                    Image(systemName: "book.fill")
                                        .foregroundColor(.blue)
                                    Text(card)
                                        .font(.subheadline)
                                }
                            }
                        }
                        .padding(.top, 8)
                    }
                }
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)
            }

            // Expandable section button
            Button(action: {
                withAnimation {
                    isScenarioExpanded.toggle()
                }
            }) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Response: \(question.title)")
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
                    
                    Image(systemName: isScenarioExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(.secondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
            .padding()
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(8)
            
            if isScenarioExpanded {
                // Scenario content
                VStack(alignment: .leading, spacing: 8) {
                    Text("Scenario:")
                        .font(.headline)
                        .foregroundColor(.primary)
                        .padding(.bottom, 2)
                    
                    Text(question.scenario)
                        .font(.body)
                        .foregroundColor(.primary)
                        .padding(.bottom, 4)
                    
                    Text("Question:")
                        .font(.headline)
                        .foregroundColor(.primary)
                        .padding(.bottom, 2)
                        .padding(.top, 4)
                    
                    Text(question.question)
                        .font(.body.italic())
                        .foregroundColor(.primary)
                }
                .padding()
                .background(Color.clear)
                .cornerRadius(8)
                
                // Response area
                VStack(alignment: .leading, spacing: 8) {
                    Text("Your Response:")
                        .font(.subheadline.bold())
                        .foregroundColor(.primary)
                    
                    if let status = store.submissionStatuses[question.id],
                       case .completed(let score, let feedback) = status,
                       let submission = store.submissions[question.id] {
                        // Show submitted response
                        VStack(alignment: .leading, spacing: 8) {
                            Text(submission)
                                .foregroundColor(.primary)
                                .padding()
                                .cornerRadius(8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            
                            // Score and feedback
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("Score:")
                                        .fontWeight(.bold)
                                        .foregroundColor(.primary)
                                    Text("\(score)/\(question.points) points")
                                        .foregroundColor(.green)
                                }
                                
                                Divider()
                                    .background(Color.gray.opacity(0.3))
                                
                                Text("Feedback:")
                                    .fontWeight(.bold)
                                    .foregroundColor(.primary)
                                Text(feedback)
                                    .foregroundColor(.primary)
                            }
                            .padding()
                            .cornerRadius(8)
                        }
                    } else if let status = store.submissionStatuses[question.id], 
                              case .evaluating = status,
                              let submission = store.submissions[question.id] {
                        VStack(alignment: .center, spacing: 8) {
                            Text(submission)
                                .foregroundColor(.primary)
                                .padding()
                                .cornerRadius(8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            
                            HStack {
                                ProgressView()
                                    .tint(.primary)
                                Text("Evaluating your response...")
                                    .foregroundColor(.orange)
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                        }
                    } else if let status = store.submissionStatuses[question.id],
                              case .submitted = status,
                              let submission = store.submissions[question.id] {
                        Text(submission)
                            .foregroundColor(.primary)
                            .padding()
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
                            
                            CustomTextEditor(text: $responseText)
                                .frame(minHeight: 120)
                                .padding(4)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                                )
                                .contentShape(Rectangle())
                                .onTapGesture { } // Consume tap gesture to prevent propagation
                        }
                        .background(Color.clear) // Ensure background doesn't trigger actions
                        .allowsHitTesting(true)  // Allow interaction with the text editor
                        
                        // Audio recording button
                        HStack {
                            Spacer()
                            
                            // AI Text Cleanup button
                            Button {
                                generateAICleanup()
                            } label: {
                                Image(systemName: "sparkle")
                                    .foregroundColor(isProcessingCleanup ? .gray : .blue)
                                    .imageScale(.large)
                                    .frame(width: 44, height: 44)
                                    .overlay(
                                        Group {
                                            if isProcessingCleanup {
                                                ProgressView()
                                                    .scaleEffect(0.7)
                                                    .tint(.blue)
                                            }
                                        }
                                    )
                            }
                            .buttonStyle(BorderlessButtonStyle())
                            .contentShape(Rectangle())
                            .disabled(isProcessingCleanup || responseText.isEmpty)
                            
                            // Handwriting button
                            Button {
                                sourceType = .camera
                                showingImagePicker = true
                            } label: {
                                Image(systemName: "doc.text.viewfinder")
                                    .foregroundColor(.blue)
                                    .imageScale(.large)
                                    .frame(width: 44, height: 44)
                            }
                            .buttonStyle(BorderlessButtonStyle())
                            .contentShape(Rectangle())
                            
                            // Speech button
                            Button {
                                if speechRecognizer.isRecording {
                                    speechRecognizer.stopRecording()
                                } else {
                                    speechRecognizer.startRecording(existingText: responseText) { text in
                                        responseText = text
                                    }
                                }
                            } label: {
                                Image(systemName: speechRecognizer.isRecording ? "mic.fill" : "mic")
                                    .foregroundColor(speechRecognizer.isRecording ? .red : .blue)
                                    .imageScale(.large)
                                    .frame(width: 44, height: 44)
                            }
                            .buttonStyle(BorderlessButtonStyle())
                            .contentShape(Rectangle())
                        }
                        .padding(.horizontal)
                        .frame(height: 44)
                        
                        // Add sheet for image picker
                        .sheet(isPresented: $showingImagePicker) {
                            ImagePickerView(selectedImage: $selectedImage, sourceType: sourceType)
                        }
                        .onChange(of: selectedImage) { newImage in
                            if let image = newImage {
                                handwritingRecognizer.recognizeText(from: image) { recognizedText in
                                    responseText = responseText + (responseText.isEmpty ? "" : " ") + recognizedText
                                }
                            }
                        }
                        
                        // Audio recording view
                        .fullScreenCover(isPresented: $isAudioPresenting) {
                            AudioView(isPresented: $isAudioPresenting)
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
                        .buttonStyle(BorderlessButtonStyle()) // Prevent button style from affecting parent views
                        .disabled(responseText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
                .padding()
                .cornerRadius(8)
                .onAppear {
                    audioPlayer.setupRecorder()
                }
                
                // Rubric
                VStack(alignment: .leading, spacing: 4) {
                    Text("Grading Rubric:")
                        .font(.subheadline.bold())
                        .foregroundColor(.primary)
                    
                    ForEach(Array(question.rubricPoints.keys.sorted()), id: \.self) { criterion in
                        if let points = question.rubricPoints[criterion] {
                            HStack {
                                Text(criterion)
                                    .foregroundColor(.primary)
                                Spacer()
                                Text("\(points) pts")
                                    .foregroundColor(.primary.opacity(0.8))
                            }
                            .font(.caption)
                            .padding(.vertical, 2)
                        }
                    }
                }
                .padding()
                .background(Color.clear)
                .cornerRadius(8)
                
                // Detailed Rubric Checklist
                if !question.checklistItems.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Detailed Evaluation Criteria:")
                            .font(.subheadline.bold())
                            .foregroundColor(.primary)
                            .padding(.top, 8)
                        
                        ForEach(question.checklistItems) { item in
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: "checkmark.circle")
                                    .foregroundColor(.blue)
                                Text(item.description)
                                    .font(.caption)
                                    .foregroundColor(.primary)
                            }
                            .padding(.vertical, 2)
                        }
                        
                        if !question.aiFeedbackPoints.isEmpty {
                            Divider()
                                .background(Color.gray.opacity(0.3))
                                .padding(.vertical, 4)
                            
                            Text("Assessment Focus Areas:")
                                .font(.caption.bold())
                                .foregroundColor(.primary)
                                .padding(.top, 4)
                            
                            ForEach(question.aiFeedbackPoints.indices, id: \.self) { index in
                                HStack(alignment: .top, spacing: 10) {
                                    Text("\(index+1).")
                                        .font(.caption.bold())
                                        .foregroundColor(.blue)
                                    Text(question.aiFeedbackPoints[index])
                                        .font(.caption)
                                        .foregroundColor(.primary)
                                        .italic()
                                }
                                .padding(.vertical, 1)
                            }
                        }
                    }
                    .padding()
                    .background(Color.clear)
                    .cornerRadius(8)
                }
            }
        }
        .padding(.vertical, 8)
        .onAppear {
            // Set initial expansion based on submission status
            if let status = store.submissionStatuses[question.id] {
                switch status {
                case .completed, .evaluating:
                    isScenarioExpanded = true
                default:
                    break
                }
            }
        }
    }
    
    func generateAICleanup() {
        guard !responseText.isEmpty && !isProcessingCleanup else { return }
        
        isProcessingCleanup = true
        
        // Use the same encoded API key approach as in ModuleQuestionsStore
        let encodedApiKey = "c2stc3ZjYWNjdC11SnZYWERIRVVRbTBTMjVGa2pNWDdVN0lJWWF2Z1J0QjI5dWNROFlxOWtBTF9XbjNTdmJraDF2V0U4czhxdmlTbEFBSl94UlNOeVQzQmxia0ZKZFhGbGFYOFFoSlVvMjZiZzVIVzFpcV9jV3g5bmJXWFU1dl84ZVJSMEotUVNIZkFQd3kwVVp5bVowT0Iwb2NxTWw3QVNURDhja0E="
        
        guard let apiKeyData = Data(base64Encoded: encodedApiKey),
              let apiKey = String(data: apiKeyData, encoding: .utf8) else {
            print("Error: Failed to decode API key")
            isProcessingCleanup = false
            return
        }
        
        let headers = ["Content-Type": "application/json"]
        let parameters: [String: Any] = [
            "model": "gpt-4o",
            "messages": [
                ["role": "system", "content": "You are a helpful assistant. Clean up the following text by improving grammar, punctuation, and clarity without changing the meaning. But don't change any of the text core sentences and dont add new, just help me format it for an email"],
                ["role": "user", "content": responseText]
            ],
            "temperature": 0.7
        ]
        
        guard let postData = try? JSONSerialization.data(withJSONObject: parameters) else {
            isProcessingCleanup = false
            return
        }
        
        guard let url = URL(string: "https://api.openai.com/v1/chat/completions") else {
            isProcessingCleanup = false
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.allHTTPHeaderFields = headers
        request.httpBody = postData
        
        // Use the decoded API key
        request.allHTTPHeaderFields?["Authorization"] = "Bearer \(apiKey)"
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                defer { isProcessingCleanup = false }
                
                guard let data = data, error == nil else {
                    print("Error: \(error?.localizedDescription ?? "Unknown error")")
                    return
                }
                
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let choices = json["choices"] as? [[String: Any]],
                   let firstChoice = choices.first,
                   let message = firstChoice["message"] as? [String: Any],
                   let content = message["content"] as? String {
                    responseText = content
                } else {
                    print("Failed to parse API response")
                }
            }
        }
        
        task.resume()
    }
}

struct ModuleQuestionsView: View {
    let course: Course
    @StateObject private var store: ModuleQuestionsStore
    @Environment(AudioPlayer.self) private var audioPlayer
    @State private var showingTestAlert = false
    @State private var testSubmissionResult = false
    
    @State private var responseText = ""
    @State private var showingFeedback = false
    @State private var isContentCardsExpanded: Bool = false
    @State private var isResourceCardsExpanded: Bool = false
    @State private var isAudioPresenting: Bool = false
    
    init(course: Course) {
        self.course = course
        self._store = StateObject(wrappedValue: ModuleQuestionsStore(course: course))
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
                            .environment(audioPlayer)
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
                        // await testSubmitToSupabase()
                        // debug log share 
                        print("DEBUG: Share button pressed")
                        showingTestAlert = true
                    }
                }) {
                    Image(systemName: "square.and.arrow.up")
                }
            }
        }
        .alert("Share Test", isPresented: $showingTestAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(testSubmissionResult ? "Share successful!" : "Share failed. Check console for details.")
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