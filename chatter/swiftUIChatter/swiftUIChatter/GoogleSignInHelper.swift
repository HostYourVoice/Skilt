//
//  GoogleSignInHelper.swift
//  swiftUIChatter
//
//  Created by AI Assistant on 3/14/25.
//

import Foundation
import GoogleSignIn
import UIKit
import SwiftUI

class GoogleSignInHelper {
    static let shared = GoogleSignInHelper()
    private init() {}
    
    // Function to handle sign in
    func signIn(presentingViewController: UIViewController, completion: @escaping (Bool) -> Void) {
        // Configure the sign-in process
        let signInConfig = GIDConfiguration(clientID: getClientID())
        
        // Start the sign-in flow
        GIDSignIn.sharedInstance.signIn(
            withPresenting: presentingViewController,
            hint: nil,
            additionalScopes: ["https://www.googleapis.com/auth/userinfo.profile", "https://www.googleapis.com/auth/userinfo.email"]
        ) { signInResult, error in
            // Handle sign-in errors
            guard error == nil else {
                print("Error signing in with Google: \(error!.localizedDescription)")
                completion(false)
                return
            }
            
            // Make sure we have a valid sign-in result
            guard let signInResult = signInResult else {
                print("Error: Sign-in result is nil")
                completion(false)
                return
            }
            
            // Get user data
            let user = signInResult.user
            
            // Update UserProfile with Google user data
            UserProfile.shared.updateFromGoogleUser(user)
            
            // Notify success
            completion(true)
        }
    }
    
    // Sign out function
    func signOut() {
        GIDSignIn.sharedInstance.signOut()
        
        // Clear the user profile
        UserProfile.shared.clearProfile()
    }
    
    // Restore previous sign-in
    func restorePreviousSignIn(completion: @escaping (Bool) -> Void) {
        // Check user preference for automatic sign-in
        let shouldAutoSignIn = UserDefaults.standard.bool(forKey: "EnableAutoSignIn")
        
        // If auto sign-in is disabled, immediately return false
        if !shouldAutoSignIn {
            print("Auto sign-in is disabled in preferences")
            completion(false)
            return
        }
        
        // Otherwise proceed with normal restoration
        GIDSignIn.sharedInstance.restorePreviousSignIn { user, error in
            if let error = error {
                print("Error restoring sign-in: \(error.localizedDescription)")
                completion(false)
                return
            }
            
            if let user = user {
                // Update UserProfile with Google user data
                UserProfile.shared.updateFromGoogleUser(user)
                completion(true)
            } else {
                completion(false)
            }
        }
    }
    
    // Get client ID from Info.plist
    private func getClientID() -> String {
        guard let clientID = Bundle.main.infoDictionary?["GIDClientID"] as? String else {
            fatalError("GIDClientID not found in Info.plist")
        }
        return clientID
    }
}

// SwiftUI Extension to present Google Sign-In
extension View {
    func signInWithGoogle(completion: @escaping (Bool) -> Void) {
        // Get the top-most view controller
        guard let rootVC = UIApplication.shared.windows.first?.rootViewController else {
            print("No root view controller found")
            completion(false)
            return
        }
        
        // Present the sign-in flow
        GoogleSignInHelper.shared.signIn(presentingViewController: rootVC, completion: completion)
    }
} 