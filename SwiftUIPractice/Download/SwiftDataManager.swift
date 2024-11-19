//
//  SwiftDataManager.swift
//  SwiftUIPractice
//
//  Created by Dhananjay Dubey on 24/10/24.
//

import Foundation
import SwiftData
//
//// MARK: - Custom Database Actor
@globalActor
public actor DatabaseActor: GlobalActor {
    public static let shared = DatabaseActor()
    private init() {}

    private let databaseActorQueue = DispatchQueue(label: "com.billionhearts.PicSee.databaseActor")

    public func performDatabaseTask<T>(closure: @escaping @DatabaseActor () async throws -> T) async throws -> T {
        return try await withCheckedThrowingContinuation { continuation in
            databaseActorQueue.async {
                Task { @DatabaseActor in
                    do {
                        let result = try await closure()
                        continuation.resume(returning: result)
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }
        }
    }
}

//// MARK: - Errors
enum StorageError: Error {
    case failedToSave
    case failedToDelete
    case itemNotFound
    case modelContextNotFound
    case modelContainerNotFound
}

//// MARK: - Protocol
//@DatabaseActor
public protocol StorageProtocol: ObservableObject {
    func save<T: PersistentModel>(_ item: T) async throws
    func update<T: PersistentModel>(_ item: T) async throws
    func delete<T: PersistentModel>(_ item: T) async throws
    func fetch<T: PersistentModel>(_ type: T.Type, predicate: Predicate<T>?) async throws -> [T]
    func fetchBatch<T: PersistentModel>(predicate: Predicate<T>?, sortDescriptors: [SortDescriptor<T>]) async throws -> [T] where T: Sendable
}

// MARK: - Storage Manager
//@DatabaseActor
actor StorageManager: StorageProtocol, @unchecked Sendable {
    public static let shared = StorageManager()

//    @DatabaseActor
     private var modelContainer: ModelContainer?
    
//    @DatabaseActor
    private var backgroundContext: ModelContext?

    private init() {}

//    @DatabaseActor
    
    public func configure(schema: Schema, isPreview: Bool = false) throws {
        let modelConfiguration = ModelConfiguration(isStoredInMemoryOnly: isPreview)
        self.modelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
        if let container = modelContainer {
            self.backgroundContext = ModelContext(container)
        }
    }

//    @DatabaseActor
    public func getModelContainer() -> ModelContainer {
        guard let container = modelContainer else {
            fatalError("Could not create ModelContainer")
        }
        return container
    }

//    @DatabaseActor
    private func getContext() throws -> ModelContext {
        guard let context = backgroundContext else {
            throw StorageError.modelContextNotFound
        }
        return context
    }

//    @DatabaseActor
    public func save<T: PersistentModel>(_ item: T) throws {
        let context = try getContext()
        context.insert(item)
        try context.save()
    }

//    @DatabaseActor
    public func update<T: PersistentModel>(_ item: T) throws {
        let context = try getContext()
        try context.save()
    }

//    @DatabaseActor
    public func delete<T: PersistentModel>(_ item: T) throws {
        let context = try getContext()
        context.delete(item)
        try context.save()
    }

//    @DatabaseActor
    public func fetch<T: PersistentModel>(_ type: T.Type, predicate: Predicate<T>?) async throws -> [T] {
        let context = try getContext()
        let descriptor = FetchDescriptor<T>(predicate: predicate)
        let results = try context.fetch(descriptor)
        return results
        
    }
    
//    @DatabaseActor
    public func fetchBatch<T: PersistentModel>(predicate: Predicate<T>?, sortDescriptors: [SortDescriptor<T>] = []) async throws -> [T] where T: Sendable {
        let context = try getContext()
        let descriptor = FetchDescriptor<T>(predicate: predicate, sortBy: sortDescriptors)
        let results = try context.fetch(descriptor)
        
        return results
    }
}

@ModelActor
actor DownloadFileMetaDataManager: Sendable {
    
//    private var modelContext: ModelContext
//    init(modelContext: ModelContext) {
//        self.modelContext = modelContext
//    }
//    private var modelContext: ModelContext {
//        modelExecutor.modelContext
//    }
    private var modelContext: ModelContext { modelExecutor.modelContext }

    static func createZipAndPhotoMetadata(zipFileURL: URL?,
                                          photos: [URL],
                                          for connectionId: String) throws -> (ZipFileMetadata?, [PhotoMetadata])? {
        
        var zipMetaData: ZipFileMetadata?
        if let zipFileURL = zipFileURL {
            zipMetaData = ZipFileMetadata(
                fileName: zipFileURL.lastPathComponent,
                downloadDate: Date(),
                filePath: zipFileURL,
                connectionId: connectionId
            )
        }
        
        let photosMetaData = photos.map {
            PhotoMetadata(
                connectionId: connectionId,
                fileName: $0.lastPathComponent,
                downloadDate: Date(),
                filePath: $0
            )
        }
        
        return (zipMetaData, photosMetaData)
    }

    func saveFileMetaData(zipFileMetaData: ZipFileMetadata?, photoMetaData: [PhotoMetadata]) {
        if let zipFileMetaData = zipFileMetaData {
            modelContext.insert(zipFileMetaData)
        }
        for photoMetaData in photoMetaData {
            modelContext.insert(photoMetaData)
        }
        do {
            try modelContext.save()
        } catch {
            print("Error: \(error.localizedDescription)")
        }
    }
    
    public func fetchPhotosLocations(for predicate: Predicate<PhotoMetadata>) throws -> [PhotoMetadata] {
        fetchAndPrintAllPhotos()
        let sortDescriptor = SortDescriptor<PhotoMetadata>(\.fileName, order: .forward)
        
        let descriptor = FetchDescriptor(predicate: predicate, sortBy: [sortDescriptor])
        return try self.modelContext.fetch(descriptor)
    }
    
    func fetchAndPrintAllPhotos() {
        do {
            // Fetch all records without a predicate
            let allPhotos = try modelContext.fetch(FetchDescriptor<PhotoMetadata>())
            
            let fetchDescriptor = FetchDescriptor<PhotoMetadata>(sortBy: [SortDescriptor(\.fileName)])
            let photos = try modelContext.fetch(fetchDescriptor)
            print("Fetched photos: \(photos)")
            
            // Print count and details of each photo
            print("Total photos: \(allPhotos.count)")
            for photo in allPhotos {
                print("Photo Metadata:")
                print("- File Name: \(photo.fileName)")
                print("- Connection ID: \(photo.connectionId)")
                print("- Download Date: \(photo.downloadDate)")
                print("- File Path: \(photo.filePath)")
                print("---------------------------------")
            }
        } catch {
            print("Error fetching photos: \(error.localizedDescription)")
        }
    }
}


// App Manager(start Download)

//  - StartDownload() -> Download Package -> return (temp location, error) - Dow
//  - Move it the file location -> File package -> create directory -> store downloaded file(success, failure) - File
//  - Decyryption(location), destination -> Crypt
//  - unzip (where) - FilePackage -> return the metadata
//  - app -> Decide to storeMeta ( swiftData/CoreData )
//  - userId/Backup(zipped - cloud)/Photos(unzipped)
