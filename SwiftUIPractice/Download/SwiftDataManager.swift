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
public protocol StorageProtocol {
    func save<T: PersistentModel>(_ item: T) async throws
    func update<T: PersistentModel>(_ item: T) async throws
    func delete<T: PersistentModel>(_ item: T) async throws
    func fetch<T: PersistentModel>(_ type: T.Type, predicate: Predicate<T>?) async throws -> [T]
    func fetchBatch<T: PersistentModel>(predicate: Predicate<T>?, sortDescriptors: [SortDescriptor<T>]) async throws -> [T] where T: Sendable
}

// MARK: - Storage Manager
//@DatabaseActor
public final class StorageManager: StorageProtocol, @unchecked Sendable {
    public static let shared = StorageManager()

//    @DatabaseActor
    private var modelContainer: ModelContainer?
    
//    @DatabaseActor
    private var backgroundContext: ModelContext?

    private init() {}

//    @DatabaseActor
    public func configure(schema: Schema, isPreview: Bool = false) async throws {
        let modelConfiguration = ModelConfiguration(isStoredInMemoryOnly: isPreview)
        self.modelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
        if let container = modelContainer {
            self.backgroundContext = ModelContext(container)
        }
    }

//    @DatabaseActor
    public func getModelContainer() throws -> ModelContainer {
        guard let container = modelContainer else {
            throw StorageError.modelContainerNotFound
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

final class DownloadFileMetaDataManager: Sendable {
    
    static func saveZipAndPhotoMetadata(zipFileURL: URL?,
                                 photos: [URL],
                                 for connectionId: String) throws {
      
        var zipMetaData: ZipFileMetadata?
        
        if let zipFileURL = zipFileURL {
            zipMetaData = ZipFileMetadata(
                fileName: zipFileURL.lastPathComponent,
                downloadDate: Date(),
                filePath: zipFileURL,
                connectionId: connectionId
            )

            if let zipMetaData = zipMetaData {
//                try await DatabaseActor.shared.performDatabaseTask {
                    try StorageManager.shared.save(zipMetaData)
//                }
            }
            
//            let descriptor = FetchDescriptor<ZipFileMetadata>(
//                predicate: zipExistsPredicate
//            )
//
//            if try modelContext?.fetch(descriptor).isEmpty == true,
//               let context = modelContext,
//               let zipMetaData = zipMetaData {
            //                context.insert(zipMetaData)
            //            }
        }
        
        for photoURL in photos {
            let photoMetaData = PhotoMetadata(
                connectionId: connectionId,
                fileName: photoURL.lastPathComponent,
                downloadDate: Date(),
                filePath: photoURL
            )
            
            try StorageManager.shared.save(photoMetaData)
        }
    }
    
//    @DatabaseActor
//    func fetchZipMetadata(byFilename filename: String) async throws -> [ZipFileMetadata] {
//        let predicate = Predicate<ZipFileMetadata>(\.fileName == filename)
//        let results = try await context.fetch(descriptor)
//        return Task.init {
//            return results
//        }
//    }
//
//    private func saveToSwiftData(photoMetadata: PhotoMetadata) async throws {
//
//    }
}
