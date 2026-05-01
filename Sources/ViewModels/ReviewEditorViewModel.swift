import Foundation
import SwiftUI

struct QueuedReviewDraft: Identifiable, Codable, Equatable {
    var id = UUID().uuidString.lowercased()
    var draft: ReviewDraft
    var varietyName: String
    var createdAt = Date()
}

@MainActor
final class ReviewEditorViewModel: ObservableObject {
    @Published var draft = ReviewDraft()
    @Published var selectedImages: [UIImage] = []
    @Published var queuedDrafts: [QueuedReviewDraft] = []
    @Published var isSaving = false
    @Published var duplicatePending = false
    @Published var duplicateReviewID: String?
    @Published var historyVarietyID = ""
    @Published var historyMinimumOverall = 1
    @Published var historyDateFrom = Calendar.current.date(byAdding: .month, value: -3, to: Date()) ?? Date()
    @Published var historyDateTo = Date()
    @Published var message: String?
    @Published var errorMessage: String?

    private let repository: IchigoRepository
    private let draftDefaultsKey = "IchigoDB.reviewDraft.v1"
    private let queueDefaultsKey = "IchigoDB.reviewQueue.v1"

    init(repository: IchigoRepository) {
        self.repository = repository
        if let data = UserDefaults.standard.data(forKey: draftDefaultsKey),
           let restored = try? JSONDecoder().decode(ReviewDraft.self, from: data) {
            self.draft = restored
        }
        if let data = UserDefaults.standard.data(forKey: queueDefaultsKey),
           let restored = try? JSONDecoder().decode([QueuedReviewDraft].self, from: data) {
            self.queuedDrafts = restored
        }
    }

    func reset(keeping varietyID: String = "") {
        draft = ReviewDraft()
        draft.varietyID = varietyID
        selectedImages = []
        duplicatePending = false
        duplicateReviewID = nil
        message = nil
        errorMessage = nil
        persistDraft()
    }

    func edit(_ review: Review) {
        draft = ReviewDraft(review: review)
        selectedImages = []
        duplicatePending = false
        duplicateReviewID = nil
        message = "履歴から評価を編集中です。"
        errorMessage = nil
        persistDraft()
    }

    func persistDraft() {
        if let data = try? JSONEncoder().encode(draft) {
            UserDefaults.standard.set(data, forKey: draftDefaultsKey)
        }
    }

    func addCurrentDraftToQueue(varietyName: String) {
        guard !draft.varietyID.isEmpty else {
            errorMessage = "品種を選んでからメモに追加してください。"
            return
        }
        guard selectedImages.isEmpty else {
            errorMessage = "画像付き評価はメモに保持せず、正式登録で保存してください。"
            return
        }
        queuedDrafts.insert(
            QueuedReviewDraft(draft: draft, varietyName: varietyName),
            at: 0
        )
        let keptDate = draft.tastedDate
        draft = ReviewDraft()
        draft.tastedDate = keptDate
        selectedImages = []
        message = "評価メモに追加しました。最後にまとめて正式登録できます。"
        errorMessage = nil
        persistDraft()
        persistQueue()
    }

    func loadQueuedDraft(_ item: QueuedReviewDraft) {
        draft = item.draft
        queuedDrafts.removeAll { $0.id == item.id }
        selectedImages = []
        message = "評価メモを編集できます。保存するか、もう一度メモに戻してください。"
        errorMessage = nil
        persistDraft()
        persistQueue()
    }

    func removeQueuedDraft(_ id: String) {
        queuedDrafts.removeAll { $0.id == id }
        persistQueue()
    }

    func saveQueuedDrafts() async -> Int {
        guard !queuedDrafts.isEmpty else { return 0 }
        isSaving = true
        message = nil
        errorMessage = nil
        var savedCount = 0
        var failed = [QueuedReviewDraft]()
        for item in queuedDrafts.reversed() {
            do {
                _ = try await repository.createOrUpdateReview(item.draft, images: [], overwriteDuplicate: true)
                savedCount += 1
            } catch {
                failed.append(item)
            }
        }
        queuedDrafts = Array(failed.reversed())
        isSaving = false
        if failed.isEmpty {
            message = "\(savedCount)件の評価を正式登録しました。"
        } else {
            errorMessage = "\(savedCount)件を登録しました。\(failed.count)件は未登録のまま残しました。"
        }
        persistQueue()
        return savedCount
    }

    private func persistQueue() {
        if let data = try? JSONEncoder().encode(queuedDrafts) {
            UserDefaults.standard.set(data, forKey: queueDefaultsKey)
        }
    }

    func save(overwriteDuplicate: Bool = false) async -> Review? {
        isSaving = true
        errorMessage = nil
        message = nil
        duplicateReviewID = nil
        do {
            let wasEditing = draft.id != nil
            let saved = try await repository.createOrUpdateReview(draft, images: selectedImages, overwriteDuplicate: overwriteDuplicate)
            let keptVarietyID = draft.varietyID
            draft = ReviewDraft()
            if saved.varietyID == keptVarietyID {
                draft.varietyID = keptVarietyID
            }
            selectedImages = []
            duplicatePending = false
            duplicateReviewID = nil
            message = overwriteDuplicate ? "既存評価を上書きしました。" : wasEditing ? "評価を更新しました。" : "評価を登録しました。"
            persistDraft()
            isSaving = false
            return saved
        } catch RepositoryError.duplicateReview(let id) {
            duplicatePending = true
            duplicateReviewID = id
            isSaving = false
            return nil
        } catch {
            errorMessage = error.localizedDescription
            isSaving = false
            return nil
        }
    }

    func deleteReview(id: String) async -> Bool {
        message = nil
        errorMessage = nil
        do {
            try await repository.softDeleteReview(id: id)
            message = "評価を削除しました。"
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func restoreReview(id: String) async -> Bool {
        message = nil
        errorMessage = nil
        do {
            try await repository.restoreReview(id: id)
            message = "評価を復元しました。"
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func deleteImage(_ image: ReviewImage) async -> Bool {
        message = nil
        errorMessage = nil
        do {
            try await repository.deleteReviewImage(id: image.id)
            message = "評価画像を削除しました。"
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}
