//
//  SwiftDataManager.swift
//  SwiftUIPractice
//
//  Created by Dhananjay Dubey on 24/10/24.
//

import SwiftData

// SwiftDataManager for saving metadata into SwiftData
class SwiftDataManager {
    static let shared = SwiftDataManager()
    
    func save(_ metadata: FileMetadata) async throws {
        // SwiftData save operation here
        print("Saved metadata: \(metadata)")
    }
}
