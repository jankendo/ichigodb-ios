import Foundation
import SwiftUI

@MainActor
final class VarietyEditorViewModel: ObservableObject {
    @Published var draft = VarietyDraft()
    @Published var selectedImages: [UIImage] = []
    @Published var isSaving = false
    @Published var message: String?
    @Published var errorMessage: String?

    private let repository: IchigoRepository

    init(repository: IchigoRepository) {
        self.repository = repository
    }

    var isEditing: Bool { draft.id != nil }

    func edit(_ variety: Variety, parentLinks: [VarietyParentLink]) {
        draft = VarietyDraft(variety: variety, parentLinks: parentLinks)
        selectedImages = []
        message = nil
        errorMessage = nil
    }

    func reset() {
        draft = VarietyDraft()
        selectedImages = []
        message = nil
        errorMessage = nil
    }

    func save() async -> Variety? {
        isSaving = true
        message = nil
        errorMessage = nil
        do {
            let saved = try await repository.createOrUpdateVariety(draft, images: selectedImages)
            message = isEditing ? "品種を更新しました。" : "品種を登録しました。"
            draft = VarietyDraft(variety: saved, parentLinks: [])
            selectedImages = []
            isSaving = false
            return saved
        } catch {
            errorMessage = error.localizedDescription
            isSaving = false
            return nil
        }
    }
}
