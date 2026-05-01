import Foundation
import UIKit

enum RepositoryError: LocalizedError, Equatable {
    case duplicateReview(String)
    case missingCreatedRow
    case imagePreparationFailed

    var errorDescription: String? {
        switch self {
        case .duplicateReview:
            return "同じ品種・日付の評価がすでにあります。"
        case .missingCreatedRow:
            return "保存後のデータ取得に失敗しました。"
        case .imagePreparationFailed:
            return "画像の準備に失敗しました。"
        }
    }
}

struct VarietyDraft: Equatable {
    var id: String?
    var name = ""
    var originPrefecture = ""
    var developer = ""
    var registeredYear: Int?
    var registrationNumber = ""
    var applicationNumber = ""
    var description = ""
    var characteristicsSummary = ""
    var skinColor = ""
    var fleshColor = ""
    var brixMin: Double?
    var brixMax: Double?
    var acidityLevel: AcidityLevel = .unknown
    var harvestStartMonth: Int?
    var harvestEndMonth: Int?
    var tagsText = ""
    var parentIDs: [String] = []

    init() {}

    init(variety: Variety, parentLinks: [VarietyParentLink]) {
        id = variety.id
        name = variety.name
        originPrefecture = variety.originPrefecture ?? ""
        developer = variety.developer ?? ""
        registeredYear = variety.registeredYear
        registrationNumber = variety.registrationNumber ?? ""
        applicationNumber = variety.applicationNumber ?? ""
        description = variety.description ?? ""
        characteristicsSummary = variety.characteristicsSummary ?? ""
        skinColor = variety.skinColor ?? ""
        fleshColor = variety.fleshColor ?? ""
        brixMin = variety.brixMin
        brixMax = variety.brixMax
        acidityLevel = variety.acidityLevel
        harvestStartMonth = variety.harvestStartMonth
        harvestEndMonth = variety.harvestEndMonth
        tagsText = variety.tags.joined(separator: ", ")
        parentIDs = parentLinks
            .filter { $0.childVarietyID == variety.id }
            .sorted { ($0.parentOrder ?? 0) < ($1.parentOrder ?? 0) }
            .map(\.parentVarietyID)
    }

    var tags: [String] {
        tagsText
            .split { $0 == "," || $0 == "、" || $0 == " " || $0 == "\n" }
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}

struct ReviewDraft: Equatable {
    var varietyID = ""
    var tastedDate = Date()
    var sweetness = 3
    var sourness = 3
    var aroma = 3
    var texture = 3
    var appearance = 3
    var purchasePlace = ""
    var priceJPY: Int?
    var comment = ""

    var overall: Int {
        let average = Double(sweetness + sourness + aroma + texture + appearance) / 5.0
        return min(10, max(1, Int((average * 2).rounded())))
    }
}

final class IchigoRepository {
    private let client: SupabaseClient
    private let cache: LocalCacheStore

    init(client: SupabaseClient, cache: LocalCacheStore = LocalCacheStore()) {
        self.client = client
        self.cache = cache
    }

    func fetchVarieties(includeDeleted: Bool = false) async throws -> [Variety] {
        var filters = [PostgrestFilter]()
        if !includeDeleted { filters.append(.isNull("deleted_at")) }
        let rows = try await client.select(
            Variety.self,
            table: "varieties",
            columns: "*",
            filters: filters,
            order: "name.asc",
            range: 0...4999
        )
        cache.save(rows, for: includeDeleted ? "varieties_all" : "varieties_active")
        return rows
    }

    func cachedVarieties() -> [Variety] {
        cache.load([Variety].self, for: "varieties_active") ?? []
    }

    func fetchReviews(includeDeleted: Bool = false) async throws -> [Review] {
        var filters = [PostgrestFilter]()
        if !includeDeleted { filters.append(.isNull("deleted_at")) }
        let rows = try await client.select(
            Review.self,
            table: "reviews",
            columns: "*",
            filters: filters,
            order: "tasted_date.desc",
            range: 0...4999
        )
        cache.save(rows, for: includeDeleted ? "reviews_all" : "reviews_active")
        return rows
    }

    func cachedReviews() -> [Review] {
        cache.load([Review].self, for: "reviews_active") ?? []
    }

    func fetchParentLinks() async throws -> [VarietyParentLink] {
        try await client.select(VarietyParentLink.self, table: "variety_parent_links", columns: "*", order: "parent_order.asc", range: 0...9999)
    }

    func fetchVarietyImages() async throws -> [VarietyImage] {
        try await client.select(VarietyImage.self, table: "variety_images", columns: "*", order: "created_at.desc", range: 0...9999)
    }

    func fetchReviewImages() async throws -> [ReviewImage] {
        try await client.select(ReviewImage.self, table: "review_images", columns: "*", order: "created_at.desc", range: 0...9999)
    }

    func createOrUpdateVariety(_ draft: VarietyDraft, images: [UIImage] = []) async throws -> Variety {
        let name = try Validation.requireName(draft.name)
        try Validation.validateBrix(min: draft.brixMin, max: draft.brixMax)
        let payload: [String: Any] = [
            "name": name,
            "origin_prefecture": nullOrString(draft.originPrefecture),
            "developer": nullOrString(draft.developer),
            "registered_year": nullable(try Validation.validateYear(draft.registeredYear)),
            "registration_number": nullOrString(draft.registrationNumber),
            "application_number": nullOrString(draft.applicationNumber),
            "description": nullOrString(draft.description),
            "characteristics_summary": nullOrString(draft.characteristicsSummary),
            "skin_color": nullOrString(draft.skinColor),
            "flesh_color": nullOrString(draft.fleshColor),
            "brix_min": nullable(draft.brixMin),
            "brix_max": nullable(draft.brixMax),
            "acidity_level": draft.acidityLevel.rawValue,
            "harvest_start_month": nullable(try Validation.validateMonth(draft.harvestStartMonth)),
            "harvest_end_month": nullable(try Validation.validateMonth(draft.harvestEndMonth)),
            "tags": draft.tags,
            "source_system": "manual"
        ]

        let variety: Variety
        if let id = draft.id {
            let rows = try await client.updateJSON(Variety.self, table: "varieties", payload: payload, filters: [.eq("id", id)])
            guard let first = rows.first else { throw RepositoryError.missingCreatedRow }
            variety = first
        } else {
            let id = UUID().uuidString.lowercased()
            var createPayload = payload
            createPayload["id"] = id
            let rows = try await client.insertJSON(Variety.self, table: "varieties", payload: createPayload)
            guard let first = rows.first else { throw RepositoryError.missingCreatedRow }
            variety = first
        }

        try await replaceParentLinks(childID: variety.id, parentIDs: draft.parentIDs)
        for image in images {
            _ = try await uploadVarietyImage(varietyID: variety.id, image: image)
        }
        return variety
    }

    func softDeleteVariety(id: String) async throws {
        _ = try await client.softDelete(Variety.self, table: "varieties", id: id)
    }

    func restoreVariety(id: String) async throws {
        _ = try await client.restore(Variety.self, table: "varieties", id: id)
    }

    func replaceParentLinks(childID: String, parentIDs: [String]) async throws {
        try await client.deleteRows(table: "variety_parent_links", filters: [.eq("child_variety_id", childID)])
        var seenParents = Set<String>()
        let uniqueParents = parentIDs.filter { parentID in
            guard !parentID.isEmpty, parentID != childID, !seenParents.contains(parentID) else { return false }
            seenParents.insert(parentID)
            return true
        }
        for (index, parentID) in uniqueParents.enumerated() {
            let payload: [String: Any] = [
                "id": UUID().uuidString.lowercased(),
                "child_variety_id": childID,
                "parent_variety_id": parentID,
                "parent_order": index + 1
            ]
            _ = try await client.insertJSON(VarietyParentLink.self, table: "variety_parent_links", payload: payload)
        }
    }

    func createOrUpdateReview(_ draft: ReviewDraft, images: [UIImage] = [], overwriteDuplicate: Bool = false) async throws -> Review {
        guard !draft.varietyID.isEmpty else { throw ValidationError.required("品種") }
        let tastedDate = Validation.isoDate(draft.tastedDate)
        let duplicate = try await findDuplicateReview(varietyID: draft.varietyID, tastedDate: tastedDate)
        if let duplicate, !overwriteDuplicate {
            throw RepositoryError.duplicateReview(duplicate.id)
        }

        let payload: [String: Any] = [
            "variety_id": draft.varietyID,
            "tasted_date": tastedDate,
            "sweetness": try Validation.validateScore(draft.sweetness, range: 1...5, label: "甘味"),
            "sourness": try Validation.validateScore(draft.sourness, range: 1...5, label: "酸味"),
            "aroma": try Validation.validateScore(draft.aroma, range: 1...5, label: "香り"),
            "texture": try Validation.validateScore(draft.texture, range: 1...5, label: "食感"),
            "appearance": try Validation.validateScore(draft.appearance, range: 1...5, label: "見た目"),
            "overall": try Validation.validateScore(draft.overall, range: 1...10, label: "総合"),
            "purchase_place": nullOrString(draft.purchasePlace),
            "price_jpy": nullable(draft.priceJPY),
            "comment": nullOrString(draft.comment)
        ]

        let review: Review
        if let duplicate {
            let rows = try await client.updateJSON(Review.self, table: "reviews", payload: payload, filters: [.eq("id", duplicate.id)])
            guard let first = rows.first else { throw RepositoryError.missingCreatedRow }
            review = first
        } else {
            var createPayload = payload
            createPayload["id"] = UUID().uuidString.lowercased()
            let rows = try await client.insertJSON(Review.self, table: "reviews", payload: createPayload)
            guard let first = rows.first else { throw RepositoryError.missingCreatedRow }
            review = first
        }

        for image in images {
            _ = try await uploadReviewImage(reviewID: review.id, image: image)
        }
        return review
    }

    func softDeleteReview(id: String) async throws {
        _ = try await client.softDelete(Review.self, table: "reviews", id: id)
    }

    func restoreReview(id: String) async throws {
        _ = try await client.restore(Review.self, table: "reviews", id: id)
    }

    func uploadVarietyImage(varietyID: String, image: UIImage) async throws -> VarietyImage {
        guard let prepared = ImageProcessing.prepareJPEG(image, fileName: "variety.jpg") else {
            throw RepositoryError.imagePreparationFailed
        }
        let path = "varieties/\(varietyID)/\(UUID().uuidString.lowercased()).jpg"
        try await client.uploadObject(bucket: "variety-images", path: path, data: prepared.data, contentType: prepared.mimeType)
        let payload: [String: Any] = [
            "id": UUID().uuidString.lowercased(),
            "variety_id": varietyID,
            "storage_path": path,
            "file_name": prepared.fileName,
            "mime_type": prepared.mimeType,
            "file_size_bytes": prepared.data.count,
            "width": prepared.width,
            "height": prepared.height,
            "is_primary": false
        ]
        let rows = try await client.insertJSON(VarietyImage.self, table: "variety_images", payload: payload)
        guard let first = rows.first else { throw RepositoryError.missingCreatedRow }
        return first
    }

    func uploadReviewImage(reviewID: String, image: UIImage) async throws -> ReviewImage {
        guard let prepared = ImageProcessing.prepareJPEG(image, fileName: "review.jpg") else {
            throw RepositoryError.imagePreparationFailed
        }
        let path = "reviews/\(reviewID)/\(UUID().uuidString.lowercased()).jpg"
        try await client.uploadObject(bucket: "review-images", path: path, data: prepared.data, contentType: prepared.mimeType)
        let payload: [String: Any] = [
            "id": UUID().uuidString.lowercased(),
            "review_id": reviewID,
            "storage_path": path,
            "file_name": prepared.fileName,
            "mime_type": prepared.mimeType,
            "file_size_bytes": prepared.data.count,
            "width": prepared.width,
            "height": prepared.height
        ]
        let rows = try await client.insertJSON(ReviewImage.self, table: "review_images", payload: payload)
        guard let first = rows.first else { throw RepositoryError.missingCreatedRow }
        return first
    }

    func signedURL(bucket: String, path: String) async throws -> URL {
        try await client.signedURL(bucket: bucket, path: path)
    }

    func downloadImage(bucket: String, path: String) async throws -> UIImage {
        let data = try await client.downloadObject(bucket: bucket, path: path)
        guard let image = UIImage(data: data) else {
            throw RepositoryError.imagePreparationFailed
        }
        return image
    }

    private func findDuplicateReview(varietyID: String, tastedDate: String) async throws -> Review? {
        let rows = try await client.select(
            Review.self,
            table: "reviews",
            columns: "*",
            filters: [
                .eq("variety_id", varietyID),
                .eq("tasted_date", tastedDate),
                .isNull("deleted_at")
            ],
            range: 0...0
        )
        return rows.first
    }

    private func nullOrString(_ value: String) -> Any {
        if let cleaned = Validation.cleaned(value) {
            return cleaned
        }
        return NSNull()
    }

    private func nullable<T>(_ value: T?) -> Any {
        if let value {
            return value
        }
        return NSNull()
    }
}
