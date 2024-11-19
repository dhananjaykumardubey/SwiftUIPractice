//
//  TaskQueue.swift
//  SwiftUIPractice
//
//  Created by Dhananjay Dubey on 24/10/24.
//

// Concurrency Task Queue to limit the number of concurrent downloads
import Foundation

actor AsyncSemaphore {
    private let maxPermits: Int
    private var availablePermits: Int
    private var waitQueue: [CheckedContinuation<Void, Never>] = []

    init(maxPermits: Int) {
        self.maxPermits = maxPermits
        self.availablePermits = maxPermits
    }

    func wait() async {
        if availablePermits > 0 {
            availablePermits -= 1
        } else {
            await withCheckedContinuation { continuation in
                waitQueue.append(continuation)
            }
        }
    }

    func signal() async {
        if let continuation = waitQueue.first {
            waitQueue.removeFirst()
            continuation.resume()
        } else {
            availablePermits += 1
        }
    }
}

actor DownloadTaskQueue {
    private let semaphore: AsyncSemaphore

    init(maxConcurrentTasks: Int) {
        self.semaphore = AsyncSemaphore(maxPermits: maxConcurrentTasks)
    }
    func enqueue(_ task: @escaping () async throws -> Void) async rethrows {
        await semaphore.wait()
        do {
            try await task()
        } catch {
            throw error
        }
        await semaphore.signal()
    }
}
