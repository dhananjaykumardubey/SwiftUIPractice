//
//  Untitled.swift
//  SwiftUIPractice
//
//  Created by Dhananjay Dubey on 26/10/24.
//

import Foundation
import UIKit

enum DownloadError {
    case invalidURL
    case downloadError(Error)
    case fileSystemError(Error)
    case unknown
}

protocol DownloadManagerDelegate1: AnyObject {
    func downloadManager(_ manager: DownloadManager1, didUpdateProgress progress: Double, for url: URL)
    func downloadManager(_ manager: DownloadManager1, didFinishDownloadingTo url: URL, to location: URL)
    func downloadManager(_ manager: DownloadManager1, didFailWithError error: DownloadError, for url: URL)
    func downloadManagerDidCancel(_ manager: DownloadManager1, for url: URL)
    func downloadManagerDidResume(_ manager: DownloadManager1, for url: URL)
    func downloadManagerDidPause(_ manager: DownloadManager1, for url: URL)
    func downloadManagerDidFinishAllDownloads(_ manager: DownloadManager1)
}

final class DownloadManager1: NSObject   {
     
    var delegate: DownloadManagerDelegate1?
    
    private var maxConcurrency: Int
    private var activeDownloads: [URL: DownloadTask] = [:]
    private let downloadQueue = DispatchQueue(label: "com.-SwiftUIPractice.SwiftUIPractice.downloadManager.queue", attributes: .concurrent)

    override init() {
        self.maxConcurrency = 3
        super.init()
    }
    
    func downloadFiles(urls: [URL]) async throws {
        let taskQueue = TaskQueue(maxConcurrentTasks: maxConcurrency)

        for url in urls {
            try await taskQueue.enqueue {
                try await self.downloadFile(from: url)
            }
        }
    }
//    func downloadFiles(urls: [URL]) async throws {
//        let taskQueue = TaskQueue(maxConcurrentTasks: maxConcurrency)
//        
//        try await withThrowingTaskGroup(of: Void.self) { [weak self] group in
//            guard let self = self else { return }
//            for url in urls {
//                group.addTask {
//                    do {
//                        try await taskQueue.enqueue {
//                            try await self.downloadFile(from: url)
//                        }
//                    } catch {
//                        print("Failed to download file from URL: \(url), error: \(error)")
//                        throw error
//                    }
//                }
//            }
//            try await group.waitForAll()
//        }
//        
//        DispatchQueue.main.async {
//            print("All downloads complete!")
//        }
//    }
    
    func pauseDownloads(for url: URL) {
        downloadQueue.async { [weak self] in
            guard let self = self else { return }
            self.activeDownloads[url]?.pause()
        }
    }
    
    func resumeDownloads(for url: URL) {
        downloadQueue.async {
            self.activeDownloads[url]?.resume()
        }
    }
    
    func cancelDownloads(for url: URL) {
        downloadQueue.async {
            self.activeDownloads[url]?.cancel()
            self.activeDownloads.removeValue(forKey: url)
        }
    }
    
    private func downloadFile(from url: URL) async throws {
        let downloadTask = DownloadTask(url: url, taskDelegate: self)
        activeDownloads[url] = downloadTask
        downloadTask.start()
    }
}

extension DownloadManager1: DownloadTaskDelegate {
    func downloadTaskDidStart(_ task: DownloadTask) {
        print("downloadTaskDidStart")
    }
    
    func downloadTask(_ task: DownloadTask, didUpdateProgress progress: Double) {
        let totalProgress = activeDownloads.values.reduce(0) { $0 + $1.progress } / Double(activeDownloads.count)
        delegate?.downloadManager(self, didUpdateProgress: totalProgress, for: task.url)
    }
    
    func downloadTask(_ task: DownloadTask, didFinishDownloadingTo location: URL) {
        delegate?.downloadManager(self, didFinishDownloadingTo: task.url, to: location)
        activeDownloads.removeValue(forKey: task.url)
    }
    
    func downloadTask(_ task: DownloadTask, didFailWithError error: DownloadError) {
        delegate?.downloadManager(self, didFailWithError: error, for: task.url)
        activeDownloads.removeValue(forKey: task.url)
    }
    
    func downloadTaskDidCancel(_ task: DownloadTask) {
        delegate?.downloadManagerDidCancel(self, for: task.url)
        activeDownloads.removeValue(forKey: task.url)
    }
    
    func downloadTaskDidResume(_ task: DownloadTask) {
        delegate?.downloadManagerDidResume(self, for: task.url)
    }
    
    func downloadTaskDidSPause(_ task: DownloadTask) {
        delegate?.downloadManagerDidPause(self, for: task.url)
    }
}
