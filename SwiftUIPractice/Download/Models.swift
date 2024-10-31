//
//  Models.swift
//  SwiftUIPractice
//
//  Created by Dhananjay Dubey on 24/10/24.
//

import Foundation
import SwiftData

@Model
public final class ZipFileMetadata: Sendable {
    @Attribute(.unique) var fileName: String
    var downloadDate: Date
    var filePath: URL
    var connectionId: String
    
    init(fileName: String, downloadDate: Date, filePath: URL, connectionId: String) {
        self.fileName = fileName
        self.downloadDate = downloadDate
        self.filePath = filePath
        self.connectionId = connectionId
    }
}

@Model
public final class PhotoMetadata: Sendable {
    @Attribute(.unique) var fileName: String
    var downloadDate: Date
    var filePath: URL
    var connectionId: String
    
    init(connectionId: String, fileName: String, downloadDate: Date, filePath: URL) {
        self.connectionId = connectionId
        self.fileName = fileName
        self.downloadDate = downloadDate
        self.filePath = filePath
    }
}

// Overall file metadata that relates zip and photo metadata
struct FileMetadata {
    let id: UUID
    let assetId: String
    let zipFilePath: URL
    let photos: [PhotoMetadata]
    let dateDownloaded: Date
}

struct DownloadModel {
    var isDownloading = false
    var progress: Float = 0
    var resumeData: Data?
    var task: URLSessionDownloadTask?
    var track: FilesToDownload
}

// MARK: - FilesToDownload
public struct FilesToDownload: Codable {
    let connectionID: String
    let devicePhotoIDS: [String]
    let signedURL: String
    // encryptedModel
}

