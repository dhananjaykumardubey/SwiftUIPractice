//
//  CyptoError.swift
//  SwiftUIPractice
//
//  Created by Dhananjay Dubey on 26/10/24.
//

import Foundation

enum CryptoError: Error {
    case fileNotFound
    case readError
    case fileNotCreated
    case writeError
    case encryptionFailed
    case decryptionFailed
    case signatureVerificationFailed
    case signatureVerificationSupportFailed
    case signingDataFailed
    case keyEncryptionFailed
    case keyDecryptionFailed
    
    var localizedDescription: String {
        switch self {
        case .fileNotFound: return "File not found at specified path."
        case .readError: return "Failed to read data from the file."
            case .fileNotCreated: return "Failed to create a file at given path"
        case .writeError: return "Failed to write data to the file."
        case .encryptionFailed: return "Failed to encrypt data."
        case .decryptionFailed: return "Failed to decrypt data."
            case .signatureVerificationFailed,
                    .signatureVerificationSupportFailed: return "Signature verification failed."
        case .signingDataFailed: return "Failed to sign data with RSA private key."
        case .keyEncryptionFailed: return "Failed to encrypt AES key with RSA public key."
        case .keyDecryptionFailed: return "Failed to decrypt AES key with RSA private key."
        }
    }
}
