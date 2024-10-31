//
//  Encryptor.swift
//  SwiftUIPractice
//
//  Created by Dhananjay Dubey on 26/10/24.
//

import Foundation
@preconcurrency import CryptoKit

struct CryptoMetadata {
    let encryptedKey: Data
    let signature: Data
    let nonce: Data
    let tag: Data
}

public struct EncryptionService {
    
    func encryptFile(
        atPath filePath: URL,
        outputPath: URL,
        senderPrivateKey: SecKey,
        recipientPublicKey: SecKey
    ) async throws -> (encryptedData: Data, metadata: CryptoMetadata) {
        
        let fileData = try await loadFileDataAsync(at: filePath)
        print("fileData loaded")
        let aesKey = SymmetricKey(size: .bits256)
        let nonce = AES.GCM.Nonce()
        
        let (sealedBox, nonceData) = try await AESManager.encrypt(data: fileData, using: aesKey, nonce: nonce)
        
        let signature = try await signData(sealedBox.ciphertext, with: senderPrivateKey)
        
        print("signature done - \(signature.base64EncodedString())")

        let encryptedKey = try await encryptAESKey(aesKey, with: recipientPublicKey)
        print("encryptedKey: \(encryptedKey)")

        let metadata = CryptoMetadata(
            encryptedKey: encryptedKey,
            signature: signature,
            nonce: nonceData,
            tag: sealedBox.tag
        )
        
        let encryptedData = sealedBox.ciphertext
        print("metadata: \(metadata) and encryptedData \(encryptedData)")

        try await createFileAndWriteDataAsync(data: encryptedData, fileName: "EncryptedData")
        
        return (sealedBox.ciphertext, metadata)
    }
    
    func decryptFile(
        fromPath filePath: URL,
        metadata: CryptoMetadata,
        recipientPrivateKey: SecKey,
        senderPublicKey: SecKey,
        outputPath: URL
    ) async throws {
        
        let encryptedData = try await loadFileDataAsync(at: filePath)
        
        let aesKey = try await decryptAESKey(metadata.encryptedKey, with: recipientPrivateKey)
        
        print("Signature to verify -- \(metadata.signature.base64EncodedString())")
        try await verifySignature(metadata.signature, for: encryptedData, using: senderPublicKey)
        
        guard let nonce = try? AES.GCM.Nonce(data: metadata.nonce) else {
            throw CryptoError.decryptionFailed
        }
        
        let decryptedData = try await AESManager.decrypt(ciphertext: encryptedData, nonce: Data(nonce), using: aesKey, tag: metadata.tag)
        
        try await createFileAndWriteDataAsync(data: decryptedData, fileName: outputPath.lastPathComponent)
    }

        
    private func loadFileDataAsync(at path: URL) async throws -> Data {
        return try await withCheckedThrowingContinuation { continuation in

            print("Constructed URL: \(path)")

            do {
                if try path.checkResourceIsReachable() {
                    let data = try Data(contentsOf: path)
                    print("Data found at \(path).")
                    continuation.resume(returning: data)
                } else {
                    print("File does not exist at path: \(path)")
                    continuation.resume(throwing: CryptoError.fileNotFound)
                }
            } catch {
                print("Error checking file existence or reading data: \(error.localizedDescription)")
                continuation.resume(throwing: CryptoError.fileNotFound)
            }
        }
    }
    
    private func signData(_ data: Data, with privateKey: SecKey) async throws -> Data {
        var error: Unmanaged<CFError>?
        guard let signature = SecKeyCreateSignature(
            privateKey,
            .rsaSignatureMessagePSSSHA256,
            data as CFData,
            &error
        ) as Data? else {
            throw CryptoError.signingDataFailed
        }
        
        return signature
    }
    
    private func encryptAESKey(_ aesKey: SymmetricKey, with publicKey: SecKey) async throws -> Data {
        var error: Unmanaged<CFError>?
        guard let encryptedKey = SecKeyCreateEncryptedData(
            publicKey,
            .rsaEncryptionOAEPSHA256,
            aesKey.withUnsafeBytes { Data($0) } as CFData,
            &error
        ) as Data? else {
            throw CryptoError.keyEncryptionFailed
        }
        return encryptedKey
    }
    
    private func decryptAESKey(_ encryptedKey: Data, with privateKey: SecKey) async throws -> SymmetricKey {
        var error: Unmanaged<CFError>?
        guard let keyData = SecKeyCreateDecryptedData(
            privateKey,
            .rsaEncryptionOAEPSHA256,
            encryptedKey as CFData,
            &error
        ) as Data? else {
            throw CryptoError.keyDecryptionFailed
        }
        return SymmetricKey(data: keyData)
    }
    
    private func verifySignature(_ signature: Data, for data: Data, using publicKey: SecKey) async throws {
        let algorithm = SecKeyAlgorithm.rsaSignatureMessagePSSSHA256
        guard SecKeyIsAlgorithmSupported(publicKey, .verify, algorithm) else {
            throw CryptoError.signatureVerificationSupportFailed
        }
        
        var error: Unmanaged<CFError>?
        let isValid = SecKeyVerifySignature(
            publicKey,
            algorithm,
            data as CFData,
            signature as CFData,
            &error
        )
        
        if let error = error?.takeRetainedValue() {
            throw error
        }
        
        guard isValid else {
            throw CryptoError.signatureVerificationFailed
        }
    }

    private func createFileAndWriteDataAsync(data: Data, fileName: String) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
                continuation.resume(throwing: CryptoError.fileNotFound)
                return
            }
            
            let fileURL = documentsDirectory.appendingPathComponent(fileName)
            
            do {
                if !FileManager.default.fileExists(atPath: fileURL.path) {
                    FileManager.default.createFile(atPath: fileURL.path, contents: nil, attributes: nil)
                    print("Created file at \(fileURL.path).")
                }
                
                try data.write(to: fileURL, options: .atomic)
                print("Data successfully written to \(fileURL.path).")
                continuation.resume()
            } catch {
                print("Error writing data to \(fileURL.path): \(error.localizedDescription)")
                continuation.resume(throwing: CryptoError.writeError)
            }
        }
    }
}
