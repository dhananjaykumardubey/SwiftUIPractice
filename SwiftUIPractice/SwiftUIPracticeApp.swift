//
//  SwiftUIPracticeApp.swift
//  SwiftUIPractice
//
//  Created by Dhananjay Dubey on 20/9/24.
//

import SwiftUI
import SwiftData

@main
struct SwiftUIPracticeApp: App {
    @StateObject private var storeConfig = StoreConfiguration()
    
    var body: some Scene {
        WindowGroup {
            if let container = storeConfig.modelContainer {
                PhotoReviewView(viewModel: PhotoGalleryViewModel(assets: []))
                    .modelContainer(container)
                    .environmentObject(storeConfig)
            } else {
                ProgressView("Initializing...")
                    .task {
                        do {
                            try await storeConfig.configure()
                        } catch {
                            print("Failed to configure SwiftData: \(error)")
                        }
                    }
            }
            
        }
    }
}

@MainActor
final class StoreConfiguration: ObservableObject {
    @Published private(set) var modelContainer: ModelContainer?
    @Published private(set) var storeManager = StorageManager.shared    
    func configure() async throws {
        try await storeManager.configure(schema: Schema([ZipFileMetadata.self, PhotoMetadata.self]))
        self.modelContainer = try storeManager.getModelContainer()
    }
}
