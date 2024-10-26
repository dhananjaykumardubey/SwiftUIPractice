//
//  DownloadHelper.swift
//  SwiftUIPractice
//
//  Created by Dhananjay Dubey on 24/10/24.
//

import Foundation

protocol DownloadTaskDelegate: AnyObject, Sendable {
    func downloadTask(_ task: DownloadTask, didUpdateProgress progress: Double)
    func downloadTask(_ task: DownloadTask, didFinishDownloadingTo location: URL)
    func downloadTask(_ task: DownloadTask, didFailWithError error: DownloadError)
    func downloadTaskDidCancel(_ task: DownloadTask)
    func downloadTaskDidResume(_ task: DownloadTask)
    func downloadTaskDidSPause(_ task: DownloadTask)
    func downloadTaskDidStart(_ task: DownloadTask)
}

final class DownloadTask: NSObject, Sendable {
    let url: URL
    let taskDelegate: DownloadTaskDelegate?
    
    private var task: URLSessionDownloadTask?
    private var resumeData: Data?
    private(set) var progress: Double = 0
    
    private lazy var backgroundSession: URLSession = {
        let configuration = URLSessionConfiguration.background(withIdentifier: "com.picsee.downloadManager.session")
        configuration.isDiscretionary = true
        configuration.sessionSendsLaunchEvents = true
        return URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
    }()
    
    init(url: URL, taskDelegate: DownloadTaskDelegate? = nil) {
        self.taskDelegate = taskDelegate
        self.url = url
        super.init()
          // Logging to confirm delegate assignment
          print("DownloadTask initialized. Delegate is set: \(self.taskDelegate != nil)")
    }
    
    func start() {
        task = backgroundSession.downloadTask(with: url)
        task?.priority = URLSessionTask.highPriority
        task?.resume()
        self.taskDelegate?.downloadTaskDidStart(self)
    }
    
    func pause() {
        task?.cancel(byProducingResumeData: { data in
            self.resumeData = data
            self.task = nil
            self.taskDelegate?.downloadTaskDidSPause(self)
        })
    }
    
    func resume() {
        guard let resumeData else { return }
        
        let task = backgroundSession.downloadTask(withResumeData: resumeData)
        task.priority = 1
        task.resume()
        self.resumeData = nil
        self.taskDelegate?.downloadTaskDidResume(self)
    }
    
    func cancel() {
        task?.cancel()
        task = nil
        self.taskDelegate?.downloadTaskDidCancel(self)
    }
    
    private func getDocumentsDirectoryString() -> String {
        func defaultGetDocumentsDirectoryString() -> String {
            let paths = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)
            return paths[0]
        }
        return defaultGetDocumentsDirectoryString()
    }
}

extension DownloadTask: URLSessionDownloadDelegate {
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        do {
            let fileManager = FileManager.default
            guard let downloadURL = downloadTask.originalRequest?.url,
                    let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first
                    else { return }
            let destinationURL = documentsPath.appendingPathComponent(downloadURL.lastPathComponent)
            
            try? fileManager.removeItem(at: destinationURL)
            try fileManager.copyItem(at: location, to: destinationURL)
            
            print("Downloaded successfully at \(destinationURL) for download url: \(String(describing: downloadURL))")
            self.taskDelegate?.downloadTask(self, didFinishDownloadingTo: destinationURL)
        } catch {
            print("Error processing downloaded file: \(error)")
        }
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        print("PROGRESS - \(progress)")
        taskDelegate?.downloadTask(self, didUpdateProgress: progress)
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error {
            taskDelegate?.downloadTask(self, didFailWithError: .downloadError(error))
        }
    }
    
    func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        print("urlSessionDidFinishEvents")
//        DispatchQueue.main.async {
//            if let appDelegate = UIApplication.shared.delegate as? AppDelegate,
//            let completionHandler = appDelegate.backgroundSessionCompletionHandler {
//                completionHandler()
//                appDelegate.backgroundSessionCompletionHandler = nil
//            }
//        }
    }
}
