import Foundation
import SwiftUI

struct QueuedReviewDraft: Identifiable, Codable, Equatable {
    var id = UUID().uuidString.lowercased()
    var draft: ReviewDraft
    var varietyName: String
    var sessionNote: String?
    var createdAt = Date()
}

struct TastingSessionDraft: Codable, Equatable {
    var id = UUID().uuidString.lowercased()
    var tastedDate = Date()
    var commonNote = ""
    var selectedVarietyIDs: [String] = []
    var activeVarietyID = ""
    var draftsByVarietyID: [String: ReviewDraft] = [:]

    enum CodingKeys: String, CodingKey {
        case id
        case tastedDate
        case commonNote
        case selectedVarietyIDs
        case activeVarietyID
        case draftsByVarietyID
    }

    init() {}

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString.lowercased()
        tastedDate = try container.decodeIfPresent(Date.self, forKey: .tastedDate) ?? Date()
        commonNote = try container.decodeIfPresent(String.self, forKey: .commonNote) ?? ""
        selectedVarietyIDs = try container.decodeIfPresent([String].self, forKey: .selectedVarietyIDs) ?? []
        activeVarietyID = try container.decodeIfPresent(String.self, forKey: .activeVarietyID) ?? selectedVarietyIDs.first ?? ""
        draftsByVarietyID = try container.decodeIfPresent([String: ReviewDraft].self, forKey: .draftsByVarietyID) ?? [:]
    }

    mutating func reset(keeping date: Date = Date()) {
        id = UUID().uuidString.lowercased()
        tastedDate = date
        commonNote = ""
        selectedVarietyIDs = []
        activeVarietyID = ""
        draftsByVarietyID = [:]
    }
}

@MainActor
final class ReviewEditorViewModel: ObservableObject {
    @Published var draft = ReviewDraft()
    @Published var sessionDraft = TastingSessionDraft()
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
    @Published var entryRequestID = UUID()

    private let repository: IchigoRepository
    private let draftStore: DraftStore
    private let draftDefaultsKey = "IchigoDB.reviewDraft.v1"
    private let queueDefaultsKey = "IchigoDB.reviewQueue.v1"
    private let sessionDefaultsKey = "IchigoDB.tastingSession.v1"
    private let draftVersion = 1

    init(repository: IchigoRepository, draftStore: DraftStore = DraftStore()) {
        self.repository = repository
        self.draftStore = draftStore
        if let restored = draftStore.load(ReviewDraft.self, for: draftDefaultsKey, version: draftVersion) {
            self.draft = restored
        } else if let data = UserDefaults.standard.data(forKey: draftDefaultsKey),
           let restored = try? JSONDecoder().decode(ReviewDraft.self, from: data) {
            self.draft = restored
        }
        if let restored = draftStore.load([QueuedReviewDraft].self, for: queueDefaultsKey, version: draftVersion) {
            self.queuedDrafts = restored
        } else if let data = UserDefaults.standard.data(forKey: queueDefaultsKey),
           let restored = try? JSONDecoder().decode([QueuedReviewDraft].self, from: data) {
            self.queuedDrafts = restored
        }
        if let restored = draftStore.load(TastingSessionDraft.self, for: sessionDefaultsKey, version: draftVersion) {
            self.sessionDraft = restored
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
        entryRequestID = UUID()
        persistDraft()
    }

    func edit(_ review: Review) {
        draft = ReviewDraft(review: review)
        selectedImages = []
        duplicatePending = false
        duplicateReviewID = nil
        message = "履歴から評価を編集中です。"
        errorMessage = nil
        entryRequestID = UUID()
        persistDraft()
    }

    func persistDraft() {
        draftStore.save(draft, for: draftDefaultsKey, version: draftVersion)
        draftStore.save(sessionDraft, for: sessionDefaultsKey, version: draftVersion)
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
            QueuedReviewDraft(draft: draftWithSessionNote(draft), varietyName: varietyName, sessionNote: cleanedSessionNote),
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

    func addBatchToQueue(varietyIDs: [String], nameResolver: (String) -> String) {
        updateTastingSessionSelection(varietyIDs, baseDraft: draft, nameResolver: nameResolver)
        queueTastingSession(nameResolver: nameResolver)
    }

    func updateTastingSessionSelection(_ varietyIDs: [String], baseDraft: ReviewDraft, nameResolver: (String) -> String) {
        let uniqueIDs = sortedUniqueVarietyIDs(varietyIDs, nameResolver: nameResolver)
        sessionDraft.selectedVarietyIDs = uniqueIDs

        var updatedDrafts = sessionDraft.draftsByVarietyID
        for varietyID in uniqueIDs where updatedDrafts[varietyID] == nil {
            var copy = baseDraft
            copy.id = nil
            copy.varietyID = varietyID
            copy.tastedDate = sessionDraft.tastedDate
            updatedDrafts[varietyID] = copy
        }
        updatedDrafts = updatedDrafts.filter { uniqueIDs.contains($0.key) }
        sessionDraft.draftsByVarietyID = updatedDrafts

        if !uniqueIDs.contains(sessionDraft.activeVarietyID) {
            sessionDraft.activeVarietyID = uniqueIDs.first ?? ""
        }
        persistDraft()
    }

    func setActiveTastingVariety(_ varietyID: String) {
        guard sessionDraft.selectedVarietyIDs.contains(varietyID) else { return }
        sessionDraft.activeVarietyID = varietyID
        persistDraft()
    }

    func updateTastingSessionDate(_ date: Date) {
        sessionDraft.tastedDate = date
        for varietyID in sessionDraft.selectedVarietyIDs {
            sessionDraft.draftsByVarietyID[varietyID]?.tastedDate = date
        }
        persistDraft()
    }

    func tastingDraft(for varietyID: String) -> ReviewDraft {
        if let existing = sessionDraft.draftsByVarietyID[varietyID] {
            return existing
        }
        var copy = draft
        copy.id = nil
        copy.varietyID = varietyID
        copy.tastedDate = sessionDraft.tastedDate
        return copy
    }

    func updateTastingDraft(_ draft: ReviewDraft, for varietyID: String) {
        var copy = draft
        copy.id = nil
        copy.varietyID = varietyID
        copy.tastedDate = sessionDraft.tastedDate
        sessionDraft.draftsByVarietyID[varietyID] = copy
        persistDraft()
    }

    func queueTastingSession(nameResolver: (String) -> String) {
        let uniqueIDs = sortedUniqueVarietyIDs(sessionDraft.selectedVarietyIDs, nameResolver: nameResolver)
        guard !uniqueIDs.isEmpty else {
            errorMessage = "食べ比べする品種を選んでください。"
            return
        }
        guard selectedImages.isEmpty else {
            errorMessage = "一括メモでは画像を保持できません。画像付き評価は1件ずつ正式登録してください。"
            return
        }

        let items = uniqueIDs.map { varietyID -> QueuedReviewDraft in
            let copy = tastingDraft(for: varietyID)
            return QueuedReviewDraft(draft: draftWithSessionNote(copy), varietyName: nameResolver(varietyID), sessionNote: cleanedSessionNote)
        }
        queuedDrafts.insert(contentsOf: items, at: 0)
        let keptDate = sessionDraft.tastedDate
        draft = ReviewDraft()
        draft.tastedDate = keptDate
        sessionDraft.reset(keeping: keptDate)
        selectedImages = []
        message = "\(items.count)件を食べ比べメモに追加しました。メモ画面からまとめて正式登録できます。"
        errorMessage = nil
        persistDraft()
        persistQueue()
    }

    private func sortedUniqueVarietyIDs(_ varietyIDs: [String], nameResolver: (String) -> String) -> [String] {
        Array(Dictionary(grouping: varietyIDs.filter { !$0.isEmpty }, by: { $0 }).keys)
            .sorted { nameResolver($0).localizedStandardCompare(nameResolver($1)) == .orderedAscending }
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
        draftStore.save(queuedDrafts, for: queueDefaultsKey, version: draftVersion)
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

    private var cleanedSessionNote: String? {
        let value = sessionDraft.commonNote.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    private func draftWithSessionNote(_ source: ReviewDraft) -> ReviewDraft {
        guard let note = cleanedSessionNote else { return source }
        var copy = source
        if copy.comment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            copy.comment = note
        } else if !copy.comment.contains(note) {
            copy.comment = "\(copy.comment)\n\(note)"
        }
        return copy
    }
}
