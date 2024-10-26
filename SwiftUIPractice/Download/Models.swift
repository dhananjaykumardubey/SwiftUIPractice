//
//  Models.swift
//  SwiftUIPractice
//
//  Created by Dhananjay Dubey on 24/10/24.
//

import Foundation

// Metadata for the downloaded zip file
struct ZipFileMetadata: Decodable {
    let fileName: String
    let downloadDate: Date
    let zipId: UUID
    let filePath: URL
}

// Metadata for individual photo files
struct PhotoMetadata: Decodable {
    let id: UUID
    let fileName: String
    let downloadDate: Date
    let zipId: UUID
    let filePath: URL
}

// Overall file metadata that relates zip and photo metadata
struct FileMetadata: Decodable {
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

