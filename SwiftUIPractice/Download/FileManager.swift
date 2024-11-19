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
    func checkAvailableSpace() async throws
    func handleDownloadedFile(location: URL, for connectionId: String, saveBackupZip: Bool) async throws -> (ZipFileMetadata?, [PhotoMetadata])?
    func getDocumentsDirectoryString() async throws-> String
    func getDocumentsDirectory() async -> URL
    func getConnectionDirectoryURL(for connectionId: String) async throws -> URL
    func getBackupDirectoryURL(for connectionId: String) async throws -> URL
    func copyFile(from location: URL, to destinationFolder: URL) async throws -> URL
    func moveFile(from location: URL, to destinationFolder: URL) async throws -> URL
}

public actor FileManagerService: Sendable, FileManagerInterface {

    static let shared = FileManagerService()
    private let minimumRequiredSpace: Int64 = 100 * 1024 * 1024 // Minimum space required: 100MB
    
    /// A cache to store directory paths that have already been checked or created.
     private var directoryCache: Set<String> = []

    private init() {}
    
    // MARK: - Public Methods
    
    public func handleDownloadedFile(location: URL, for connectionId: String, saveBackupZip: Bool) async throws -> (ZipFileMetadata?, [PhotoMetadata])? {
        guard FileManager.default.fileExists(atPath: location.path) else {
            throw FileManagerError.failedToMoveFile
        }
        
        // Set up main directories
        let connectionDirectory = try getConnectionDirectoryURL(for: connectionId)
        let backupDirectory = try getBackupDirectoryURL(for: connectionId)
        let photosDirectory = connectionDirectory.appendingPathComponent("Photos")
        
        // Create necessary directories
        try await ensureDirectoryExists(at: backupDirectory)
        try await ensureDirectoryExists(at: photosDirectory)
        
        // Move the zip file to the backup folder
        let zipFileURL = try await moveFile(from: location, to: backupDirectory)
        
        // Unzip to a temporary folder
        let tempUnzipDirectory = connectionDirectory.appendingPathComponent("\(UUID().uuidString)")
        try await ensureDirectoryExists(at: tempUnzipDirectory)
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
           
            let metaData = try DownloadFileMetaDataManager.createZipAndPhotoMetadata(zipFileURL: zipFileURL,
                                                                  photos: unzippedPhotoURLs,
                                                                  for: connectionId)
        } catch {
            throw error
        }
        
        return nil
    }
    
    public func getDocumentsDirectoryString() -> String {
        return getDocumentsDirectory().path
    }
    
    public func getConnectionDirectoryURL(for connectionId: String) throws -> URL {
        let connectionDirectory = getDocumentsDirectory().appendingPathComponent("PicSee/\(connectionId)")
        try checkAndCreateDirectory(at: connectionDirectory.path)
        return connectionDirectory
    }
    
    public func getBackupDirectoryURL(for connectionId: String) throws -> URL {
        return try getConnectionDirectoryURL(for: connectionId).appendingPathComponent("Backup")
    }
    
    public func moveFile(from location: URL, to destinationFolder: URL) async throws -> URL {
        let destinationURL = destinationFolder.appendingPathComponent(location.lastPathComponent)
        try await ensureDirectoryExists(at: destinationFolder)
        do {
            try checkAvailableSpace()
            try FileManager.default.moveItem(at: location, to: destinationURL)
        } catch {
            throw FileManagerError.failedToMoveFile
        }
        
        return destinationURL
    }
    
    public func copyFile(from location: URL, to destinationFolder: URL) async throws -> URL {
        let destinationURL = destinationFolder.appendingPathComponent(location.lastPathComponent)
        try await ensureDirectoryExists(at: destinationURL)
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
    
    public func getDocumentsDirectory() -> URL {
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    }

    @discardableResult
    private func checkAndCreateDirectory(at path: String) throws -> Bool {
        var isDirectory: ObjCBool = false
        if !FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory) || !isDirectory.boolValue {
            try FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true, attributes: nil)
            return true
        }
        return false
    }
    
    private func isDirectoryCached(_ path: String) async -> Bool {
        return directoryCache.contains(path)
    }
    
    private func cacheDirectory(_ path: String) async {
        directoryCache.insert(path)
    }
    
    private func ensureDirectoryExists(at url: URL) async throws {
        let path = url.path
        if await isDirectoryCached(path) {
            return
        }
        do {
            let directoryCreated = try checkAndCreateDirectory(at: path)
            if directoryCreated {
                await cacheDirectory(path)
            }
        } catch {
            throw FileManagerError.failedToCreateDirectory
        }
    }
}
