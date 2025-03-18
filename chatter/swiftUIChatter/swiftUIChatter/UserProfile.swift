//
//  UserProfile.swift
//  swiftUIChatter
//
//  Created by AI Assistant on 3/5/25.
//

import Foundation
import SwiftUI
import GoogleSignIn

@Observable
final class UserProfile {
    static let shared = UserProfile() // Singleton instance
    private init() {
        loadFromUserDefaults()
    }
    
    // User profile data
    private(set) var displayName: String = "Anonymous User"
    private(set) var email: String?
    private(set) var profilePictureURL: URL?
    private(set) var isLoggedIn: Bool = false
    private(set) var userId: String?
    private(set) var givenName: String?
    private(set) var familyName: String?
    
    // ChatterID integration
    var chatterId: String? {
        ChatterID.shared.id
    }
    
    var chatterIdExpiration: Date {
        ChatterID.shared.expiration
    }
    
    // Google Auth Token (For backend authentication)
    private(set) var idToken: String?
    
    // Additional stats
    private(set) var eloRating: Int = 1200
    private(set) var completedModules: Int = 0
    private(set) var totalModules: Int = 20
    
    // Update user profile with Google sign-in data
    func updateProfile(name: String?, email: String?, profilePictureURL: URL?, userId: String?, givenName: String? = nil, familyName: String? = nil, idToken: String? = nil) {
        self.displayName = name ?? "Anonymous User"
        self.email = email
        self.profilePictureURL = profilePictureURL
        self.userId = userId
        self.givenName = givenName
        self.familyName = familyName
        self.idToken = idToken
        self.isLoggedIn = true
        
        saveToUserDefaults()
    }
    
    // Update from Google Sign-In
    func updateFromGoogleUser(_ googleUser: GIDGoogleUser) {
        let email = googleUser.profile?.email
        let fullName = googleUser.profile?.name
        let givenName = googleUser.profile?.givenName
        let familyName = googleUser.profile?.familyName
        let profilePicURL = googleUser.profile?.imageURL(withDimension: 320)
        let userId = googleUser.userID
        
        // Get ID token for secure backend communication
        let idToken = googleUser.idToken?.tokenString
        
        // Update UserID in ChatterID if needed
        if let userId = userId {
            ChatterID.shared.id = userId
            // Set expiration to 30 days from now
            ChatterID.shared.expiration = Date().addingTimeInterval(30 * 24 * 60 * 60)
            
            // Save to keychain
            Task {
                await ChatterID.shared.save()
            }
        }
        
        // Update profile
        updateProfile(
            name: fullName,
            email: email,
            profilePictureURL: profilePicURL,
            userId: userId,
            givenName: givenName,
            familyName: familyName,
            idToken: idToken
        )
    }
    
    // Update user stats
    func updateStats(eloRating: Int? = nil, completedModules: Int? = nil, totalModules: Int? = nil) {
        if let eloRating = eloRating {
            self.eloRating = eloRating
        }
        
        if let completedModules = completedModules {
            self.completedModules = completedModules
        }
        
        if let totalModules = totalModules {
            self.totalModules = totalModules
        }
        
        saveToUserDefaults()
    }
    
    // Clear profile data on logout
    func clearProfile() {
        displayName = "Anonymous User"
        email = nil
        profilePictureURL = nil
        isLoggedIn = false
        userId = nil
        givenName = nil
        familyName = nil
        idToken = nil
        
        // Clear ChatterID
        Task {
            ChatterID.shared.id = nil
            ChatterID.shared.expiration = Date(timeIntervalSince1970: 0.0)
            await ChatterID.shared.delete()
        }
        
        // Keep stats for anonymous user
        saveToUserDefaults()
    }
    
    // Save profile to UserDefaults
    private func saveToUserDefaults() {
        let userDefaults = UserDefaults.standard
        
        userDefaults.set(displayName, forKey: "userProfile_displayName")
        userDefaults.set(email, forKey: "userProfile_email")
        userDefaults.set(profilePictureURL?.absoluteString, forKey: "userProfile_profilePictureURL")
        userDefaults.set(isLoggedIn, forKey: "userProfile_isLoggedIn")
        userDefaults.set(userId, forKey: "userProfile_userId")
        userDefaults.set(givenName, forKey: "userProfile_givenName")
        userDefaults.set(familyName, forKey: "userProfile_familyName")
        userDefaults.set(idToken, forKey: "userProfile_idToken")
        userDefaults.set(eloRating, forKey: "userProfile_eloRating")
        userDefaults.set(completedModules, forKey: "userProfile_completedModules")
        userDefaults.set(totalModules, forKey: "userProfile_totalModules")
    }
    
    // Load profile from UserDefaults
    private func loadFromUserDefaults() {
        let userDefaults = UserDefaults.standard
        
        displayName = userDefaults.string(forKey: "userProfile_displayName") ?? "Anonymous User"
        email = userDefaults.string(forKey: "userProfile_email")
        
        if let urlString = userDefaults.string(forKey: "userProfile_profilePictureURL") {
            profilePictureURL = URL(string: urlString)
        }
        
        isLoggedIn = userDefaults.bool(forKey: "userProfile_isLoggedIn")
        userId = userDefaults.string(forKey: "userProfile_userId")
        givenName = userDefaults.string(forKey: "userProfile_givenName")
        familyName = userDefaults.string(forKey: "userProfile_familyName")
        idToken = userDefaults.string(forKey: "userProfile_idToken")
        
        eloRating = userDefaults.integer(forKey: "userProfile_eloRating")
        if eloRating == 0 { eloRating = 1200 } // Default value if not set
        
        completedModules = userDefaults.integer(forKey: "userProfile_completedModules")
        totalModules = userDefaults.integer(forKey: "userProfile_totalModules")
        if totalModules == 0 { totalModules = 20 } // Default value if not set
    }
} 