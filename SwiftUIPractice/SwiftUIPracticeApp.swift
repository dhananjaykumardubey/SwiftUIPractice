//
//  SwiftUIPracticeApp.swift
//  SwiftUIPractice
//
//  Created by Dhananjay Dubey on 20/9/24.
//

import SwiftUI

@main
struct SwiftUIPracticeApp: App {
    var body: some Scene {
        WindowGroup {
            PhotoReviewView(viewModel: PhotoGalleryViewModel(assets: []))
        }
    }
}
