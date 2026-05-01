import Foundation

protocol SupabaseImage: Identifiable, Codable, Hashable {
    var id: String { get }
    var storagePath: String { get }
    var fileName: String { get }
    var mimeType: String { get }
    var fileSizeBytes: Int { get }
    var width: Int? { get }
    var height: Int? { get }
    var createdAt: String? { get }
}

struct VarietyImage: SupabaseImage {
    var id: String
    var varietyID: String
    var storagePath: String
    var fileName: String
    var mimeType: String
    var fileSizeBytes: Int
    var width: Int?
    var height: Int?
    var isPrimary: Bool
    var createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case varietyID = "variety_id"
        case storagePath = "storage_path"
        case fileName = "file_name"
        case mimeType = "mime_type"
        case fileSizeBytes = "file_size_bytes"
        case width
        case height
        case isPrimary = "is_primary"
        case createdAt = "created_at"
    }
}

struct ReviewImage: SupabaseImage {
    var id: String
    var reviewID: String
    var storagePath: String
    var fileName: String
    var mimeType: String
    var fileSizeBytes: Int
    var width: Int?
    var height: Int?
    var createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case reviewID = "review_id"
        case storagePath = "storage_path"
        case fileName = "file_name"
        case mimeType = "mime_type"
        case fileSizeBytes = "file_size_bytes"
        case width
        case height
        case createdAt = "created_at"
    }
}
