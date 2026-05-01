import Foundation

struct VarietyParentLink: Identifiable, Codable, Hashable {
    var id: String
    var childVarietyID: String
    var parentVarietyID: String
    var parentOrder: Int?
    var crossedYear: Int?
    var note: String?
    var createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case childVarietyID = "child_variety_id"
        case parentVarietyID = "parent_variety_id"
        case parentOrder = "parent_order"
        case crossedYear = "crossed_year"
        case note
        case createdAt = "created_at"
    }
}
