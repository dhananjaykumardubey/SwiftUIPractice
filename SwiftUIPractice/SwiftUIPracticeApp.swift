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

    let container: ModelContainer
    init() {
        do {
            container = try ModelContainer(for: ZipFileMetadata.self, PhotoMetadata.self)
        } catch {
            fatalError("Failed to create container")
        }
    }
    
    var body: some Scene {
        WindowGroup {
            PhotoReviewView(viewModel: PhotoGalleryViewModel(assets: [], modelContainer: container))
                .environment(\.modelContext, container.mainContext)
        }
    }
}

extension View {
    func withModelContainer() -> some View {
        modelContainer(for: [
          ZipFileMetadata.self,
          PhotoMetadata.self,
        ])
    }
}
