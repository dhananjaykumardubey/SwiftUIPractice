//
//  KeychainManager.swift
//  SwiftUIPractice
//
//  Created by Dhananjay Dubey on 26/10/24.


import Foundation
import Security

enum PSKeychainConstants {
    static let signInTokenKey = "signInToken"
    static let signInRefreshTokenKey = "signInRefreshToken"
    static let keychainService = "com.-SwiftUIPractice.SwiftUIPractice.keychain"
}

enum PSKeychainItemType {
    case genericPassword
    case internetPassword
    case certificate
    case key
    case identity
    
    var secClass: CFString {
        switch self {
        case .genericPassword: return kSecClassGenericPassword
        case .internetPassword: return kSecClassInternetPassword
        case .certificate: return kSecClassCertificate
        case .key: return kSecClassKey
        case .identity: return kSecClassIdentity
        }
    }
}

enum PSKeychainError: Error, Equatable {
    case itemNotFound
    case duplicateItem
    case unexpectedItemData
    case unhandledError(status: OSStatus)
    case keyGenerationFailed
    case decodingError
    
    static func == (lhs: PSKeychainError, rhs: PSKeychainError) -> Bool {
           switch (lhs, rhs) {
           case (.itemNotFound, .itemNotFound),
                (.duplicateItem, .duplicateItem),
                (.unexpectedItemData, .unexpectedItemData),
                (.keyGenerationFailed, .keyGenerationFailed),
               (.decodingError, .decodingError):
               return true
           case (.unhandledError(let lhsStatus), .unhandledError(let rhsStatus)):
               return lhsStatus == rhsStatus
           default:
               return false
           }
       }
}

protocol PSKeychainStorable: Sendable {
    
    func save<T: Codable>(_ item: T,
                          for key: String,
                          service: String,
                          type: PSKeychainItemType,
                          accessible: CFString,
                          shouldSaveInCloud: Bool) throws
    func read<T: Codable>(_ key: String, service: String, type: PSKeychainItemType, itemType: T.Type) throws -> T
    func update<T: Codable>(_ item: T, for key: String, service: String, type: PSKeychainItemType, accessible: CFString, shouldSaveInCloud: Bool) throws
    func delete(for key: String, service: String, type: PSKeychainItemType) throws
    func deleteAll(of type: PSKeychainItemType) throws
    func queryAll<T: Codable>(of type: PSKeychainItemType) throws -> [String: T]
    func saveCertificate(_ certificate: Data, for tag: String) throws
    func readCertificate(withTag tag: String) throws -> Data
    func updateCertificate(_ certificate: Data, for tag: String) throws
}

final class PSKeychainManager: PSKeychainStorable {
    
    func save<T: Codable>(_ item: T,
                          for key: String,
                          service: String,
                          type: PSKeychainItemType,
                          accessible: CFString = kSecAttrAccessibleWhenUnlocked,
                          shouldSaveInCloud: Bool) throws {
        let data = try JSONEncoder().encode(item)
        
        var query: [String: Any] = [
            kSecClass as String: type.secClass,
            kSecAttrAccount as String: key,
            kSecAttrService as String: service,
            kSecAttrAccessible as String: accessible,
            kSecValueData as String: data
        ]
        
        if shouldSaveInCloud, (type == .genericPassword || type == .internetPassword) {
            query[kSecAttrSynchronizable as String] = kSecAttrSynchronizableAny
        }
        
        let status = SecItemAdd(query as CFDictionary, nil)
        
        if status == errSecDuplicateItem {
            try update(item, for: key, service: service, type: type, accessible: accessible, shouldSaveInCloud: shouldSaveInCloud)
        } else if status != errSecSuccess {
            throw PSKeychainError.unhandledError(status: status)
        }
    }
    
    func read<T: Codable>(_ key: String, service: String, type: PSKeychainItemType, itemType: T.Type) throws -> T {
        var query: [String: Any] = [
            kSecClass as String: type.secClass,
            kSecAttrAccount as String: key,
            kSecAttrService as String: service,
            kSecReturnData as String: kCFBooleanTrue!
        ]
        if type == .genericPassword || type == .internetPassword {
            query[kSecAttrSynchronizable as String] = kSecAttrSynchronizableAny
        }
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        
        guard status != errSecItemNotFound else { throw PSKeychainError.itemNotFound }
        guard status == errSecSuccess else { throw PSKeychainError.unhandledError(status: status) }
        guard let data = item as? Data else { throw PSKeychainError.unexpectedItemData }
        
        return try JSONDecoder().decode(T.self, from: data)
    }
    
    func update<T: Codable>(_ item: T, for key: String, service: String, type: PSKeychainItemType, accessible: CFString = kSecAttrAccessibleWhenUnlocked, shouldSaveInCloud: Bool) throws {
        let data = try JSONEncoder().encode(item)
        
        var query: [String: Any] = [
            kSecClass as String: type.secClass,
            kSecAttrAccount as String: key,
            kSecAttrService as String: service
        ]
        if shouldSaveInCloud, (type == .genericPassword || type == .internetPassword) {
            query[kSecAttrSynchronizable as String] = kSecAttrSynchronizableAny
        }
        
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: accessible
        ]
        
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        
        guard status != errSecItemNotFound else { throw PSKeychainError.itemNotFound }
        guard status == errSecSuccess else { throw PSKeychainError.unhandledError(status: status) }
    }
    
    func delete(for key: String, service: String, type: PSKeychainItemType) throws {
        var query: [String: Any] = [
            kSecClass as String: type.secClass,
            kSecAttrAccount as String: key,
            kSecAttrService as String: service
        ]
        if type == .genericPassword || type == .internetPassword {
            query[kSecAttrSynchronizable as String] = kSecAttrSynchronizableAny
        }
        
        let status = SecItemDelete(query as CFDictionary)
        
        guard status == errSecSuccess || status == errSecItemNotFound else { throw PSKeychainError.unhandledError(status: status) }
    }
    
    func deleteAll(of type: PSKeychainItemType) throws {
        let query: [String: Any] = [
            kSecClass as String: type.secClass,
            kSecAttrSynchronizable as String: kSecAttrSynchronizableAny
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        
        guard status == errSecSuccess || status == errSecItemNotFound else { throw PSKeychainError.unhandledError(status: status) }
    }
    
    func queryAll<T: Codable>(of type: PSKeychainItemType) throws -> [String: T] {
        let query: [String: Any] = [
            kSecClass as String: type.secClass,
            kSecMatchLimit as String: kSecMatchLimitAll,
            kSecReturnAttributes as String: true,
            kSecReturnData as String: true,
            kSecAttrSynchronizable as String: kSecAttrSynchronizableAny
        ]
        
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess else {
            throw PSKeychainError.unhandledError(status: status)
        }
        
        guard let items = result as? [[String: Any]] else {
            throw PSKeychainError.unexpectedItemData
        }
        
        var results = [String: T]()
        for item in items {
            if let key = item[kSecAttrAccount as String] as? String,
               let valueData = item[kSecValueData as String] as? Data {
                do {
                    let decodedItem = try JSONDecoder().decode(T.self, from: valueData)
                    results[key] = decodedItem
                } catch {
                    throw PSKeychainError.decodingError
                }
            }
        }
        
        return results
    }
    
    func saveCertificate(_ certificate: Data, for tag: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassCertificate,
            kSecAttrApplicationTag as String: tag,
            kSecValueData as String: certificate
        ]
        
        let status = SecItemAdd(query as CFDictionary, nil)
        
        if status == errSecDuplicateItem {
            try updateCertificate(certificate, for: tag)
        } else if status != errSecSuccess {
            throw PSKeychainError.unhandledError(status: status)
        }
    }
    
    func readCertificate(withTag tag: String) throws -> Data {
        let query: [String: Any] = [
            kSecClass as String: kSecClassCertificate,
            kSecAttrApplicationTag as String: tag,
            kSecReturnData as String: kCFBooleanTrue!
        ]
        
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        
        guard status == errSecSuccess else { throw PSKeychainError.itemNotFound }
        guard let certificate = item as? Data else { throw PSKeychainError.unexpectedItemData }
        
        return certificate
    }
    
    func updateCertificate(_ certificate: Data, for tag: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassCertificate,
            kSecAttrApplicationTag as String: tag
        ]
        
        let attributes: [String: Any] = [
            kSecValueData as String: certificate
        ]
        
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        
        guard status != errSecItemNotFound else { throw PSKeychainError.itemNotFound }
        guard status == errSecSuccess else { throw PSKeychainError.unhandledError(status: status) }
    }
}

