//
//  FileManager.swift
//  SwiftUIPractice
//
//  Created by Dhananjay Dubey on 24/10/24.
//

import Foundation
import SSZipArchive

enum FileManagerError: Error {
    case noDiskSpaceAvailable
    case failedToCreateDirectory
    case failedToMoveFile
    case failedToCopyFile
    case unzipFailed
}

class FileManagerService {
    static let shared = FileManagerService()
    
    private let minimumRequiredSpace: Int64 = 100 * 1024 * 1024 // Minimum space required: 100MB
    
    private init() {}
    
    func checkAvailableSpace() throws {
        let availableSpace = try getAvailableDiskSpace()
        guard availableSpace > minimumRequiredSpace else {
            throw FileManagerError.noDiskSpaceAvailable
        }
    }
    
    private func getAvailableDiskSpace() throws -> Int64 {
        let attributes = try FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory())
        let freeSpace = attributes[.systemFreeSize] as? Int64 ?? 0
        return freeSpace
    }
    
    func handleDownloadedFile(location: URL, downloadURL: URL) throws -> URL {
        guard FileManager.default.fileExists(atPath: location.path) else {
            throw FileManagerError.failedToMoveFile
        }
//        guard let zipFileURL = try saveToDocumentsDirectory(copyFrom: location, with: downloadURL.lastPathComponent)
//        else {
//            throw FileManagerError.failedToMoveFile
//        }
        let zipFileURL = try moveFile(from: location, to: getConnectionDirectoryURL())
        
        let photosDirectory = getConnectionDirectoryURL().appendingPathComponent("Photos")
        try createDirectoryIfNeeded(at: photosDirectory)
        let unzippedPhotoURLs = try unzipFile(at: zipFileURL.path, to: photosDirectory.path)
        print("unzippedPhotoURLs \(unzippedPhotoURLs)")
        
        try saveZipAndPhotoMetadata(zipFileURL: zipFileURL, photos: unzippedPhotoURLs)
        return zipFileURL
    }
    
    
    private func saveZipAndPhotoMetadata(zipFileURL: URL, photos: [URL]) throws {
        let zipMetadata = ZipFileMetadata(fileName: zipFileURL.lastPathComponent,
                                          downloadDate: Date(),
                                          zipId: UUID(),
                                          filePath: zipFileURL)
        
        let photoMetadata = photos.map {
            return PhotoMetadata(id: UUID(),
                                 fileName: $0.lastPathComponent,
                                 downloadDate: Date(),
                                 zipId: zipMetadata.zipId,
                                 filePath: $0)
        }
        
        try saveToSwiftData(zipMetadata: zipMetadata, photoMetadata: photoMetadata)
    }
    
    private func saveToSwiftData(zipMetadata: ZipFileMetadata, photoMetadata: [PhotoMetadata]) throws {
        // Implement SwiftData saving logic
        print("zipMetadata -- \(zipMetadata)")
        print("photoMetadata -- \(photoMetadata)")
        // Add actual saving logic here
    }
    
    func createDirectoryIfNeeded(at url: URL) throws {
        if !FileManager.default.fileExists(atPath: url.path) {
            do {
                try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
            } catch {
                print("Failed to create directory: \(error.localizedDescription)")
                throw FileManagerError.failedToCreateDirectory
            }
        }
    }

    func createDirectory(for fileName: String) throws -> URL {
        guard let documentsDirectory = FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        ).first?
        .appendingPathComponent(fileName) else {
            throw FileManagerError.failedToCreateDirectory
        }
        
        do {
            try FileManager.default.createDirectory(at: documentsDirectory, withIntermediateDirectories: true)
        } catch {
            print("Failed to create directory: \(error.localizedDescription)")
            throw FileManagerError.failedToCreateDirectory
        }
        
        return documentsDirectory
    }
    
    func moveFile(from location: URL, to destinationFolder: URL) throws -> URL {
        let destinationURL = destinationFolder.appendingPathComponent(location.lastPathComponent)
        
        do {
            try checkAvailableSpace() // Ensure there's space before moving the file
            try FileManager.default.moveItem(at: location, to: destinationURL)
        } catch {
            print("Error moving file: \(error.localizedDescription)")
            throw FileManagerError.failedToMoveFile
        }
        
        return destinationURL
    }
    
    func copyFile(from location: URL, to destinationFolder: URL) throws -> URL {
        let destinationURL = destinationFolder.appendingPathComponent(location.lastPathComponent)
        
        do {
            try checkAvailableSpace() // Ensure there's space before moving the file
            try FileManager.default.copyItem(at: location, to: destinationURL)
        } catch {
            print("Error moving file: \(error.localizedDescription)")
            throw FileManagerError.failedToCopyFile
        }
        
        return destinationURL
    }
    
    
    func unzipFile(at fileURL: String, to destinationFolder: String) throws -> [URL] {
        let success = SSZipArchive.unzipFile(atPath: fileURL, toDestination: destinationFolder)
        guard success else {
            throw FileManagerError.unzipFailed
        }
        
        // List all files in destination folder and return URLs
        let unzippedFiles = try FileManager.default.contentsOfDirectory(atPath: destinationFolder)
        return unzippedFiles.map { URL(fileURLWithPath: destinationFolder).appendingPathComponent($0) }
    }
    
    // Read a file from a specified URL
    func readFile(at url: URL) throws -> Data {
        return try Data(contentsOf: url)
    }
}


extension FileManagerService {

    func connectionAssetDirectory() -> String {
        let directory = getDocumentsDirectoryString() + "/Connection"
        checkAndCreateDirectory(at: directory)
        return directory
    }

    func checkAndCreateDirectory(at path: String) {
        var isDirectory: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory)
        if !exists || !isDirectory.boolValue {
            try? FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true, attributes: nil)
        }
    }

     func getDocumentsDirectoryString() -> String {
        func defaultGetDocumentsDirectoryString() -> String {
            let paths = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)
            return paths[0]
        }
        
        return defaultGetDocumentsDirectoryString()
    }

    func getConnectionDirectoryURL() -> URL {
        URL(fileURLWithPath: connectionAssetDirectory())
    }
    
    func getBackupDirectoryURL() -> URL {
        URL(fileURLWithPath: connectionAssetDirectory()).appendingPathComponent("Backup")
    }

    func saveToDocumentsDirectory(copyFrom sourceURL: URL, with fileName: String) throws -> URL? {
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: sourceURL.relativePath) {
            let documentsDirectory = getBackupDirectoryURL().path
            let uniquePrefix: String = {
                let date = Date()
                return String(describing: date.timeIntervalSince1970)
            }()
            let pathToWrite = "\(documentsDirectory)/\(uniquePrefix)\(fileName)"

            do {
                let dd = try self.moveFile(from: sourceURL, to: URL(filePath: pathToWrite))
//                try fileManager.copyItem(atPath: sourceURL.relativePath, toPath: pathToWrite)
                if fileManager.fileExists(atPath: pathToWrite) {
                    let fileURL = URL(fileURLWithPath: pathToWrite)
                    try? fileManager.removeItem(at: sourceURL)
                    return fileURL
                } else {
                    return nil
                }
            } catch {
                print("Error: \(error.localizedDescription)")
                throw error
            }
        } else {
            print("saveToDocumentsDirectory: File Does not exist")
            return nil
        }
    }
}
