//
//  Untitled.swift
//  SwiftUIPractice
//
//  Created by Dhananjay Dubey on 26/10/24.
//
//
//import Foundation
//import UIKit
//
//enum DownloadError {
//    case invalidURL
//    case downloadError(Error)
//    case fileSystemError(Error)
//    case unknown
//}
//
//protocol DownloadManagerDelegate1: AnyObject {
//    func downloadManager(_ manager: DownloadManager1, didUpdateProgress progress: Double, for url: URL)
//    func downloadManager(_ manager: DownloadManager1, didFinishDownloadingTo url: URL, to location: URL)
//    func downloadManager(_ manager: DownloadManager1, didFailWithError error: DownloadError, for url: URL)
//    func downloadManagerDidCancel(_ manager: DownloadManager1, for url: URL)
//    func downloadManagerDidResume(_ manager: DownloadManager1, for url: URL)
//    func downloadManagerDidPause(_ manager: DownloadManager1, for url: URL)
//    func downloadManagerDidFinishAllDownloads(_ manager: DownloadManager1)
//}
//
//final class DownloadManager1: NSObject   {
//     
//    var delegate: DownloadManagerDelegate1?
////    private let taskQueue: DownloadTaskQueue
//    private var maxConcurrency: Int
//    private var activeDownloads: [URL: DownloadTask] = [:]
//    private let downloadQueue = DispatchQueue(label: "com.-SwiftUIPractice.SwiftUIPractice.downloadManager.queue", attributes: .concurrent)
//    var semaphore: DispatchSemaphore?
//    private var downloadQueueList: [URL] = []
//      private var currentDownloads: Set<Task<Void, Never>> = []
//
//    override init() {
//        self.maxConcurrency = 3
//        semaphore = DispatchSemaphore(value: maxConcurrency)
//        super.init()
//    }
//    
//    func downloadFiles(urls: [URL]) async throws {
//        downloadQueueList.append(contentsOf: urls)
//        self.processBatch()
//    }
//     
//    private func processBatch() {
//        print("DJJ: Starting new batch of downloads...")
//        print("downloadQueueList.count: \(downloadQueueList.count)")
//        for _ in 0..<min(maxConcurrency, downloadQueueList.count) {
//            if activeDownloads.count >= maxConcurrency {
//                return
//            }
//            let nextURL = downloadQueueList.removeFirst()
//            
//            print("DJJ: Starting download for URL: \(nextURL.absoluteString)")
//            guard let urlString = nextURL.absoluteString as? String else {
//                print("DJJ: Invalid URL passed: \(nextURL)")
//                continue
//            }
//            self.downloadFile(from: nextURL)
//        }
//    }
//    
//    func pauseDownloads(for url: URL) {
//        downloadQueue.async { [weak self] in
//            guard let self = self else { return }
//            self.activeDownloads[url]?.pause()
//        }
//    }
//    
//    func resumeDownloads(for url: URL) {
//        downloadQueue.async {
//            self.activeDownloads[url]?.resume()
//        }
//    }
//    
//    func cancelDownloads(for url: URL) {
//        downloadQueue.async {
//            self.activeDownloads[url]?.cancel()
//            self.activeDownloads.removeValue(forKey: url)
//        }
//    }
//    
//    private func downloadFile(from url: URL) {
//        let downloadTask = DownloadTask(url: url, taskDelegate: self)
//        activeDownloads[url] = downloadTask
//        downloadTask.start()
//    }
//}
//
//extension DownloadManager1: DownloadTaskDelegate {
//    func downloadTaskDidStart(_ task: DownloadTask) {
//        print("downloadTaskDidStart for url: \(task.url)")
//    }
//    
//    func downloadTask(_ task: DownloadTask, didUpdateProgress progress: Double) {
//        let totalProgress = activeDownloads.values.reduce(0) { $0 + $1.progress } / Double(activeDownloads.count)
//        delegate?.downloadManager(self, didUpdateProgress: totalProgress, for: task.url)
//    }
//    
//    func downloadTask(_ task: DownloadTask, didFinishDownloadingTo location: URL) {
//        delegate?.downloadManager(self, didFinishDownloadingTo: task.url, to: location)
//        activeDownloads.removeValue(forKey: task.url)
//        print("Download Complete for url: \(task.url), location: \(location)")
//        processBatch()
////        Task {
////            
//////            try await self.downloadFiles(urls: Array(downloadQueueList))
////        }
//    }
//    
//    func downloadTask(_ task: DownloadTask, didFailWithError error: DownloadError) {
//        delegate?.downloadManager(self, didFailWithError: error, for: task.url)
//        activeDownloads.removeValue(forKey: task.url)
//    }
//    
//    func downloadTaskDidCancel(_ task: DownloadTask) {
//        delegate?.downloadManagerDidCancel(self, for: task.url)
//        activeDownloads.removeValue(forKey: task.url)
//    }
//    
//    func downloadTaskDidResume(_ task: DownloadTask) {
//        delegate?.downloadManagerDidResume(self, for: task.url)
//    }
//    
//    func downloadTaskDidSPause(_ task: DownloadTask) {
//        delegate?.downloadManagerDidPause(self, for: task.url)
//    }
//}
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

final class DownloadManager1: NSObject {
    weak var delegate: DownloadManagerDelegate1?
    private let maxConcurrency: Int
    private var activeDownloads: [URL: DownloadTask] = [:]
    private let downloadQueue = DispatchQueue(label: "com.SwiftUIPractice.downloadManager.queue", attributes: .concurrent)
    private var downloadQueueList: [URL] = []
    
    override init() {
        self.maxConcurrency = 3
        super.init()
    }
    
    deinit {
        print("Came here for DownloadManager1 - deinit")
    }
    
    func downloadFiles(urls: [URL]) {
        downloadQueueList.append(contentsOf: urls)
        processBatch()
    }

    private func processBatch() {
        downloadQueue.async {
            while !self.downloadQueueList.isEmpty && self.activeDownloads.count < self.maxConcurrency {
                let nextURL = self.downloadQueueList.removeFirst()
                print("Starting download for URL: \(nextURL.absoluteString)")
                self.downloadFile(from: nextURL)
            }
        }
    }
    
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
        downloadQueue.async(flags: .barrier) {
            self.activeDownloads[url]?.cancel()
            self.activeDownloads.removeValue(forKey: url)
        }
    }
    
    func removeDownloadTask(for url: URL) {
        downloadQueue.async(flags: .barrier) {
            self.activeDownloads.removeValue(forKey: url)
        }
    }
    
    private func downloadFile(from url: URL) {
        let downloadTask = DownloadTask(url: url)
        downloadTask.taskDelegate = self
        //        downloadQueue.async(flags: .barrier) {
        self.activeDownloads[url] = downloadTask
        //        }
        downloadTask.start()
    }
}

extension DownloadManager1: DownloadTaskDelegate {
    func downloadTaskDidStart() {
        print("downloadTaskDidStart for")
    }
    
    func downloadTask(_ task: DownloadTask, didUpdateProgress progress: Double) {
        let totalProgress = activeDownloads.values.reduce(0) { $0 + $1.progress } / Double(activeDownloads.count)
        delegate?.downloadManager(self, didUpdateProgress: totalProgress, for: task.url)
    }
    
    func downloadTask(_ task: DownloadTask, didFinishDownloadingTo location: URL) {
        print("didFinishDownloadingTo: \(task.url)")
        delegate?.downloadManager(self, didFinishDownloadingTo: task.url, to: location)
        if downloadQueueList.isEmpty && activeDownloads.isEmpty {
            delegate?.downloadManagerDidFinishAllDownloads(self)
        }
        removeDownloadTask(for: task.url)
        processBatch()
    }
    
    func downloadTask(_ task: DownloadTask, didFailWithError error: DownloadError) {
        delegate?.downloadManager(self, didFailWithError: error, for: task.url)
        removeDownloadTask(for: task.url)
        processBatch()
    }
    
    func downloadTaskDidCancel(_ task: DownloadTask) {
        delegate?.downloadManagerDidCancel(self, for: task.url)
        removeDownloadTask(for: task.url)
    }
    
    func downloadTaskDidResume(_ task: DownloadTask) {
        delegate?.downloadManagerDidResume(self, for: task.url)
    }
    
    func downloadTaskDidPause(_ task: DownloadTask) {
        delegate?.downloadManagerDidPause(self, for: task.url)
    }
}
