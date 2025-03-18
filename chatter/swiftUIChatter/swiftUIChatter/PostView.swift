//
//  PostView.swift
//  swiftUIChatter
//
//  Created by BlessedAmulya Parmar on 1/29/25.
//


import SwiftUI

struct PostView: View {
    @Binding var isPresented: Bool

    private let username = "amulya"
    @State private var message = "Some short sample text."
    
    @Environment(AudioPlayer.self) private var audioPlayer
    @State private var isAudioPresenting = false
    @State private var isSigninPresented = false
    @State private var showAlert = false
    @FocusState private var messageInFocus: Bool
    
    enum AlertType {
        case sendError, signinError
    }
    
    @State private var alertType = AlertType.sendError

    var body: some View {
        VStack {
            Text(username)
                .padding(.top, 30.0)
            TextEditor(text: $message)
                .padding(EdgeInsets(top: 10, leading: 18, bottom: 0, trailing: 4))
                .frame(minHeight: 80, maxHeight: 120)
                .focused($messageInFocus)
            Spacer().frame(maxHeight: .infinity)
        }
        .navigationTitle("Post")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement:.topBarTrailing) {
                SubmitButton()
            }
            ToolbarItem(placement: .bottomBar) {
                AudioButton(isPresenting: $isAudioPresenting)
            }
        }
        .fullScreenCover(isPresented: $isAudioPresenting) {
            AudioView(isPresented: $isAudioPresenting, autoPlay: false)
        }
        .sheet(isPresented: $isSigninPresented) {
            SigninView(isPresented: $isSigninPresented)
        }
        .onAppear {
            audioPlayer.setupRecorder()
            checkChatterID()
        }
        .contentShape(.rect)
        .onTapGesture {
            messageInFocus.toggle()
        }
    }
    
    private func checkChatterID() {
        // Check if ChatterID is valid, if not show SigninView
        if ChatterID.shared.id == nil {
            isSigninPresented = true
        }
    }

    @ViewBuilder
    private func SubmitButton() -> some View {
        @State var isDisabled: Bool = false
        
        Button {
            // Check for valid ChatterID first
            if ChatterID.shared.id == nil {
                alertType = .signinError
                showAlert = true
                return
            }
            
            isDisabled = true
            Task(priority: .background) {
                let result = await SubmissionStore.shared.postSubmission(Submission(username: username, 
                                                                    message: message, 
                                                                    audio: audioPlayer.audio?.base64EncodedString()))
                if result != nil {
                    await SubmissionStore.shared.getSubmissions()
                    isPresented.toggle()
                } else {
                    alertType = .sendError
                    showAlert = true
                }
            }
        } label: {
            Image(systemName: "paperplane")
        }
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.2 : 1)
        .alert(isPresented: $showAlert) {
            return Alert(title: Text(alertType == .sendError ? "Send failed" : "Signin failed"), message: Text(alertType == .sendError ? "Submission not posted" : "Please try again"), dismissButton: .cancel{
                isPresented.toggle()})
        }
    }
}

struct AudioButton: View {
    @Binding var isPresenting: Bool
    @Environment(AudioPlayer.self) private var audioPlayer

    var body: some View {        
        Button {
            isPresenting.toggle()
        } label: {
            if let _ = audioPlayer.audio {
                Image(systemName: "mic.fill")
                    .padding(EdgeInsets(top: 0, leading: 0, bottom: 20, trailing: 0))
                    .scaleEffect(1.5)
                    .foregroundColor(Color(.systemRed))
            } else {
                Image(systemName: "mic")
                    .padding(EdgeInsets(top: 0, leading: 0, bottom: 20, trailing: 0))
                    .scaleEffect(1.5)
                    .foregroundColor(Color(.systemGreen))
            }
        }   
    }
}

/* struct SigninView: View {
    @Binding var isPresented: Bool
    
    var body: some View {
        VStack {
            Text("Sign In")
                .font(.largeTitle)
                .padding()
            
            // Your sign-in implementation here
            // This would update ChatterID.shared when successful
            
            Button("Sign In") {
                // Simulate successful sign-in
                ChatterID.shared.id = "user123"
                ChatterID.shared.expiration = Date().addingTimeInterval(3600) // 1 hour from now
                isPresented = false
            }
            .padding()
            
            Button("Cancel") {
                isPresented = false
            }
            .padding()
        }
    }
} */

