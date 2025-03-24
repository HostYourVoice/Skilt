//
//  Submission.swift
//  swiftUIChatter
//
//  Created by BlessedAmulya Parmar on 1/29/25.
//

import Foundation

// Property wrapper to handle empty or "null" string values
// Moved outside of Submission to avoid redeclaration issues
@propertyWrapper
struct EmptyStringOptional {
    private var _value: String?
    var wrappedValue: String? {
        get { _value }
        set {
            guard let newValue else {
                _value = nil
                return
            }
            _value = (newValue == "null" || newValue.isEmpty) ? nil : newValue
        }
    }
    
    init(wrappedValue: String?) {
        self.wrappedValue = wrappedValue
    }
}

struct Submission: Identifiable {
    var username: String?
    var message: String?
    var id: UUID?
    var timestamp: String?
    var altRow = true
    @EmptyStringOptional var audio: String?
    var userEmail: String?

    // so that we don't need to compare every property for equality
    static func ==(lhs: Submission, rhs: Submission) -> Bool {
        lhs.id == rhs.id
    }    
} 
