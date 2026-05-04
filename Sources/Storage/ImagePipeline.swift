import Foundation
import UIKit

struct ImageRequest: Hashable {
    var bucket: String
    var path: String
    var targetPixelSize: Int
    var priority: Priority

    enum Priority: Int, Hashable {
        case visible = 0
        case prefetch = 1
    }

    var cacheKey: String { "\(bucket)/\(path)#\(targetPixelSize)" }
}

final class ImagePipeline {
    private let cache: ImageCacheStore
    private let limiter: AsyncLimiter
    private let lock = NSLock()
    private var inFlight: [String: Task<UIImage?, Never>] = [:]

    init(cache: ImageCacheStore = ImageCacheStore(), maxConcurrentFetches: Int = 4) {
        self.cache = cache
        self.limiter = AsyncLimiter(limit: maxConcurrentFetches)
    }

    func cachedImage(bucket: String, path: String, targetPixelSize: Int) -> UIImage? {
        cache.image(bucket: bucket, path: path, targetPixelSize: targetPixelSize)
    }

    func image(for request: ImageRequest, repository: IchigoRepository) async -> UIImage? {
        if let cached = cachedImage(bucket: request.bucket, path: request.path, targetPixelSize: request.targetPixelSize) {
            return cached
        }

        let key = request.cacheKey
        if let task = task(for: key) {
            return await task.value
        }

        let task = Task<UIImage?, Never> {
            await limiter.acquire()
            defer { Task { await limiter.release() } }
            do {
                let data = try await repository.downloadImageData(bucket: request.bucket, path: request.path)
                return cache.store(data, bucket: request.bucket, path: request.path, targetPixelSize: request.targetPixelSize)
            } catch {
                return nil
            }
        }
        setTask(task, for: key)
        let image = await task.value
        removeTask(for: key)
        return image
    }

    func prefetch(_ sources: [VarietyThumbnailSource], repository: IchigoRepository, targetPixelSize: Int) {
        for source in sources.prefix(24) {
            Task {
                _ = await image(
                    for: ImageRequest(
                        bucket: source.bucket,
                        path: source.path,
                        targetPixelSize: targetPixelSize,
                        priority: .prefetch
                    ),
                    repository: repository
                )
            }
        }
    }

    func remove(bucket: String, path: String) {
        cache.remove(bucket: bucket, path: path)
    }

    func removeAll() {
        cache.removeAll()
    }

    private func task(for key: String) -> Task<UIImage?, Never>? {
        lock.lock()
        defer { lock.unlock() }
        return inFlight[key]
    }

    private func setTask(_ task: Task<UIImage?, Never>, for key: String) {
        lock.lock()
        defer { lock.unlock() }
        inFlight[key] = task
    }

    private func removeTask(for key: String) {
        lock.lock()
        defer { lock.unlock() }
        inFlight[key] = nil
    }
}

private actor AsyncLimiter {
    private let limit: Int
    private var active = 0
    private var waiters: [CheckedContinuation<Void, Never>] = []

    init(limit: Int) {
        self.limit = max(1, limit)
    }

    func acquire() async {
        if active < limit {
            active += 1
            return
        }
        await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }

    func release() {
        if waiters.isEmpty {
            active = max(0, active - 1)
        } else {
            let continuation = waiters.removeFirst()
            continuation.resume()
        }
    }
}
