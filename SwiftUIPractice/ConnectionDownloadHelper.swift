//
//  ConnectionDownloadHelper.swift
//  SwiftUIPractice
//
//  Created by Dhananjay Dubey on 26/10/24.
//

import Foundation
import AppleArchive
import System

public class ConnectionDownloadHelper {

    private var filesToDownload: [FilesToDownload] = []
    private let fileManagerService: FileManagerService = FileManagerService.shared
    private let downloadService: DownloadManager1 = DownloadManager1()
    
    public init() {
        downloadService.delegate = self
    }
    
    public func startDownloading(filesToDownload: [FilesToDownload]) async {
        self.filesToDownload = filesToDownload
        let downloadUrls = filesToDownload.compactMap { URL(string: $0.signedURL) }
        do {
            try fileManagerService.checkAvailableSpace()
            try await downloadService.downloadFiles(urls: downloadUrls)
        } catch {
            print("Error downloading files: \(error.localizedDescription)")
        }
    }
    
    
    // APP -> fileManager(location)
    // DownloadService -> FileManager
    // APP -> EncryptionPackage -> FileManager
    
    // App -> File, Download, Encryption
    // Download -> File
    // Encryption-> File
    
    
    // Write again in the location
    // APP -> FIleService -> Unzip and Store
    
    // DP
    // downloaded
    // fileManager - tmp(encrypted)
    //
    // EncryptionPackage
    //
    
    private func handleFileDownload(locationUrl: URL, downloadURL: URL) throws -> URL {
        // locationURL -> EncryptionPackage -> FilesToDownload.encryptedModel
        // decryptedData
        // zip/image
        // write this data
        // location
        // clean the decrypted clean
        let filePath = FilePath(locationUrl.absoluteString)
        let savedURL = try fileManagerService.handleDownloadedFile(location: locationUrl, downloadURL: downloadURL)
        return savedURL
    }
}

extension ConnectionDownloadHelper: DownloadManagerDelegate1 {
    func downloadManager(_ manager: DownloadManager1, didUpdateProgress progress: Double, for url: URL) {
        print("Current Progress - \(progress)")
    }
    
    func downloadManager(_ manager: DownloadManager1, didFinishDownloadingTo url: URL, to location: URL) {
        do {
            let savedURL = try self.handleFileDownload(locationUrl: location, downloadURL: url)
            print("Downloaded successfully at \(savedURL) for download url: \(url)")
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


