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

// Course row component
struct CourseListRow: View {
    let course: Course
    var onCourseSelected: (Course) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(course.code)
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
                Text("Difficulty: \(course.difficulty)/\(course.maxDifficulty)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Text(course.name)
                .font(.body)
                .foregroundColor(.primary)
            
            HStack {
                Text("Instructor: \(course.instructor)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
                Text("Required ELO: \(course.eloRequired)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Text("Category: \(course.category)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())  // Make the entire area tappable
        .onTapGesture {
            onCourseSelected(course)
        }
    }
}

// Profile View
struct ProfileView: View {
    var body: some View {
        VStack {
            Image(systemName: "person.circle.fill")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 100, height: 100)
                .foregroundColor(.blue)
                .padding()
            
            Text("User Profile")
                .font(.title)
                .fontWeight(.bold)
            
            Text("User information will be displayed here")
                .foregroundColor(.secondary)
                .padding()
            
            Spacer()
        }
        .navigationTitle("Profile")
    }
}

// Settings View
struct SettingsView: View {
    var body: some View {
        List {
            Section(header: Text("Account")) {
                HStack {
                    Image(systemName: "person.fill")
                    Text("Account Information")
                }
                HStack {
                    Image(systemName: "bell.fill")
                    Text("Notifications")
                }
            }
            
            Section(header: Text("Preferences")) {
                HStack {
                    Image(systemName: "paintbrush.fill")
                    Text("Appearance")
                }
                HStack {
                    Image(systemName: "lock.fill")
                    Text("Privacy")
                }
            }
            
            Section(header: Text("Support")) {
                HStack {
                    Image(systemName: "questionmark.circle.fill")
                    Text("Help & Feedback")
                }
                HStack {
                    Image(systemName: "info.circle.fill")
                    Text("About")
                }
            }
        }
        .navigationTitle("Settings")
    }
}

// Learning Tree View (former MainView content)
struct LearningTreeView: View {
    private let store = ChattStore.shared
    @State private var isPresenting = false
    @State private var courses: [Course] = []
    @State private var selectedCourse: Course?
    
    var body: some View {
        NavigationStack {
            List {
                Section(header: Text("My Email Course Modules").font(.headline)) {
                    ForEach(courses) { course in
                        CourseListRow(course: course, onCourseSelected: { course in
                            selectedCourse = course
                        })
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color(course.altRow ?
                                .systemGray5 : .systemGray6))
                    }
                }
                
                Section(header: Text("My Wordsmith Submissions").font(.headline)) {
                    ForEach(store.chatts) { chatt in
                        ChattListRow(chatt: chatt)
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color(chatt.altRow ?
                                .systemGray5 : .systemGray6))
                    }
                }
            }
            .listStyle(.plain)
            .refreshable {
                await store.getChatts()
            }
            .navigationTitle("Learning Tree")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement:.topBarTrailing) {
                    Button { 
                        Task {
                            await ChatterID.shared.open()
                            isPresenting.toggle()
                        }
                    } label: {
                        Image(systemName: "square.and.pencil")
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
                loadCourseData()
            }
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
        } catch {
            print("Error decoding JSON: \(error)")
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
    var body: some View {
        TabView {
            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person.fill")
                }
            
            LearningTreeView()
                .tabItem {
                    Label("Learning", systemImage: "book.fill")
                }
            
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
        }
    }
}

#Preview {
    MainView()
}
