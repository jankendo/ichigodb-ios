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
            draft.parentIDs = try normalizedParentIDs()
            let saved = try await repository.createOrUpdateVariety(draft, images: selectedImages)
            message = isEditing ? "品種を更新しました。" : "品種を登録しました。"
            draft = VarietyDraft(variety: saved, parentLinks: draft.parentIDs.enumerated().map {
                VarietyParentLink(id: UUID().uuidString.lowercased(), childVarietyID: saved.id, parentVarietyID: $0.element, parentOrder: $0.offset + 1)
            })
            selectedImages = []
            isSaving = false
            return saved
        } catch {
            errorMessage = error.localizedDescription
            isSaving = false
            return nil
        }
    }

    func setPrimaryImage(varietyID: String, imageID: String) async -> Bool {
        message = nil
        errorMessage = nil
        do {
            try await repository.setPrimaryVarietyImage(varietyID: varietyID, imageID: imageID)
            message = "メイン画像を更新しました。"
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func deleteImage(_ image: VarietyImage) async -> Bool {
        message = nil
        errorMessage = nil
        do {
            try await repository.deleteVarietyImage(id: image.id)
            message = "画像を削除しました。"
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func softDeleteCurrent() async -> Bool {
        guard let id = draft.id else { return false }
        message = nil
        errorMessage = nil
        do {
            try await repository.softDeleteVariety(id: id)
            reset()
            message = "品種を削除しました。"
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func restore(id: String) async -> Bool {
        message = nil
        errorMessage = nil
        do {
            try await repository.restoreVariety(id: id)
            message = "品種を復元しました。"
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    private func normalizedParentIDs() throws -> [String] {
        let ownID = draft.id ?? ""
        let cleaned = draft.parentIDs
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        if cleaned.contains(ownID) {
            throw ValidationError.invalid("親品種")
        }
        if Set(cleaned).count != cleaned.count {
            throw ValidationError.invalid("親品種")
        }
        var seen = Set<String>()
        var unique = [String]()
        for parentID in cleaned where !seen.contains(parentID) {
            seen.insert(parentID)
            unique.append(parentID)
        }
        return unique
    }
}
