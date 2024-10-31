//
//  Download.swift
//  SwiftUIPractice
//
//  Created by Dhananjay Dubey on 24/10/24.
//

import Foundation

enum DownloadManagerError: Error, LocalizedError {
    case downloadNotFound
    case failedToProduceResumeData
    case noAvailableDiskSpace
    case unknownError(String)

    var errorDescription: String? {
        switch self {
        case .downloadNotFound:
            return "The download task could not be found."
        case .failedToProduceResumeData:
            return "Failed to produce resume data while pausing the download."
        case .noAvailableDiskSpace:
            return "Not enough disk space available."
        case .unknownError(let message):
            return "Unknown error: \(message)"
        }
    }
}

struct DownloadTaskState {
    var task: URLSessionDownloadTask
    var url: URL
    var progress: Double
    var resumeData: Data?
}

protocol DownloadManagerProtocol {
    func downloadFiles(urls: [URL]) async throws
}

protocol DownloadManagerDelegate: AnyObject {
    func downloadManager(_ manager: DownloadManager, didFinishDownloadingWithError error: Error?)
}

class DownloadManager: NSObject, DownloadManagerProtocol {
    static let shared = DownloadManager()
    
    private let maxConcurrentDownloads = 3
    private var activeDownloads = [UUID: DownloadTaskState]()
    private let fileManagerService = FileManagerService.shared
    
    // Lazy background session to allow initialization after `self` is available
    private lazy var backgroundSession: URLSession = {
        let configuration = URLSessionConfiguration.background(withIdentifier: "com.-SwiftUIPractice.SwiftUIPractice.downloadManager.session")
        configuration.isDiscretionary = true
        configuration.sessionSendsLaunchEvents = true
        return URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
    }()
    
    override private init() {
        super.init()
    }

    
    func downloadFiles(urls: [URL]) async throws {
        let taskQueue = TaskQueue(maxConcurrentTasks: maxConcurrentDownloads)
        
        try await withThrowingTaskGroup(of: Void.self) { group in
            for url in urls {
                group.addTask {
                    do {
                        try await taskQueue.enqueue {
                            try await self.downloadFile(from: url)
                        }
                    } catch {
                        print("Failed to download file from URL: \(url), error: \(error)")
                        throw error
                    }
                }
            }
            try await group.waitForAll()
            
            DispatchQueue.main.async {
                print("All downloads complete!")
            }
        }
    }
    
    private func downloadFile(from url: URL) async throws {
        try fileManagerService.checkAvailableSpace()
        let downloadId = UUID()
        let task = backgroundSession.downloadTask(with: url)
        task.priority = 1.0
        activeDownloads[downloadId] = DownloadTaskState(task: task, url: url, progress: 0.0)
        task.resume()
    }

    private func updateProgress(for task: URLSessionDownloadTask, progress: Double) {
        guard let downloadId = activeDownloads.first(where: { $0.value.task == task })?.key else { return }
        activeDownloads[downloadId]?.progress = progress
        print("Download progress for \(downloadId): \(progress * 100)%")
    }
    
    // MARK: - File Handling After Download Completion
    private func handleFileDownload(locationUrl: URL, downloadURL: URL) throws -> URL {
        let savedURL = try fileManagerService.handleDownloadedFile(location: locationUrl, downloadURL: downloadURL, for: "dhan_123", saveBackupZip: true)
        return savedURL
    }
    
//    private func unzipAndSaveMetadata(zipFileURL: URL) async throws {
//        let folderURL = zipFileURL.deletingLastPathComponent()
//        let photos = try fileManagerService.unzipFile(at: zipFileURL.absoluteString, to: folderURL.absoluteString)
//        try await saveMetadata(zipFileURL: zipFileURL, photos: photos)
//    }
    
//    private func saveMetadata(zipFileURL: URL, photos: [URL]) async throws {
//        var photoMetadata = [PhotoMetadata]()
//
//        let downloadDate = Date()                // Record the current date as the download date
//        let zipId = UUID().uuidString            // Generate a unique identifier for the zip file
//
//        for photo in photos {
//            let attributes = try FileManager.default.attributesOfItem(atPath: photo.path)
//            let fileSize = attributes[.size] as? Int64 ?? 0
//            let fileName = photo.lastPathComponent // Get the file name from the URL
//
//            let metadata = PhotoMetadata(id: UUID(),
//                                         fileName: fileName,
//                                         downloadDate: downloadDate,
//                                         zipId: UUID(),
//                                         filePath: photo)
//            
//            photoMetadata.append(metadata)
//        }
//
//        let fileMetadata = FileMetadata(id: UUID(),
//                                        assetId: zipId,
//                                        zipFilePath: zipFileURL,
//                                        photos: photoMetadata,
//                                        dateDownloaded: downloadDate)
//        
//        try await SwiftDataManager.shared.save(fileMetadata)
//    }

}

// MARK: - URLSessionDownloadDelegate for Background Support
extension DownloadManager: URLSessionDownloadDelegate {
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            print("Download task completed with error: \(error.localizedDescription)")
        }
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
            do {
                let url = downloadTask.originalRequest?.url
                guard let downloadURL = url else { throw DownloadManagerError.unknownError("Original request URL not found.") }
                
                guard let downloadId = activeDownloads.first(where: { $0.value.task == downloadTask })?.key else {
                    throw DownloadManagerError.downloadNotFound
                }
                
                // TODO: Send an event for download complete instantly
                print("Downloaded successfully at \(location) for download url: \(downloadURL)")
                let savedURL = try handleFileDownload(locationUrl: location, downloadURL: downloadURL)
//                print("unzipped at \(savedURL)")
//                let baseDirectory = try fileManagerService.createDirectory(for: "ConnectionID")
//                
//                // Move zip file to designated location
//                let savedURL = try fileManagerService.moveFile(from: location, to: baseDirectory)
//
                print("Downloaded successfully at \(savedURL) for download url: \(downloadURL)")
//                try await unzipAndSaveMetadata(zipFileURL: savedURL)
                activeDownloads.removeValue(forKey: downloadId)
            } catch {
                print("Error processing downloaded file: \(error)")
            }
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        let progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        updateProgress(for: downloadTask, progress: progress)
    }
    
    func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        DispatchQueue.main.async {
            print("Downloaded successfully in background")
            // Notify that all background events are finished, and the app can reactivate
        }
        // Add LOCAL NOtification later
    }
}
