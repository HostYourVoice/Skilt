import Foundation
import Observation

@Observable
final class CourseStore {
    static let shared = CourseStore()
    private(set) var courseData: CourseData?
    private(set) var isLoading: Bool = false
    
    private init() {
        loadJSONData()
    }
    
    // Load the CoursesTYG.json data
    private func loadJSONData() {
        guard let url = Bundle.main.url(forResource: "CoursesTYG", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            print("Error loading JSON file")
            return
        }
        
        do {
            let decoder = JSONDecoder()
            self.courseData = try decoder.decode(CourseData.self, from: data)
        } catch {
            print("Error decoding JSON: \(error)")
        }
    }
    
    // Update module difficulty locally
    func updateModuleDifficulty(moduleId: String, newDifficulty: Int) {
        guard var courseData = courseData,
              let moduleIndex = courseData.course.modules.firstIndex(where: { $0.id == moduleId }) else {
            print("Module not found")
            return
        }
        
        // Create a mutable copy of the module
        var module = courseData.course.modules[moduleIndex]
        module.difficulty.score = newDifficulty
        
        // Update the module in the course data
        courseData.course.modules[moduleIndex] = module
        
        // Update the entire course data
        self.courseData = courseData
        print("Successfully updated difficulty for module \(moduleId) to \(newDifficulty)")
    }
    
    // Get module difficulty locally
    func getModuleDifficulty(moduleId: String) -> Int? {
        return courseData?.course.modules.first(where: { $0.id == moduleId })?.difficulty.score
    }
    
    // Get module by ID
    func getModule(moduleId: String) -> Module? {
        return courseData?.course.modules.first(where: { $0.id == moduleId })
    }
    
    // Get module by title
    func getModule(title: String) -> Module? {
        return courseData?.course.modules.first(where: { $0.title == title })
    }
} 