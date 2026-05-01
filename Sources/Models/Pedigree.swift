import Foundation
import CoreGraphics

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

struct PedigreeNode: Identifiable {
    var id: String
    var name: String
    var point: CGPoint = .zero
    var layer: Int = 0
}

struct PedigreeEdge: Identifiable, Hashable {
    var id: String { "\(parentID)->\(childID)" }
    var parentID: String
    var childID: String
}

enum PedigreeDirection: String, CaseIterable, Identifiable {
    case ancestors
    case descendants
    case both

    var id: String { rawValue }

    var label: String {
        switch self {
        case .ancestors: "祖先"
        case .descendants: "子孫"
        case .both: "祖先＋子孫"
        }
    }
}
