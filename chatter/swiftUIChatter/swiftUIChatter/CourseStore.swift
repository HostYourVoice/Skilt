import Foundation
import Observation

// Struct to hold submission data
struct ModuleSubmission: Codable {
    let totalSubmissions: Int
    let averageScorePercentage: Double
}

@Observable
class CourseStore {
    static let shared = CourseStore()
    
    private(set) var courseData: CourseData?
    private(set) var isLoading = false
    private(set) var error: Error?
    
    // Track submissions for each module
    private var moduleSubmissions: [String: ModuleSubmission] = [:]
    
    private init() {
        loadJSONData()
        loadSubmissions()
    }
    
    private func loadJSONData() {
        guard let url = Bundle.main.url(forResource: "CoursesTYG", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            print("Error loading JSON file")
            return
        }
        
        do {
            courseData = try JSONDecoder().decode(CourseData.self, from: data)
        } catch {
            print("Error decoding JSON: \(error)")
            self.error = error
        }
    }
    
    private func loadSubmissions() {
        // Load submissions from UserDefaults
        if let data = UserDefaults.standard.data(forKey: "moduleSubmissions"),
           let submissions = try? JSONDecoder().decode([String: ModuleSubmission].self, from: data) {
            moduleSubmissions = submissions
        }
    }
    
    private func saveSubmissions() {
        // Save submissions to UserDefaults
        if let data = try? JSONEncoder().encode(moduleSubmissions) {
            UserDefaults.standard.set(data, forKey: "moduleSubmissions")
        }
    }
    
    func getModuleSubmissions(moduleId: String) -> ModuleSubmission? {
        return moduleSubmissions[moduleId]
    }
    
    func updateModuleSubmissions(moduleId: String, totalSubmissions: Int, averageScorePercentage: Double) {
        moduleSubmissions[moduleId] = ModuleSubmission(
            totalSubmissions: totalSubmissions,
            averageScorePercentage: averageScorePercentage
        )
        saveSubmissions()
    }
    
    func updateModuleDifficulty(moduleId: String, newDifficulty: Int) async {
        guard var courseData = courseData else { return }
        
        // Find the module and update its difficulty
        if let moduleIndex = courseData.course.modules.firstIndex(where: { $0.id == moduleId }) {
            var module = courseData.course.modules[moduleIndex]
            var difficulty = module.difficulty
            difficulty.score = newDifficulty
            module.difficulty = difficulty
            
            // Create a new array with the updated module
            var updatedModules = courseData.course.modules
            updatedModules[moduleIndex] = module
            
            // Create a new course with updated modules
            var updatedCourse = courseData.course
            updatedCourse.modules = updatedModules
            
            // Update the courseData
            courseData.course = updatedCourse
            self.courseData = courseData
            
            // Save changes back to JSON file
            saveToJSON()
        }
    }
    
    func getModuleDifficulty(moduleId: String) -> Int? {
        return courseData?.course.modules.first(where: { $0.id == moduleId })?.difficulty.score
    }
    
    func getModule(byId id: String) -> ModuleInfo? {
        return courseData?.course.modules.first(where: { $0.id == id })
    }
    
    func getModule(byTitle title: String) -> ModuleInfo? {
        return courseData?.course.modules.first(where: { $0.title == title })
    }
    
    func getCategory(categoryId: String) -> CategoryInfo? {
        return courseData?.course.categories.first(where: { $0.id == categoryId })
    }
    
    private func saveToJSON() {
        guard let courseData = courseData,
              let url = Bundle.main.url(forResource: "CoursesTYG", withExtension: "json") else {
            return
        }
        
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(courseData)
            try data.write(to: url)
        } catch {
            print("Error saving JSON: \(error)")
            self.error = error
        }
    }
}
