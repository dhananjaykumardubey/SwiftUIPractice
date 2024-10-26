//
//  AESManager.swift
//  SwiftUIPractice
//
//  Created by Dhananjay Dubey on 26/10/24.
//

import Foundation
import CryptoKit

struct AESManager {
    static func encrypt(data: Data, using key: SymmetricKey, nonce: AES.GCM.Nonce) async throws -> (sealedBox: AES.GCM.SealedBox, nonce: Data) {
        do {
            let sealedBox = try AES.GCM.seal(data, using: key, nonce: nonce, authenticating: Data())
            return (sealedBox, Data(nonce))
        } catch {
            throw CryptoError.encryptionFailed
        }
    }
    
    static func decrypt(ciphertext: Data, nonce: Data, using key: SymmetricKey, tag: Data) async throws -> Data {
        guard let nonce = try? AES.GCM.Nonce(data: nonce) else {
            throw CryptoError.decryptionFailed
        }
        do {
            let sealedBox = try AES.GCM.SealedBox(nonce: nonce, ciphertext: ciphertext, tag: tag)
            return try AES.GCM.open(sealedBox, using: key)
        } catch {
            throw CryptoError.decryptionFailed
        }
    }
}

