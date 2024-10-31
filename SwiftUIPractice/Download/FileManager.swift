import Foundation
import AppleArchive
import SSZipArchive // Assuming SSZipArchive is used for unzipping

public enum FileManagerError: Error {
    case noDiskSpaceAvailable
    case failedToCreateDirectory
    case failedToMoveFile
    case failedToCreateFilePath
    case failedToCopyFile
    case unzipFailed
    case readFileStreamError
    case decompressStreamError
    case decodeStreamError
    case extractStreamError
}

public protocol FileManagerInterface {
    func checkAvailableSpace() throws
    func handleDownloadedFile(location: URL, downloadURL: URL, for connectionId: String, saveBackupZip: Bool) throws -> URL
    func getDocumentsDirectoryString() -> String
    func getConnectionDirectoryURL(for connectionId: String) -> URL
    func getBackupDirectoryURL(for connectionId: String) -> URL
    func copyFile(from location: URL, to destinationFolder: URL) throws -> URL
    func moveFile(from location: URL, to destinationFolder: URL) throws -> URL
}

public final class FileManagerService: Sendable, FileManagerInterface {
    
    static let shared = FileManagerService()
    let metaDataManager = DownloadFileMetaDataManager()
    private let minimumRequiredSpace: Int64 = 100 * 1024 * 1024 // Minimum space required: 100MB
    
    private init() {}
    
    // MARK: - Public Methods
    
    public func handleDownloadedFile(location: URL, downloadURL: URL, for connectionId: String, saveBackupZip: Bool) throws -> URL {
        guard FileManager.default.fileExists(atPath: location.path) else {
            throw FileManagerError.failedToMoveFile
        }
        
        // Set up main directories
        let connectionDirectory = getConnectionDirectoryURL(for: connectionId)
        let backupDirectory = getBackupDirectoryURL(for: connectionId)
        let photosDirectory = connectionDirectory.appendingPathComponent("Photos")
        
        // Create necessary directories
        try createDirectoryIfNeeded(at: backupDirectory)
        try createDirectoryIfNeeded(at: photosDirectory)
        
        // Move the zip file to the backup folder
        let zipFileURL = try moveFile(from: location, to: backupDirectory)
        
        // Unzip to a temporary folder
        let tempUnzipDirectory = connectionDirectory.appendingPathComponent("TempUnzip")
        try createDirectoryIfNeeded(at: tempUnzipDirectory)
        do {
            // Unzipping
            let isSuccess = SSZipArchive.unzipFile(atPath: zipFileURL.path, toDestination: tempUnzipDirectory.path)
            guard isSuccess else {
                throw FileManagerError.unzipFailed
            }
            
            // Move unzipped files to Photos folder
            let unzippedFiles = try FileManager.default.contentsOfDirectory(at: tempUnzipDirectory, includingPropertiesForKeys: nil)
            var unzippedPhotoURLs: [URL] = []
            for file in unzippedFiles {
                let destinationURL = photosDirectory.appendingPathComponent(file.lastPathComponent)
                unzippedPhotoURLs.append(destinationURL)
                try FileManager.default.moveItem(at: file, to: destinationURL)
            }
            
            // Clean up: delete the temporary unzip directory
            try FileManager.default.removeItem(at: tempUnzipDirectory)
            
            // Optionally delete the zip file from backup
            if !saveBackupZip {
                try FileManager.default.removeItem(at: zipFileURL)
            }
            
            try DownloadFileMetaDataManager.saveZipAndPhotoMetadata(
                zipFileURL: saveBackupZip ? zipFileURL : nil,
                photos: unzippedPhotoURLs,
                for: connectionId
            )
        } catch {
            throw error
        }
        
        return zipFileURL
    }
    
    public func getDocumentsDirectoryString() -> String {
        return getDocumentsDirectory().path
    }
    
    public func getConnectionDirectoryURL(for connectionId: String) -> URL {
        let connectionDirectory = getDocumentsDirectory().appendingPathComponent("PicSee/Connections/\(connectionId)")
        checkAndCreateDirectory(at: connectionDirectory.path)
        return connectionDirectory
    }
    
    public func getBackupDirectoryURL(for connectionId: String) -> URL {
        return getConnectionDirectoryURL(for: connectionId).appendingPathComponent("Backup")
    }
    
    public func moveFile(from location: URL, to destinationFolder: URL) throws -> URL {
        let destinationURL = destinationFolder.appendingPathComponent(location.lastPathComponent)
        try createDirectoryIfNeeded(at: destinationFolder)
        do {
            try checkAvailableSpace()
            try FileManager.default.moveItem(at: location, to: destinationURL)
        } catch {
            throw FileManagerError.failedToMoveFile
        }
        
        return destinationURL
    }
    
    public func copyFile(from location: URL, to destinationFolder: URL) throws -> URL {
        let destinationURL = destinationFolder.appendingPathComponent(location.lastPathComponent)
        try createDirectoryIfNeeded(at: destinationURL)
        do {
            try checkAvailableSpace()
            try FileManager.default.copyItem(at: location, to: destinationURL)
        } catch {
            throw FileManagerError.failedToCopyFile
        }
        
        return destinationURL
    }
    
    public func checkAvailableSpace() throws {
        let attributes = try FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory())
        let freeSpace = attributes[.systemFreeSize] as? Int64 ?? 0
        guard freeSpace > minimumRequiredSpace else {
            throw FileManagerError.noDiskSpaceAvailable
        }
    }
    
    // MARK: - Private Helper Methods
    
    private func getDocumentsDirectory() -> URL {
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    }
    
    private func createDirectoryIfNeeded(at url: URL) throws {
        if !FileManager.default.fileExists(atPath: url.path) {
            do {
                try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
            } catch {
                throw FileManagerError.failedToCreateDirectory
            }
        }
    }
    
    private func checkAndCreateDirectory(at path: String) {
        var isDirectory: ObjCBool = false
        if !FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory) || !isDirectory.boolValue {
            try? FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true, attributes: nil)
        }
    }
}
