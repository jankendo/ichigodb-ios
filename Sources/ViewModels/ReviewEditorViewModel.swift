import Foundation
import SwiftUI

@MainActor
final class ReviewEditorViewModel: ObservableObject {
    @Published var draft = ReviewDraft()
    @Published var selectedImages: [UIImage] = []
    @Published var isSaving = false
    @Published var duplicatePending = false
    @Published var message: String?
    @Published var errorMessage: String?

    private let repository: IchigoRepository

    init(repository: IchigoRepository) {
        self.repository = repository
    }

    func reset(keeping varietyID: String = "") {
        draft = ReviewDraft()
        draft.varietyID = varietyID
        selectedImages = []
        duplicatePending = false
        message = nil
        errorMessage = nil
    }

    func save(overwriteDuplicate: Bool = false) async -> Review? {
        isSaving = true
        errorMessage = nil
        message = nil
        do {
            let saved = try await repository.createOrUpdateReview(draft, images: selectedImages, overwriteDuplicate: overwriteDuplicate)
            message = overwriteDuplicate ? "既存評価を上書きしました。" : "評価を登録しました。"
            reset(keeping: draft.varietyID)
            isSaving = false
            return saved
        } catch RepositoryError.duplicateReview(_) {
            duplicatePending = true
            isSaving = false
            return nil
        } catch {
            errorMessage = error.localizedDescription
            isSaving = false
            return nil
        }
    }
}
