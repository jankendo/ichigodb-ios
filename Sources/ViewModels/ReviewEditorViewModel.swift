import Foundation
import SwiftUI

@MainActor
final class ReviewEditorViewModel: ObservableObject {
    @Published var draft = ReviewDraft()
    @Published var selectedImages: [UIImage] = []
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

    init(repository: IchigoRepository) {
        self.repository = repository
        if let data = UserDefaults.standard.data(forKey: draftDefaultsKey),
           let restored = try? JSONDecoder().decode(ReviewDraft.self, from: data) {
            self.draft = restored
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

    func persistDraft() {
        if let data = try? JSONEncoder().encode(draft) {
            UserDefaults.standard.set(data, forKey: draftDefaultsKey)
        }
    }

    func save(overwriteDuplicate: Bool = false) async -> Review? {
        isSaving = true
        errorMessage = nil
        message = nil
        duplicateReviewID = nil
        do {
            let saved = try await repository.createOrUpdateReview(draft, images: selectedImages, overwriteDuplicate: overwriteDuplicate)
            let keptVarietyID = draft.varietyID
            draft = ReviewDraft()
            draft.varietyID = keptVarietyID
            selectedImages = []
            duplicatePending = false
            duplicateReviewID = nil
            message = overwriteDuplicate ? "既存評価を上書きしました。" : "評価を登録しました。"
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
