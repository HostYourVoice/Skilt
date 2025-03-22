//
//  MainView.swift
//  swiftUIChatter
//
//  Created by BlessedAmulya Parmar TYG  on 1/29/25.
//

import SwiftUI

// Course models to parse JSON data
struct CourseData: Codable {
    let course: CourseInfo
}

struct CourseInfo: Codable {
    let id: String
    let title: String
    let categories: [CategoryInfo]
    let modules: [ModuleInfo]
    let metadata: MetadataInfo
}

struct CategoryInfo: Codable {
    let id: String
    let name: String
    let description: String
    let minEloRating: Int
    let baseEloGain: Int
}

struct ModuleInfo: Codable {
    let id: String
    let title: String
    let order: Int
    let category: String
    let difficulty: DifficultyInfo
    let requiredEloRating: Int
    let scenario: ScenarioInfo?
    let rubric: RubricInfo?
    // Other fields omitted for brevity
}

struct RubricInfo: Codable {
    let aiFeedbackPoints: [String]?
    let checklistItems: [ChecklistItemInfo]?
}

struct ChecklistItemInfo: Codable {
    let id: String
    let description: String
}

struct ScenarioInfo: Codable {
    let context: String
    let requirements: [String]
}

struct DifficultyInfo: Codable {
    let score: Int
    let scale: Int
    let factors: [String]
    let baseCompletionPoints: Int
    let bonusMultiplier: Double
}

struct MetadataInfo: Codable {
    let version: String
    let lastUpdated: String
    let totalModules: Int
    let estimatedCompletionTime: String
    // Other fields omitted for brevity
}

// Updated Course model
struct Course: Identifiable, Hashable {
    let id: UUID = UUID()
    let name: String
    let code: String
    let instructor: String
    let altRow: Bool
    let difficulty: Int
    let maxDifficulty: Int
    let eloRequired: Int
    let category: String
    let moduleId: String  // Added to reference back to the original module
    
    // Adding Hashable conformance
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: Course, rhs: Course) -> Bool {
        lhs.id == rhs.id
    }
}

// Adding a struct to represent a category with its courses
struct CategoryWithCourses: Identifiable {
    let id: String
    let name: String
    let description: String
    var courses: [Course]
    
    var averageDifficulty: Double {
        courses.isEmpty ? 0 : Double(courses.reduce(0) { $0 + $1.difficulty }) / Double(courses.count)
    }
    
    var minEloRequired: Int {
        courses.min(by: { $0.eloRequired < $1.eloRequired })?.eloRequired ?? 0
    }
}

// Category item in the tree view
struct CategoryView: View {
    let category: CategoryWithCourses
    let sortOption: LearningTreeView.SortOption
    let isExpanded: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Category title with icon
            HStack {
                Image(systemName: categoryIcon(for: category.name))
                    .foregroundColor(.white)
                    .padding(8)
                    .background(categoryColor(for: category.name))
                    .cornerRadius(10)
                    .font(.headline)
                
                Text(category.name)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                // Badge count
                ZStack {
                    Circle()
                        .fill(Color.secondary.opacity(0.2))
                        .frame(width: 30, height: 30)
                    
                    Text("\(category.courses.count)")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                }
                
                // Dropdown indicator inside the card
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .foregroundColor(categoryColor(for: category.name))
                    .font(.system(size: 16, weight: .semibold))
                    .animation(.spring(), value: isExpanded)
                    .padding(.leading, 4)
            }
            
            // Metrics row
            HStack(spacing: 20) {
                // Difficulty metric
                HStack(spacing: 4) {
                    Image(systemName: "bolt")
                        .foregroundColor(.blue)
                        .font(.footnote)
                    Text("Difficulty: \(String(format: "%.1f", category.averageDifficulty))")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
                
                // ELO metric
                HStack(spacing: 4) {
                    Image(systemName: "trophy")
                        .foregroundColor(.orange)
                        .font(.footnote)
                    Text("Min ELO: \(category.minEloRequired)")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            // Visual difficulty indicator
            HStack(spacing: 2) {
                ForEach(1...4, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 1)
                        .fill(index <= Int(category.averageDifficulty.rounded()) ? categoryColor(for: category.name) : Color.secondary.opacity(0.15))
                        .frame(width: 36, height: 5)
                }
            }
            .padding(.top, 4)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 8)
        .background(categoryColor(for: category.name).opacity(0.1))
        .cornerRadius(12)
    }
    
    // Return appropriate icon for category
    private func categoryIcon(for category: String) -> String {
        switch category.lowercased() {
        case let name where name.contains("email"):
            return "envelope"
        case let name where name.contains("copywriting"):
            return "doc.text"
        case let name where name.contains("marketing"):
            return "megaphone"
        case let name where name.contains("creative"):
            return "paintbrush"
        case let name where name.contains("technical"):
            return "gear"
        case let name where name.contains("social") || name.contains("network"):
            return "person.2"
        default:
            return "book"
        }
    }
    
    // Return color for category
    private func categoryColor(for category: String) -> Color {
        switch category.lowercased() {
        case let name where name.contains("email"):
            return .blue
        case let name where name.contains("copywriting"):
            return .purple
        case let name where name.contains("marketing"):
            return .orange
        case let name where name.contains("creative"):
            return .pink
        case let name where name.contains("technical"):
            return .gray
        case let name where name.contains("social") || name.contains("network"):
            return .indigo
        default:
            return .teal
        }
    }
}

// Enhanced course row component with visual cues
struct EnhancedCourseListRow: View {
    let course: Course
    let sortOption: LearningTreeView.SortOption
    var onCourseSelected: (Course) -> Void
    
    var body: some View {
        let isLocked = UserProfile.shared.eloRating < course.eloRequired
        let userProfile = UserProfile.shared
        let score = userProfile.userExerciseScores[course.moduleId]
        let scoreText: String? = {
            guard let score = score else {
                return nil
            }
            return "Previous Score: \(score)"
        }()

        HStack(spacing: 16) {
            // Left side - course icon based on difficulty or completion
            ZStack {
                if let score = score {
                    Circle()
                        .fill(Color.green.opacity(0.9))
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: "checkmark")
                        .foregroundColor(.white)
                        .font(.system(size: 16))
                } else {
                    Circle()
                        .fill(isLocked ? Color.gray.opacity(0.5) : difficultyColor().opacity(0.9))
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: isLocked ? "lock.fill" : difficultyIcon())
                        .foregroundColor(.white)
                        .font(.system(size: 16))
                }
            }
            
            // Middle - course info
            VStack(alignment: .leading, spacing: 4) {
                Text(course.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(isLocked ? .gray : .primary)
                
                HStack {
                    // Course code
                    Text(course.code)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    // Instructor in smaller text
                    HStack(spacing: 4) {
                        Text(course.instructor)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                
                HStack(spacing: 16) {
                    // Difficulty indicator with text
                    HStack(spacing: 6) {
                        Image(systemName: "bolt")
                            .foregroundColor(.blue)
                            .font(.caption2)
                            
                        Text("Difficulty: \(course.difficulty)/\(course.maxDifficulty)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    // ELO indicator with text
                    HStack(spacing: 6) {
                        Image(systemName: "trophy")
                            .foregroundColor(.orange)
                            .font(.caption2)
                            
                        Text("Min ELO: \(course.eloRequired)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Score indicator
                if let scoreText = scoreText {
                    Text(scoreText)
                        .font(.caption2)
                        .foregroundColor(.green)
                }
            }
            
            // Right side - chevron indicator
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 10)
        .background(
            isLocked ? Color.gray.opacity(0.1) :
            (score != nil ? Color.green.opacity(0.1) : Color(.systemBackground))
        )
        .cornerRadius(10)
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
        .contentShape(Rectangle())  // Make the entire area tappable
        .onTapGesture {
            if !isLocked {
                onCourseSelected(course)
            }
        }
    }
    
    // Color based on difficulty
    private func difficultyColor() -> Color {
        let ratio = Double(course.difficulty) / Double(course.maxDifficulty)
        switch ratio {
        case 0..<0.3:
            return .green
        case 0.3..<0.6:
            return .blue
        case 0.6..<0.8:
            return .orange
        default:
            return .red
        }
    }
    
    // Icon based on difficulty
    private func difficultyIcon() -> String {
        let ratio = Double(course.difficulty) / Double(course.maxDifficulty)
        switch ratio {
        case 0..<0.3:
            return "1.circle"
        case 0.3..<0.6:
            return "2.circle" 
        case 0.6..<0.8:
            return "3.circle"
        default:
            return "bolt"
        }
    }
}

// Profile View
struct ProfileView: View {
    @State private var userProfile = UserProfile.shared
    @State private var store = SubmissionStore.shared
    @State private var showGoogleSignIn = false
    @State private var presentingViewControllerHolder: UIViewController?
    @State private var fireAnimation = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Profile header with avatar
                VStack(spacing: 16) {
                    // Profile picture - show user's picture if available, otherwise show placeholder
                    if let profileURL = userProfile.profilePictureURL {
                        AsyncImage(url: profileURL) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 100, height: 100)
                                .clipShape(Circle())
                        } placeholder: {
                            ProgressView()
                                .frame(width: 100, height: 100)
                        }
                    } else {
                        Image(systemName: "person.circle.fill")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 100, height: 100)
                            .foregroundColor(.blue)
                    }
                    
                    // Display name
                    Text(userProfile.displayName)
                        .font(.title)
                        .fontWeight(.bold)
                    
                    // Email if available
                    if let email = userProfile.email {
                        Text(email)
                            .foregroundColor(.secondary)
                    }
                    
                    // Sign in/out button
                    if userProfile.isLoggedIn {
                        Button(action: {
                            // Use GoogleSignInHelper to sign out
                            GoogleSignInHelper.shared.signOut()
                        }) {
                            Text("Sign Out")
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                                .frame(maxWidth: 200)
                                .padding(.vertical, 10)
                                .background(Color.red)
                                .cornerRadius(8)
                        }
                    } else {
                        Button(action: {
                            showGoogleSignIn = true
                        }) {
                            HStack {
                                Image(systemName: "g.circle.fill")
                                    .foregroundColor(.blue)
                                Text("Sign in with Google")
                                    .fontWeight(.medium)
                            }
                            .frame(maxWidth: 200)
                            .padding(.vertical, 10)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                        }
                    }
                }
                .padding(.top, 40)
                
                // Progress section
                VStack(alignment: .leading, spacing: 14) {
                    Text("My Progress")
                        .font(.headline)
                    
                    HStack(spacing: 20) {
                        // ELO Rating circle
                        VStack {
                            ZStack {
                                Circle()
                                    .stroke(Color.blue.opacity(0.2), lineWidth: 10)
                                    .frame(width: 80, height: 80)
                                
                                Circle()
                                    .trim(from: 0, to: 0.7)
                                    .stroke(Color.blue, lineWidth: 10)
                                    .frame(width: 80, height: 80)
                                    .rotationEffect(.degrees(-90))
                                
                                VStack(spacing: 2) {
                                    Text("\(userProfile.eloRating)")
                                        .font(.title3)
                                        .fontWeight(.bold)
                                    
                                    Text("ELO")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            Text("Rating")
                                .font(.caption)
                                .padding(.top, 6)
                        }
                        
                        // Modules completed circle
                        VStack {
                            ZStack {
                                Circle()
                                    .stroke(Color.green.opacity(0.2), lineWidth: 10)
                                    .frame(width: 80, height: 80)
                                
                                let progress = Float(userProfile.completedExercisesCount) / Float(userProfile.totalModules)
                                Circle()
                                    .trim(from: 0, to: CGFloat(progress))
                                    .stroke(Color.green, lineWidth: 10)
                                    .frame(width: 80, height: 80)
                                    .rotationEffect(.degrees(-90))
                                
                                VStack(spacing: 2) {
                                    Text("\(userProfile.completedExercisesCount)/\(userProfile.totalModules)")
                                        .font(.title3)
                                        .fontWeight(.bold)
                                    
                                    Text("Done")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            Text("Modules")
                                .font(.caption)
                                .padding(.top, 6)
                        }
                        
                        // Streak circle with fire animation
                        VStack {
                            ZStack {
                                // Animated gradient background
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            gradient: Gradient(colors: [.orange, .red]),
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 80, height: 80)
                                    .opacity(0.2)
                                
                                // Fire stroke with varying width for flame effect
                                Circle()
                                    .trim(from: 0, to: 0.8)
                                    .stroke(
                                        AngularGradient(
                                            gradient: Gradient(colors: [.yellow, .orange, .red]),
                                            center: .center,
                                            startAngle: .degrees(0),
                                            endAngle: .degrees(360)
                                        ),
                                        style: StrokeStyle(lineWidth: 10, lineCap: .round)
                                    )
                                    .frame(width: 80, height: 80)
                                    .rotationEffect(.degrees(-90))
                                    .shadow(color: .orange.opacity(0.3), radius: 5, x: 0, y: 0)
                                
                                // Flames around the circle (visible when streak is high)
                                if store.currentStreak >= 5 {
                                    ForEach(0..<8) { i in
                                        Image(systemName: "flame.fill")
                                            .foregroundColor(.orange)
                                            .font(.system(size: 12))
                                            .offset(
                                                x: 45 * cos(Double(i) * .pi / 4),
                                                y: 45 * sin(Double(i) * .pi / 4)
                                            )
                                            .opacity(fireAnimation ? 0.8 : 0.4)
                                            .scaleEffect(fireAnimation ? 1.2 : 0.8)
                                    }
                                    .animation(
                                        Animation.easeInOut(duration: 1.5)
                                            .repeatForever(autoreverses: true),
                                        value: fireAnimation
                                    )
                                    .onAppear {
                                        fireAnimation = true
                                    }
                                }
                                
                                // Streak counter
                                VStack(spacing: 1) {
                                    Text("\(store.currentStreak)")
                                        .font(.title3)
                                        .fontWeight(.bold)
                                        .foregroundColor(store.currentStreak > 0 ? .primary : .secondary)
                                    
                                    Text("days")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                // Fire emblem for active streak
                                if store.currentStreak > 0 {
                                    Image(systemName: "flame.fill")
                                        .foregroundColor(.orange)
                                        .font(.system(size: 16))
                                        .offset(y: -28)
                                        .opacity(fireAnimation ? 1.0 : 0.7)
                                        .scaleEffect(fireAnimation ? 1.1 : 0.9)
                                        .animation(
                                            Animation.easeInOut(duration: 1.0)
                                                .repeatForever(autoreverses: true),
                                            value: fireAnimation
                                        )
                                }
                                
                                // Streak freeze indicator
                                if userProfile.streakFreeze > 0 {
                                    HStack(spacing: 1) {
                                        Image(systemName: "snowflake")
                                            .foregroundColor(.blue)
                                            .font(.system(size: 10))
                                        
                                        Text("\(userProfile.streakFreeze)")
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundColor(.blue)
                                    }
                                    .padding(4)
                                    .background(Color.white.opacity(0.8))
                                    .cornerRadius(10)
                                    .offset(x: 30, y: 30)
                                }
                            }
                            
                            // Streak label with dynamic styling
                            HStack(spacing: 2) {
                                Text("Streak")
                                    .font(.caption)
                                
                                if store.currentStreak >= 7 {
                                    Image(systemName: "checkmark.seal.fill")
                                        .foregroundColor(.orange)
                                        .font(.system(size: 10))
                                }
                            }
                            .padding(.top, 6)
                        }
                        .onTapGesture {
                            // Just for fun - add streak freeze on tap in preview/test mode
                            #if DEBUG
                            userProfile.addStreakFreeze()
                            #endif
                        }
                    }
                    
                    // Longest streak badge
                    if store.largestStreak > 0 {
                        HStack {
                            Spacer()
                            
                            Text("Longest streak: \(store.largestStreak) days")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Color(.systemGray6))
                                .cornerRadius(10)
                            
                            Spacer()
                        }
                        .padding(.top, 8)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
                .padding(.horizontal)
                
                // ChatterID Section
                VStack(alignment: .leading, spacing: 14) {
                    Text("ChatterID Information")
                        .font(.headline)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        if let chatterId = userProfile.chatterId {
                            HStack {
                                Text("ChatterID:")
                                    .fontWeight(.medium)
                                
                                Text(chatterId)
                                    .foregroundColor(.secondary)
                                
                                Spacer()
                                
                                Button(action: {
                                    UIPasteboard.general.string = chatterId
                                }) {
                                    Image(systemName: "doc.on.doc")
                                        .foregroundColor(.blue)
                                }
                            }
                            
                            HStack {
                                Text("Expires:")
                                    .fontWeight(.medium)
                                
                                Text(userProfile.chatterIdExpiration, style: .date)
                                    .foregroundColor(.secondary)
                            }
                        } else {
                            Text("No ChatterID available. Please sign in.")
                                .foregroundColor(.secondary)
                                .italic()
                        }
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(8)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
                .padding(.horizontal)
                
                Spacer()
            }
        }
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: showGoogleSignIn) { _, newValue in
            if newValue {
                // Implement Google Sign-In
                handleGoogleSignIn()
            }
        }
        .onAppear {
            // Refresh submissions to update streak when profile view appears
            Task {
                await store.getSubmissions()
            }
            
            // Just for testing/preview - simulate activity to update streak
            #if DEBUG
            userProfile.recordActivity()
            #endif
        }
    }
    
    private func handleGoogleSignIn() {
        showGoogleSignIn = false
        
        // Create a temporary UIViewController to act as the presenting controller
        let hostingController = UIHostingController(rootView: EmptyView())
        
        // Find the root view controller
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootViewController = window.rootViewController {
            
            // Add the temporary controller as a child of the root
            rootViewController.addChild(hostingController)
            rootViewController.view.addSubview(hostingController.view)
            hostingController.view.frame = .zero
            hostingController.didMove(toParent: rootViewController)
            
            // Store the reference to remove it later
            self.presentingViewControllerHolder = hostingController
            
            // Use the GoogleSignInHelper
            GoogleSignInHelper.shared.signIn(presentingViewController: rootViewController) { success in
                // Remove the temporary controller
                hostingController.willMove(toParent: nil)
                hostingController.view.removeFromSuperview()
                hostingController.removeFromParent()
                self.presentingViewControllerHolder = nil
                
                // Handle sign-in result if needed
                if success {
                    print("Successfully signed in with Google")
                } else {
                    print("Failed to sign in with Google")
                }
            }
        }
    }
}

// Empty view for hosting controller
struct EmptyView: View {
    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
    }
}

// Settings View
struct SettingsView: View {
    var body: some View {
        List {
            Section(header: Text("Account").textCase(.uppercase)) {
                NavigationLink(destination: Text("Account Information")) {
                    HStack {
                        Image(systemName: "person.fill")
                            .foregroundColor(.blue)
                            .frame(width: 26)
                        Text("Account Information")
                    }
                }
                
                NavigationLink(destination: Text("Notifications Settings")) {
                    HStack {
                        Image(systemName: "bell.fill")
                            .foregroundColor(.orange)
                            .frame(width: 26)
                        Text("Notifications")
                        
                        Spacer()
                        
                        Text("On")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                NavigationLink(destination: Text("Preferences")) {
                    HStack {
                        Image(systemName: "hand.tap.fill")
                            .foregroundColor(.green)
                            .frame(width: 26)
                        Text("Preferences")
                    }
                }
            }
            
            Section(header: Text("Appearance").textCase(.uppercase)) {
                NavigationLink(destination: Text("Theme Settings")) {
                    HStack {
                        Image(systemName: "paintbrush.fill")
                            .foregroundColor(.purple)
                            .frame(width: 26)
                        Text("Theme")
                        
                        Spacer()
                        
                        Text("System")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                NavigationLink(destination: Text("Privacy Settings")) {
                    HStack {
                        Image(systemName: "lock.fill")
                            .foregroundColor(.gray)
                            .frame(width: 26)
                        Text("Privacy")
                    }
                }
            }
            
            Section(header: Text("Support").textCase(.uppercase)) {
                NavigationLink(destination: Text("Help & Feedback")) {
                    HStack {
                        Image(systemName: "questionmark.circle.fill")
                            .foregroundColor(.blue)
                            .frame(width: 26)
                        Text("Help & Feedback")
                    }
                }
                
                NavigationLink(destination: Text("About App")) {
                    HStack {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(.teal)
                            .frame(width: 26)
                        Text("About")
                        
                        Spacer()
                        
                        Text("v1.0.0")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// Learning Tree View (former MainView content)
struct LearningTreeView: View {
    private let store = SubmissionStore.shared
    @State private var isPresenting = false
    @State private var courses: [Course] = []
    @State private var categorizedCourses: [CategoryWithCourses] = []
    @State private var selectedCourse: Course?
    @State private var sortOption: SortOption = .difficulty
    @State private var expandedCategories: Set<String> = []
    @State private var searchText = ""
    
    enum SortOption: String, CaseIterable, Identifiable {
        case difficulty = "Difficulty"
        case eloRating = "ELO Rating"
        case name = "Name"
        
        var id: String { self.rawValue }
    }
    
    var filteredCategories: [CategoryWithCourses] {
        if searchText.isEmpty {
            return categorizedCourses
        } else {
            return categorizedCourses.map { category in
                var filtered = category
                filtered.courses = category.courses.filter { course in
                    course.name.lowercased().contains(searchText.lowercased()) ||
                    course.code.lowercased().contains(searchText.lowercased()) ||
                    course.category.lowercased().contains(searchText.lowercased())
                }
                return filtered
            }.filter { !$0.courses.isEmpty }
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search field
                TextField("Search modules", text: $searchText)
                    .padding(10)
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                    .padding(.horizontal)
                    .padding(.top, 10)
                    .padding(.bottom, 10)
                
                // Course tree
                if filteredCategories.isEmpty {
                    contentUnavailableView
                } else {
                    courseTreeView
                }
            }
            .navigationTitle("Learning Tree")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Text("Wordsmith")
                        .font(.headline)
                        .foregroundColor(.primary)
                }
                
                ToolbarItem(placement:.topBarTrailing) {
                    if UserProfile.shared.isLoggedIn {
                        // Show user is logged in
                        NavigationLink(destination: ProfileView()) {
                            if let profileURL = UserProfile.shared.profilePictureURL {
                                AsyncImage(url: profileURL) { image in
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 30, height: 30)
                                        .clipShape(Circle())
                                } placeholder: {
                                    Image(systemName: "person.circle.fill")
                                        .foregroundColor(.blue)
                                }
                            } else {
                                Image(systemName: "person.circle.fill")
                                    .foregroundColor(.blue)
                            }
                        }
                    } else {
                        Button { 
                            Task {
                                await ChatterID.shared.open()
                                isPresenting.toggle()
                            }
                        } label: {
                            Text("Sign In")
                                .fontWeight(.medium)
                                .foregroundColor(.blue)
                        }
                    }
                }
            }
            .navigationDestination(isPresented: $isPresenting) {
                PostView(isPresented: $isPresenting)
            }
            .navigationDestination(item: $selectedCourse) { course in
                ModuleQuestionsView(course: course)
            }
            .onAppear {
                print("DEBUG: LearningTreeView.body appeared")
                loadCourseData()
                
                // Force a refresh of submissions data when view appears
                Task {
                    print("DEBUG: Triggering refresh of submissions data on view appear")
                    await store.getSubmissions()
                }
            }
        }
    }
    
    // View to show when no content matches search
    private var contentUnavailableView: some View {
        VStack(spacing: 20) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            
            Text("No Modules Found")
                .font(.title2)
                .fontWeight(.bold)
            
            if !searchText.isEmpty {
                Text("Try searching with different keywords")
                    .foregroundColor(.secondary)
            } else {
                Text("There are no modules available")
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
    
    // Main course tree view
    private var courseTreeView: some View {
        List {
            // Header section for categories
            Section {
                ForEach(filteredCategories) { category in
                    VStack(spacing: 0) {
                        let isExpanded = expandedCategories.contains(category.id)
                        
                        // Custom category header - now fully tappable
                        CategoryView(category: category, sortOption: sortOption, isExpanded: isExpanded)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                withAnimation {
                                    if isExpanded {
                                        expandedCategories.remove(category.id)
                                    } else {
                                        expandedCategories.insert(category.id)
                                    }
                                }
                            }
                        
                        // Content view that shows when expanded
                        if isExpanded {
                            VStack(spacing: 8) {
                                ForEach(category.courses) { course in
                                    EnhancedCourseListRow(
                                        course: course,
                                        sortOption: sortOption,
                                        onCourseSelected: { course in
                                            selectedCourse = course
                                        }
                                    )
                                }
                            }
                            .padding(.top, 12)
                            .padding(.bottom, 4)
                            .padding(.horizontal, 4)
                            .background(Color(.systemGroupedBackground))
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }
                    .padding(.vertical, 2)
                }
            } header: {
                HStack(spacing: 0) {
                    Text("MODULE CATEGORIES")
                        .textCase(.uppercase)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    // Sort dropdown menu
                    Menu {
                        ForEach(SortOption.allCases) { option in
                            Button(action: {
                                sortOption = option
                                sortCoursesBySelectedOption()
                            }) {
                                HStack {
                                    Text(option.rawValue)
                                    
                                    if sortOption == option {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.blue)
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text("SORTED BY:")
                                .font(.caption2)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)
                            
                            Text(sortOption.rawValue.uppercased())
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.blue)
                            
                            Image(systemName: "chevron.down")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                    }
                }
                .listRowInsets(EdgeInsets(top: 16, leading: 16, bottom: 8, trailing: 16))
            }
            
            // Submissions section
            Section {
                if store.submissions.isEmpty {
                    Text("No submissions available")
                        .foregroundColor(.secondary)
                        .italic()
                        .padding()
                        .onAppear {
                            print("DEBUG: Submissions section is empty - no data available")
                        }
                } else {
                    ForEach(store.submissions) { submission in
                        SubmissionListRow(submission: submission)
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color(submission.altRow ?
                                .systemGray5 : .systemGray6))
                    }
                    .onAppear {
                        print("DEBUG: ForEach in submissions section has \(store.submissions.count) items")
                    }
                }
            } header: {
                Text("MY WORDSMITH SUBMISSIONS")
                    .textCase(.uppercase)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                    .listRowInsets(EdgeInsets(top: 16, leading: 16, bottom: 8, trailing: 16))
            }
        }
        .listStyle(GroupedListStyle())
        .environment(\.defaultMinListRowHeight, 0) // Allow for more compact rows when needed
        .listSectionSpacing(16) // Add spacing between sections
        .refreshable {
            print("DEBUG: Refreshable action triggered - fetching new data")
            await store.getSubmissions()
            loadCourseData()
        }
        .onAppear {
            print("DEBUG: courseTreeView appeared - store has \(store.submissions.count) submissions")
        }
    }
    
    private func loadCourseData() {
        guard let url = Bundle.main.url(forResource: "CoursesTYG", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            print("Error loading JSON file")
            return
        }
        
        do {
            let decoder = JSONDecoder()
            let courseData = try decoder.decode(CourseData.self, from: data)
            
            // Create instructor names using category names
            let categoryMap = Dictionary(uniqueKeysWithValues: courseData.course.categories.map { ($0.id, $0.name) })
            
            // Get category descriptions
            let categoryDescriptions = Dictionary(uniqueKeysWithValues: courseData.course.categories.map { 
                ($0.id, $0.description) 
            })
            
            // Convert modules to Course objects
            courses = courseData.course.modules.enumerated().map { index, module in
                let categoryName = categoryMap[module.category] ?? "Unknown"
                let instructor = "Prof. " + categoryName.split(separator: " ").first!
                return Course(
                    name: module.title,
                    code: moduleCodeFromID(module.id),
                    instructor: String(instructor),
                    altRow: index % 2 == 1,
                    difficulty: module.difficulty.score,
                    maxDifficulty: module.difficulty.scale,
                    eloRequired: module.requiredEloRating,
                    category: categoryName,
                    moduleId: module.id
                )
            }
            
            // Group courses by category
            let groupedCourses = Dictionary(grouping: courses, by: { $0.category })
            
            // Create CategoryWithCourses objects
            categorizedCourses = courseData.course.categories.map { category in
                let categoryName = category.name
                let coursesInCategory = groupedCourses[categoryName] ?? []
                return CategoryWithCourses(
                    id: category.id,
                    name: categoryName,
                    description: category.description,
                    courses: coursesInCategory
                )
            }
            
            // Sort according to the selected option
            sortCoursesBySelectedOption()
            
            // Auto-expand categories with few courses
            expandedCategories = Set(categorizedCourses
                .filter { $0.courses.count < 3 }
                .map { $0.id })
            
        } catch {
            print("Error decoding JSON: \(error)")
        }
    }
    
    private func sortCoursesBySelectedOption() {
        // Sort courses within each category
        for i in 0..<categorizedCourses.count {
            switch sortOption {
            case .difficulty:
                categorizedCourses[i].courses.sort { $0.difficulty > $1.difficulty }
            case .eloRating:
                categorizedCourses[i].courses.sort { $0.eloRequired > $1.eloRequired }
            case .name:
                categorizedCourses[i].courses.sort { $0.name < $1.name }
            }
        }
        
        // Sort categories
        switch sortOption {
        case .difficulty:
            categorizedCourses.sort { $0.averageDifficulty > $1.averageDifficulty }
        case .eloRating:
            categorizedCourses.sort { $0.minEloRequired > $1.minEloRequired }
        case .name:
            categorizedCourses.sort { $0.name < $1.name }
        }
    }
    
    // Generate course code from module ID
    private func moduleCodeFromID(_ id: String) -> String {
        let components = id.split(separator: "-")
        let firstLetters = components.map { String($0.prefix(1).uppercased()) }.joined()
        return "MOD\(firstLetters)\(Int.random(in: 100...999))"
    }
}

struct MainView: View {
    @State private var selectedTab = 1  // Default to Learning tab
    @State private var isRestoringSignIn = true
    
    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                ProfileView()
            }
            .tag(0)
            .tabItem {
                Image(systemName: "person")
                Text("Profile")
            }
            
            NavigationStack {
                LearningTreeView()
            }
            .tag(1)
            .tabItem {
                Image(systemName: "book")
                Text("Learning")
            }
            
            NavigationStack {
                SettingsView()
            }
            .tag(2)
            .tabItem {
                Image(systemName: "gearshape")
                Text("Settings")
            }
        }
        .onAppear {
            // Tab bar customization
            let tabBarAppearance = UITabBarAppearance()
            tabBarAppearance.configureWithOpaqueBackground()
            tabBarAppearance.backgroundColor = UIColor.systemBackground
            
            // Avoid images being too large or text overlapping
            let itemAppearance = UITabBarItemAppearance(style: .stacked)
            
            // Normal state - smaller image, reduced spacing
            itemAppearance.normal.iconColor = UIColor.systemGray
            itemAppearance.normal.titleTextAttributes = [
                NSAttributedString.Key.font: UIFont.systemFont(ofSize: 10, weight: .regular)
            ]
            
            // Selected state - better highlight and spacing
            itemAppearance.selected.iconColor = UIColor.systemBlue
            itemAppearance.selected.titleTextAttributes = [
                NSAttributedString.Key.font: UIFont.systemFont(ofSize: 10, weight: .semibold),
                NSAttributedString.Key.foregroundColor: UIColor.systemBlue
            ]
            
            // Apply styles
            tabBarAppearance.stackedLayoutAppearance = itemAppearance
            tabBarAppearance.inlineLayoutAppearance = itemAppearance
            tabBarAppearance.compactInlineLayoutAppearance = itemAppearance
            
            UITabBar.appearance().standardAppearance = tabBarAppearance
            
            // For bottom safe area (iPhone X and later)
            if #available(iOS 15.0, *) {
                UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
            }
            
            // Restore previous sign-in
            if isRestoringSignIn {
                GoogleSignInHelper.shared.restorePreviousSignIn { success in
                    isRestoringSignIn = false
                    if success {
                        print("Successfully restored Google Sign-In")
                    } else {
                        // Restore ChatterID from keychain
                        Task {
                            await ChatterID.shared.open()
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    MainView()
}


