//
//  TaskQueue.swift
//  SwiftUIPractice
//
//  Created by Dhananjay Dubey on 24/10/24.
//

// Concurrency Task Queue to limit the number of concurrent downloads
actor TaskQueue {
    private let maxConcurrentTasks: Int
    private var currentTasks = 0
    
    init(maxConcurrentTasks: Int) {
        self.maxConcurrentTasks = maxConcurrentTasks
    }
    
    func enqueue(_ task: @escaping () async throws -> Void) async rethrows {
        while currentTasks >= maxConcurrentTasks {
            do {
                try await Task.sleep(nanoseconds: 100_000_000) // sleep for 100ms
            } catch {
                print("Error in TaskQueue.enqueue: \(error)")
            }
        }
        currentTasks += 1
        defer { currentTasks -= 1 }
        try await task()
    }
}
