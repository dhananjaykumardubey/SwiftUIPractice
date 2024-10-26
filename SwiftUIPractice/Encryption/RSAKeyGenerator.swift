//
//  RSAKeyGenerator.swift
//  SwiftUIPractice
//
//  Created by Dhananjay Dubey on 26/10/24.
//
import Foundation
import Security
import OSLog


protocol RSAKeyManagerProtocol: Sendable {
    func fetchPublicKey(for connectionId: String) -> String?
    func fetchPrivateKey(for connectionId: String) -> String?
    func deleteKeys(for connectionId: String) -> Bool
    func generateRSAKey(for connectionId: String, sizeInBits: Int) -> (privateKey: SecKey, publicKey: SecKey)?
}

final class RSAKeyManager: RSAKeyManagerProtocol {
    
    static let kRSAKeyApplicationTag = "com.-SwiftUIPractice.SwiftUIPractice.keypair.access"
    
    static let shared = RSAKeyManager()
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "-SwiftUIPractice.SwiftUIPractice", category: "RSAKeyManager")

    private init() {}

    func fetchPublicKey(for connectionId: String) -> String? {
        if let publicKey = self.getPublicKeyBase64(for: connectionId) {
            return publicKey
        }
        return nil
    }
    
    func fetchPrivateKey(for connectionId: String) -> String? {
        if let privateKey = self.getPrivateKeyBase64(for: connectionId) {
            return privateKey
        }
        return nil
    }
    
    func deleteKeys(for connectionId: String) -> Bool {
        return self.deleteSecKeyFromKeychain(for: connectionId)
    }
    
    func generateRSAKey(for connectionId: String, sizeInBits: Int = 4096) -> (privateKey: SecKey, publicKey: SecKey)? {
        return self.generateAndValidateRSAKeyPair(connectionId: connectionId, sizeInBits: sizeInBits)
    }
    
    private func generateAndValidateRSAKeyPair(connectionId: String, sizeInBits size: Int) -> (privateKey: SecKey, publicKey: SecKey)? {
        guard let keys = generateAndStoreRSAKeyPair(for: connectionId, sizeInBits: size) else {
            logger.error("Key pair generation failed")
            return nil
        }

        guard self.verifyKeyPair(privateKey: keys.privateKey, publicKey: keys.publicKey) else {
            logger.error("Key pair validation failed")
            return nil
        }
        return keys
    }
    
    private func getPublicKeyBase64(for connectionId: String) -> String? {
        let foundPublicKey = self.retrieveRSAKeyPair(for: connectionId)?.publicKey
        guard let foundPublicKey = foundPublicKey, let data = data(forKeyReference: foundPublicKey) else {
            return nil
        }
        let modifiedData = self.prependX509KeyHeader(keyData: data)
        return format(keyData: modifiedData, withPemType: "PUBLIC KEY")
    }
    
    private func getPrivateKeyBase64(for connectionId: String) -> String? {
        guard let privateKey = self.retrieveRSAKeyPair(for: connectionId)?.privateKey,
                let data = data(forKeyReference: privateKey) else {
            return nil
        }
        return format(keyData: data, withPemType: "RSA PRIVATE KEY")
    }

    private func deleteSecKeyFromKeychain(for connectionId: String) -> Bool {
        guard let tagData = "\(RSAKeyManager.kRSAKeyApplicationTag).\(connectionId)".data(using: .utf8)
        else {
            logger.error("String to data conversion failed")
            return false
        }
        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: tagData
        ]

        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            logger.error("Deletion Failed: \(SecCopyErrorMessageString(status, nil) ?? "unknown error" as CFString)")
            return false
        }
        return true
    }

    private func generateAndStoreRSAKeyPair(for connectionId: String, sizeInBits size: Int) -> (privateKey: SecKey, publicKey: SecKey)? {
        guard let tagData = "\(RSAKeyManager.kRSAKeyApplicationTag).\(connectionId)".data(using: .utf8) else {
            logger.error("String to data conversion failed")
            return nil
        }
        
        if let keys = self.retrieveRSAKeyPair(for: connectionId),
           let privateKey = keys.privateKey,
           let publicKey = keys.publicKey {
            return (privateKey, publicKey)
        }
        
        logger.info("Generating RSA key pair for connection \(tagData)")
        
        let privateKeyAttributes: [String: Any] = [
            kSecAttrIsPermanent as String: true,
            kSecAttrApplicationTag as String: tagData,
            kSecAttrSynchronizable as String: true,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked
        ]

        let keyAttributes: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeRSA,
            kSecAttrKeySizeInBits as String: size,
            kSecPrivateKeyAttrs as String: privateKeyAttributes
        ]

        var error: Unmanaged<CFError>?
        guard let privateKey = SecKeyCreateRandomKey(keyAttributes as CFDictionary, &error) else {
            logger.error("Key pair generation failed: \(error?.takeRetainedValue().localizedDescription ?? "unknown error")")
            return nil
        }

        guard let publicKey = SecKeyCopyPublicKey(privateKey) else {
            logger.error("Failed to copy public key")
            return nil
        }

        let privateKeyData = SecKeyCopyExternalRepresentation(privateKey, &error)
        guard let privateKeyData = privateKeyData else {
            logger.error("Failed to copy private key data: \(error?.takeRetainedValue().localizedDescription ?? "unknown error")")
            return nil
        }

        let privateKeyStorageAttributes: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrKeyType as String: kSecAttrKeyTypeRSA,
            kSecAttrKeySizeInBits as String: size,
            kSecValueData as String: privateKeyData as Data,
            kSecAttrApplicationTag as String: tagData,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked
        ]

        let status = SecItemAdd(privateKeyStorageAttributes as CFDictionary, nil)
        guard status == errSecSuccess else {
            logger.error("Failed to store private key: \(status)")
            return nil
        }

        return (privateKey: privateKey, publicKey: publicKey)
    }

    private func retrieveRSAKeyPair(for connectionId: String) -> (privateKey: SecKey?, publicKey: SecKey?)? {
        guard let tagData = "\(RSAKeyManager.kRSAKeyApplicationTag).\(connectionId)".data(using: .utf8)
        else {
            logger.error("String to data conversion failed")
            return nil
        }

        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: tagData,
            kSecAttrKeyType as String: kSecAttrKeyTypeRSA,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked,
            kSecReturnRef as String: true,
            kSecAttrSynchronizable as String: true
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        guard status == errSecSuccess else {
            logger.error("Failed to retrieve key pair from Keychain: \(SecCopyErrorMessageString(status, nil) ?? "unknown error" as CFString)")
            return nil
        }

        let privateKey = item as! SecKey
        guard let publicKey = SecKeyCopyPublicKey(privateKey) else {
            logger.error("Failed to copy public key")
            return nil
        }

        return (privateKey: privateKey, publicKey: publicKey)
    }

    private func verifyKeyPair(privateKey: SecKey, publicKey: SecKey) -> Bool {
        let testData = "Test Data".data(using: .utf8)!
        
        var error: Unmanaged<CFError>?
        
        guard let encryptedData = SecKeyCreateEncryptedData(publicKey, .rsaEncryptionPKCS1, testData as CFData, &error) else {
            logger.error("Encryption failed: \(error?.takeRetainedValue().localizedDescription ?? "unknown error")")
            return false
        }
        
        guard let decryptedData = SecKeyCreateDecryptedData(privateKey, .rsaEncryptionPKCS1, encryptedData, &error) else {
            logger.error("Decryption failed: \(error?.takeRetainedValue().localizedDescription ?? "unknown error")")
            return false
        }
        
        return decryptedData as Data == testData
    }

    private func format(keyData: Data, withPemType pemType: String) -> String {
        func split(_ str: String, byChunksOfLength length: Int) -> [String] {
            return stride(from: 0, to: str.count, by: length).map { index -> String in
                let startIndex = str.index(str.startIndex, offsetBy: index)
                let endIndex = str.index(startIndex, offsetBy: length, limitedBy: str.endIndex) ?? str.endIndex
                return String(str[startIndex..<endIndex])
            }
        }
        
        let chunks = split(keyData.base64EncodedString(options: [.lineLength64Characters, .endLineWithLineFeed]),
                           byChunksOfLength: 64)
        
        let pem = [
            "-----BEGIN \(pemType)-----",
            chunks.joined(separator: "\n"),
            "-----END \(pemType)-----"
        ]
        
        return pem.joined(separator: "\n")
    }

    private func data(forKeyReference reference: SecKey) -> Data? {
        var error: Unmanaged<CFError>?
        let data = SecKeyCopyExternalRepresentation(reference, &error)
        guard let unwrappedData = data as Data? else {
            self.logger.error("No Data mapped")
            return nil
        }
        return unwrappedData
    }
    
    private func prependX509KeyHeader(keyData: Data) -> Data {
        let x509PublicKeyHeader: [UInt8] = [
            0x30, 0x82, 0x01, 0x22, 0x30, 0x0d, 0x06,
            0x09, 0x2a, 0x86, 0x48, 0x86, 0xf7, 0x0d,
            0x01, 0x01, 0x01, 0x05, 0x00, 0x03, 0x82,
            0x01, 0x0f, 0x00
        ]
        var keyWithHeader = Data(x509PublicKeyHeader)
        keyWithHeader.append(keyData)
        return keyWithHeader
    }
}

