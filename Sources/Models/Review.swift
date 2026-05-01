import Foundation

struct Review: Identifiable, Codable, Hashable {
    var id: String
    var varietyID: String
    var tastedDate: String
    var sweetness: Int
    var sourness: Int
    var aroma: Int
    var texture: Int
    var appearance: Int
    var overall: Int
    var purchasePlace: String?
    var priceJPY: Int?
    var comment: String?
    var deletedAt: String?
    var createdAt: String?
    var updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case varietyID = "variety_id"
        case tastedDate = "tasted_date"
        case sweetness
        case sourness
        case aroma
        case texture
        case appearance
        case overall
        case purchasePlace = "purchase_place"
        case priceJPY = "price_jpy"
        case comment
        case deletedAt = "deleted_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}
