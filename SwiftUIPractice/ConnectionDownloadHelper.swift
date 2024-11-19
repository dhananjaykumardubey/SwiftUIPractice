//
//  ConnectionDownloadHelper.swift
//  SwiftUIPractice
//
//  Created by Dhananjay Dubey on 26/10/24.
//

import Foundation
import AppleArchive
import System
import SwiftData

public final class ConnectionDownloadHelper {

    private var filesToDownload: [FilesToDownload] = []
    private let fileManagerService: FileManagerService = FileManagerService.shared
    private let downloadService: DownloadManager1 = DownloadManager1()
    private let cryptoService: Encryptor = EncryptionService()
    private let shouldDecrypt: Bool = false
    private let modelContainer: ModelContainer
    
    public init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
    }
    
    public func startDownloading(filesToDownload: [FilesToDownload]) {
        self.filesToDownload = filesToDownload
        let downloadUrls = filesToDownload.compactMap { URL(string: $0.signedURL) }
        Task {
            do {
                try await fileManagerService.checkAvailableSpace()
                downloadService.delegate = self
                downloadService.downloadFiles(urls: downloadUrls)
            } catch {
                print("Error downloading files: \(error.localizedDescription)")
            }
        }
    }
    
    private func decryptDownloadedFile(from fileLocation: URL,
                                       to destinationPath: URL,
                                       recipientPrivateKey: SecKey,
                                       senderPublicKey: SecKey,
                                       from metaData: CryptoMetadata) throws {
        try self.cryptoService.decryptFile(fromPath: fileLocation,
                                           metadata: metaData,
                                           recipientPrivateKey: recipientPrivateKey,
                                           senderPublicKey: senderPublicKey,
                                           outputPath: destinationPath)
        
    }
                          
    
    private func saveFileMetaData(zipFileMetaData: ZipFileMetadata?, photoMetaData: [PhotoMetadata]) {
//        if let zipFileMetaData = zipFileMetaData {
//            modelContext.insert(zipFileMetaData)
//        }
//        for photoMetaData in photoMetaData {
//            modelContext.insert(photoMetaData)
//        }
//        do {
//            try modelContext.save()
//        } catch {
//            print("Error: \(error.localizedDescription)")
//        }
    }

    private func handleFileDownload(locationUrl: URL, downloadURL: URL) throws -> URL? {
        print(locationUrl)
        let filePath = FilePath(locationUrl.absoluteString)
        let connectionId = self.filesToDownload.filter { downloadURL == URL(string: $0.signedURL) }.first?.connectionID
        var outputDecryptedFilePath = locationUrl
        Task {
            if shouldDecrypt, let fileName = filePath.lastComponent {
                print("FIlename = \(fileName)")
                let outputDecryptedFilePath = await self.fileManagerService.getDocumentsDirectory().appendingPathComponent("\(fileName).zip")
                // TODO: Handle decryption
            }
            let metaData = try await self.fileManagerService.handleDownloadedFile(location: locationUrl, for: connectionId ?? "Generic", saveBackupZip: true)
            self.saveFileMetaData(zipFileMetaData: metaData?.0, photoMetaData: metaData?.1 ?? [])
        }
        return nil
    }
}

extension ConnectionDownloadHelper: DownloadManagerDelegate1 {
    func downloadManager(_ manager: DownloadManager1, didUpdateProgress progress: Double, for url: URL) {
    }
    
    func downloadManager(_ manager: DownloadManager1, didFinishDownloadingTo url: URL, to location: URL) {
            do {
                let savedURL = try self.handleFileDownload(locationUrl: location, downloadURL: url)
            } catch {
                print("Error handling downloaded file: \(error.localizedDescription)")
            }
    }
    
    
    func downloadManager(_ manager: DownloadManager1, didFailWithError error: DownloadError, for url: URL) {
        print("didFailWithError: \(error)")
    }
    
    func downloadManagerDidCancel(_ manager: DownloadManager1, for url: URL) {
        print("downloadManagerDidCancel: \(url)")
    }
    
    func downloadManagerDidResume(_ manager: DownloadManager1, for url: URL) {
        print("downloadManagerDidResume: \(url)")
    }
    
    func downloadManagerDidPause(_ manager: DownloadManager1, for url: URL) {
        print("downloadManagerDidPause: \(url)")
    }
    
    func downloadManagerDidFinishAllDownloads(_ manager: DownloadManager1) {
        print("downloadManagerDidFinishAllDownloads")
    }
}


