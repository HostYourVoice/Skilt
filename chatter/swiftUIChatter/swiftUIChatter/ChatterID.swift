//
//  ChatterID.swift
//  swiftUIChatter
//
//  Created by BlessedAmulya Parmar on 2/26/25.
//


import Foundation
import LocalAuthentication

final class ChatterID: @unchecked Sendable {
    static let shared = ChatterID() // create one instance of the class to be shared
    private init(){}                // and make the constructor private so no other
                                    // instances can be created
    
    var expiration = Date(timeIntervalSince1970: 0.0)
    private var _id: String?
    var id: String? {
        get { Date() >= expiration ? nil : _id }
        set(newValue) { _id = newValue }
    }
    
    #if targetEnvironment(simulator)
    // Skip authentication for simulator to avoid passcode prompt
    private let skipSimulatorAuthentication = true
    private let auth = LAContext()
    #endif
    
    func open() async {
        if expiration != Date(timeIntervalSince1970: 0.0) {
            // not first launch
            return
        }

        #if targetEnvironment(simulator)
        // Skip authentication for simulator to avoid passcode prompt
        if !skipSimulatorAuthentication {
            guard let _ = try? await auth.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "to allow simulator to access ChatterID in KeyChain") else { return }
        }
        #endif

        let searchFor: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrDescription: "ChatterID",
            kSecReturnData: true,
            kSecReturnAttributes: true,
        ]
        
        var itemRef: AnyObject?
        let searchStatus = SecItemCopyMatching(searchFor as CFDictionary, &itemRef)
        
        let df = DateFormatter()
        df.dateFormat="yyyy-MM-dd HH:mm:ss '+'SSSS"

        switch (searchStatus) {
        case errSecSuccess: // found keychain
            if let item = itemRef as? NSDictionary,
               let data = item[kSecValueData] as? Data,
               let dateStr = item[kSecAttrLabel] as? String,
               let date = df.date(from: dateStr) {
                id = String(data: data, encoding: .utf8)
                expiration = date
            } else {
                print("Keychain has null entry!")
            }
            
        case errSecItemNotFound:
            // biometric check
            let accessControl = SecAccessControlCreateWithFlags(nil,
              kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly,
              .userPresence,
              nil)!
            
            let item: [CFString: Any] = [
                kSecClass: kSecClassGenericPassword,
                kSecAttrDescription: "ChatterID",
                kSecAttrLabel: df.string(from: expiration),
                kSecAttrAccessControl: accessControl  // biometric check
            ]

            let addStatus = SecItemAdd(item as CFDictionary, nil)
            if (addStatus != 0) {
                print("ChatterID.open add: \(String(describing: SecCopyErrorMessageString(addStatus, nil)!))")
            }
            
        default:
            print("ChatterID.open search: \(String(describing: SecCopyErrorMessageString(searchStatus, nil)!))")
        }
    }

    func save() async {
        #if targetEnvironment(simulator)
        // Skip authentication for simulator to avoid passcode prompt
        if !skipSimulatorAuthentication {
            guard let _ = try? await auth.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "to allow simulator to access ChatterID in KeyChain") else { return }
        }
        #endif
        
        let df = DateFormatter()
        df.dateFormat="yyyy-MM-dd HH:mm:ss '+'SSSS"
        
        let item: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrDescription: "ChatterID",
        ]
        
        let updates: [CFString: Any] = [
            kSecValueData: id?.data(using: .utf8) as Any,
            kSecAttrLabel: df.string(from: expiration)
        ]
        
        let updateStatus = SecItemUpdate(item as CFDictionary, updates as CFDictionary)
        if (updateStatus != 0) {
            print("ChatterID.save: \(String(describing: SecCopyErrorMessageString(updateStatus, nil)!))")
        }
    }

    func delete() async {
        let item: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrDescription: "ChatterID",
        ]
        
        let delStatus = SecItemDelete(item as CFDictionary)
        if (delStatus != 0) {
            print("ChatterID.delete: \(String(describing: SecCopyErrorMessageString(delStatus, nil)!))")
        }
    }

}
