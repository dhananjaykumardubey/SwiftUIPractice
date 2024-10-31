//
//  ViewModel.swift
//  SwiftUIPractice
//
//  Created by Dhananjay Dubey on 20/9/24.
//

import SwiftUI
import Photos

struct Item: Identifiable {
    let id: Int
    let color: Color
    let isCorner: Bool
    var removedIndex: Int?
}

class VerticalGridViewModel: ObservableObject {
    @Published var items: [Item] = [
        Item(id: 1, color: .blue, isCorner: true, removedIndex: nil),
        Item(id: 2, color: .red, isCorner: false, removedIndex: nil),
        Item(id: 3, color: .green, isCorner: false, removedIndex: nil),
        Item(id: 4, color: .orange, isCorner: false, removedIndex: nil),
        Item(id: 5, color: .purple, isCorner: false, removedIndex: nil),
        Item(id: 6, color: .yellow, isCorner: false, removedIndex: nil),
        Item(id: 7, color: .pink, isCorner: false, removedIndex: nil),
        Item(id: 8, color: .teal, isCorner: false, removedIndex: nil),
        Item(id: 9, color: .indigo, isCorner: false, removedIndex: nil),
        Item(id: 10, color: .gray, isCorner: true, removedIndex: nil)
    ]
}

class PhotoGalleryViewModel: ObservableObject {
    @Published var images: [UIImage] = []
    @Published var isLoading: Bool = false
    private var currentPage: Int = 0
    private let pageSize: Int = 20
    private var allAssets: [PHAsset] = []
    
    // Initialize with PHAssets
    init(assets: [PHAsset]) {
        self.allAssets = assets
        fetchImages()
    }
    
    func fetchImages() {
        guard !isLoading else { return }
        isLoading = true
        
        let start = currentPage * pageSize
        let end = min(start + pageSize, allAssets.count)
        
        // Fetch images for current page
        for index in start..<end {
            let asset = allAssets[index]
            fetchImage(for: asset) { image in
                if let image = image {
                    DispatchQueue.main.async {
                        self.images.append(image)
                    }
                }
            }
        }
        
        // Increment current page
        currentPage += 1
        
        // Stop loading
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.isLoading = false
        }
    }
    
    private func fetchImage(for asset: PHAsset, completion: @escaping (UIImage?) -> Void) {
        let imageManager = PHImageManager.default()
        let requestOptions = PHImageRequestOptions()
        requestOptions.isSynchronous = false
        requestOptions.deliveryMode = .highQualityFormat
        
        imageManager.requestImage(for: asset,
                                  targetSize: CGSize(width: 120, height: 120),
                                  contentMode: .aspectFit,
                                  options: requestOptions) { image, _ in
            completion(image)
        }
    }
    
    func resetPagination() {
        currentPage = 0
        images.removeAll()
        fetchImages()
    }
    
    func send() async {
        do {
            try await encrypt()
        } catch {}
//
//        let urlString = "https://sample-videos.com/zip/50mb.zip" //
//        let filesToDownload1 = FilesToDownload(connectionID: "Dhananjay", devicePhotoIDS: ["Dhananjay_50mb"], signedURL: urlString)
//        let filesToDownload2 = FilesToDownload(connectionID: "Dhananjay", devicePhotoIDS: ["Dhananjay_20mb"], signedURL: "https://sample-videos.com/zip/20mb.zip")
//        
//        let filesToDownload3 = FilesToDownload(connectionID: "Dhananjay", devicePhotoIDS: ["Dhananjay_10mb"], signedURL: "https://sample-videos.com/zip/10mb.zip")
//        
//        let connectionHelper = ConnectionDownloadHelper()
//        
//        await connectionHelper.startDownloading(filesToDownload: [filesToDownload3])
        
    }
    
    func encrypt() async throws {
        
        guard let rsaDhananjaySender = RSAKeyManager.shared.generateRSAKey(for: "DH_123") else {
            print("Error: RSA Key generation failed - rsaDhananjaySender")
            return
        }
        guard let rsaGuruReceiver = RSAKeyManager.shared.generateRSAKey(for: "GS_456") else {
            print("Error: RSA Key generation failed - rsaGuruReceiver")
            return
        }
        print("rsaDhananjaySender private key: \(rsaDhananjaySender.privateKey)")
        print("rsaDhananjaySender public key: \(rsaDhananjaySender.publicKey)")
        
        print("rsaGuruReceiver private key: \(rsaGuruReceiver.privateKey)")
        print("rsaGuruReceiver publickey key: \(rsaGuruReceiver.publicKey)")
        let filePath = FileManager.default.urls(for: .documentDirectory,
                                                in: .userDomainMask).first!
            .appendingPathComponent("10mb.zip")
        let outputFilePath = FileManager.default.urls(for: .documentDirectory,
                                                      in: .userDomainMask).first!
        let outputDecryptedFilePath = FileManager.default.urls(for: .documentDirectory,
                                                      in: .userDomainMask).first!
            .appendingPathComponent("DecryptedData.zip")
        let encryptedPath = FileManager.default.urls(for: .documentDirectory,
                                                in: .userDomainMask).first!
            .appendingPathComponent("EncryptedData")
        
        let encryptor = EncryptionService()
        do {
            let encryptedData = try await encryptor.encryptFile(atPath: filePath,
                                                                outputPath: outputFilePath,
                                                                senderPrivateKey: rsaDhananjaySender.privateKey,
                                                                recipientPublicKey: rsaGuruReceiver.publicKey)
            
            try await Task.sleep(nanoseconds: 5_000_000_000)
            
            try await encryptor.decryptFile(fromPath: encryptedPath,
                                            metadata: encryptedData.metadata,
                                            recipientPrivateKey: rsaGuruReceiver.privateKey,
                                            senderPublicKey: rsaDhananjaySender.publicKey,
                                            outputPath: outputDecryptedFilePath)
            
            print("Decrypted data successfully:")

        } catch {
            print("Error: \(error)")
        }
        
       
    }
}
