import Foundation
import SwiftUI
import UIKit

enum UploadTaskState: String, Codable, Equatable {
    case waiting
    case uploading
    case succeeded
    case failed
}

struct QueuedUploadTask: Identifiable, Codable, Equatable {
    var id: String
    var bucket: String
    var storagePath: String
    var contentType: String
    var fileName: String
    var localFileName: String
    var createdAt: Date
    var state: UploadTaskState
    var attemptCount: Int
    var errorMessage: String?

    init(
        id: String = UUID().uuidString.lowercased(),
        bucket: String,
        storagePath: String,
        contentType: String,
        fileName: String,
        localFileName: String,
        createdAt: Date = Date(),
        state: UploadTaskState = .waiting,
        attemptCount: Int = 0,
        errorMessage: String? = nil
    ) {
        self.id = id
        self.bucket = bucket
        self.storagePath = storagePath
        self.contentType = contentType
        self.fileName = fileName
        self.localFileName = localFileName
        self.createdAt = createdAt
        self.state = state
        self.attemptCount = attemptCount
        self.errorMessage = errorMessage
    }
}

@MainActor
final class UploadQueue: ObservableObject {
    @Published private(set) var tasks: [QueuedUploadTask] = []
    @Published private(set) var isProcessing = false

    private let repository: IchigoRepository
    private let draftStore: DraftStore
    private let baseURL: URL
    private let persistenceKey = "upload_queue"
    private let version = 1

    init(repository: IchigoRepository, draftStore: DraftStore = DraftStore()) {
        self.repository = repository
        self.draftStore = draftStore
        let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        self.baseURL = root.appendingPathComponent("IchigoDBUploadQueue", isDirectory: true)
        try? FileManager.default.createDirectory(at: baseURL, withIntermediateDirectories: true)
        self.tasks = draftStore.load([QueuedUploadTask].self, for: persistenceKey, version: version) ?? []
    }

    func enqueue(bucket: String, path: String, image: UIImage, fileName: String = "upload.jpg") {
        guard let prepared = ImageProcessing.prepareJPEG(image, fileName: fileName) else { return }
        let localName = "\(UUID().uuidString.lowercased()).jpg"
        let localURL = baseURL.appendingPathComponent(localName)
        do {
            try prepared.data.write(to: localURL, options: .atomic)
            tasks.append(
                QueuedUploadTask(
                    bucket: bucket,
                    storagePath: path,
                    contentType: prepared.mimeType,
                    fileName: prepared.fileName,
                    localFileName: localName
                )
            )
            persist()
        } catch {
            // The caller can still use direct upload if queue staging fails.
        }
    }

    func retryFailed() {
        for index in tasks.indices where tasks[index].state == .failed {
            tasks[index].state = .waiting
            tasks[index].errorMessage = nil
        }
        persist()
        Task { await process() }
    }

    func process() async {
        guard !isProcessing else { return }
        isProcessing = true
        defer {
            isProcessing = false
            persist()
        }

        for index in tasks.indices where tasks[index].state == .waiting || tasks[index].state == .failed {
            tasks[index].state = .uploading
            tasks[index].attemptCount += 1
            persist()

            let task = tasks[index]
            do {
                let data = try Data(contentsOf: baseURL.appendingPathComponent(task.localFileName))
                try await repository.uploadQueuedObject(bucket: task.bucket, path: task.storagePath, data: data, contentType: task.contentType)
                tasks[index].state = .succeeded
                tasks[index].errorMessage = nil
                try? FileManager.default.removeItem(at: baseURL.appendingPathComponent(task.localFileName))
            } catch {
                tasks[index].state = .failed
                tasks[index].errorMessage = AppError.from(error).localizedDescription
            }
        }

        tasks.removeAll { $0.state == .succeeded }
    }

    private func persist() {
        draftStore.save(tasks, for: persistenceKey, version: version)
    }
}
