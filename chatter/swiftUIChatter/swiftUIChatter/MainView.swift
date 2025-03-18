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
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Category title with icon
            HStack {
                Image(systemName: categoryIcon(for: category.name))
                    .foregroundColor(categoryColor(for: category.name))
                    .font(.headline)
                
                Text(category.name)
                    .font(.headline)
                    .foregroundColor(categoryColor(for: category.name))
                
                Spacer()
                
                // Module count badge
                Text("\(category.courses.count)")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(categoryColor(for: category.name).opacity(0.8))
                    .cornerRadius(12)
            }
            
            // Always show both metrics
            HStack(spacing: 12) {
                // Difficulty metric
                HStack(spacing: 4) {
                    Image(systemName: "bolt")
                        .foregroundColor(.blue)
                        .font(.caption)
                    Text("Difficulty: \(String(format: "%.1f", category.averageDifficulty))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // ELO metric
                HStack(spacing: 4) {
                    Image(systemName: "trophy")
                        .foregroundColor(.orange)
                        .font(.caption)
                    Text("Min ELO: \(category.minEloRequired)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            // Visual difficulty indicator
            difficultyIndicator(level: Int(category.averageDifficulty.rounded()))
                .padding(.top, 2)
        }
        .padding(.vertical, 4)
    }
    
    // Return appropriate icon for category
    private func categoryIcon(for category: String) -> String {
        switch category.lowercased() {
        case let name where name.contains("email"):
            return "envelope.fill"
        case let name where name.contains("copywriting"):
            return "doc.text.fill"
        case let name where name.contains("marketing"):
            return "megaphone.fill"
        case let name where name.contains("creative"):
            return "paintbrush.fill"
        case let name where name.contains("technical"):
            return "gear.fill"
        case let name where name.contains("social"):
            return "bubble.left.and.bubble.right.fill"
        default:
            return "book.fill"
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
        case let name where name.contains("social"):
            return .green
        default:
            return .indigo
        }
    }
    
    // Visual difficulty indicator
    private func difficultyIndicator(level: Int) -> some View {
        HStack(spacing: 3) {
            ForEach(1...5, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(index <= level ? categoryColor(for: category.name) : Color.secondary.opacity(0.2))
                    .frame(width: 16, height: 5)
            }
        }
    }
}

// Enhanced course row component with visual cues
struct EnhancedCourseListRow: View {
    let course: Course
    let sortOption: LearningTreeView.SortOption
    var onCourseSelected: (Course) -> Void
    
    var body: some View {
        HStack(spacing: 14) {
            // Left side - course icon based on difficulty
            ZStack {
                Circle()
                    .fill(difficultyColor().opacity(0.8))
                    .frame(width: 44, height: 44)
                
                Image(systemName: difficultyIcon())
                    .foregroundColor(.white)
                    .font(.system(size: 18))
            }
            
            // Middle - course info
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(course.code)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(4)
                    
                    Spacer()
                }
                
                Text(course.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                // Bottom row with metrics
                HStack {
                    // Instructor
                    HStack(spacing: 4) {
                        Image(systemName: "person.fill")
                            .foregroundColor(.secondary)
                            .font(.system(size: 10))
                        Text(course.instructor)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    // Metrics row - always show both metrics side by side
                    HStack(spacing: 8) {
                        // Difficulty visual meter
                        HStack(spacing: 1) {
                            ForEach(1...course.maxDifficulty, id: \.self) { index in
                                RoundedRectangle(cornerRadius: 1)
                                    .fill(index <= course.difficulty ? difficultyColor() : Color.secondary.opacity(0.2))
                                    .frame(width: 8, height: 8)
                            }
                        }
                        
                        // ELO requirement
                        HStack(spacing: 2) {
                            Image(systemName: "trophy")
                                .foregroundColor(.orange)
                                .font(.system(size: 9))
                            
                            Text("\(course.eloRequired)")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.orange)
                        }
                    }
                }
            }
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())  // Make the entire area tappable
        .onTapGesture {
            onCourseSelected(course)
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
            return "1.circle.fill"
        case 0.3..<0.6:
            return "2.circle.fill"
        case 0.6..<0.8:
            return "3.circle.fill"
        default:
            return "bolt.fill"
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
                // Sort picker
                Picker("Sort By", selection: $sortOption) {
                    ForEach(SortOption.allCases) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
                .pickerStyle(.segmented)
                .padding()
                .background(Color(.systemBackground))
                .onChange(of: sortOption) { _ in
                    sortCoursesBySelectedOption()
                }
                
                // Search field
                TextField("Search modules", text: $searchText)
                    .padding(8)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                    .padding(.horizontal)
                    .padding(.bottom)
                
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
            Section {
                ForEach(filteredCategories) { category in
                    VStack(spacing: 0) {
                        DisclosureGroup(
                            isExpanded: Binding(
                                get: { expandedCategories.contains(category.id) },
                                set: { isExpanded in
                                    if isExpanded {
                                        expandedCategories.insert(category.id)
                                    } else {
                                        expandedCategories.remove(category.id)
                                    }
                                }
                            ),
                            content: {
                                VStack(spacing: 2) {
                                    ForEach(category.courses) { course in
                                        EnhancedCourseListRow(
                                            course: course,
                                            sortOption: sortOption,
                                            onCourseSelected: { course in
                                                selectedCourse = course
                                            }
                                        )
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 6)
                                        .background(Color(course.altRow ?
                                            .systemGray6 : .systemGray5).opacity(0.6))
                                        .cornerRadius(8)
                                    }
                                }
                                .padding(.top, 8)
                            },
                            label: {
                                CategoryView(category: category, sortOption: sortOption)
                            }
                        )
                        .padding(.horizontal, 4)
                    }
                    .padding(.vertical, 4)
                }
            } header: {
                HStack {
                    Text("Course Categories")
                        .font(.headline)
                    Spacer()
                    Text("Sorted by: \(sortOption.rawValue)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.bottom, 8)
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
        .listStyle(.insetGrouped) // Change back to insetGrouped for better section separation
        .refreshable {
            await store.getChatts()
            loadCourseData()
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
