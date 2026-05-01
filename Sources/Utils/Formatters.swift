import Foundation

enum IchigoFormat {
    static func month(_ value: Int?) -> String {
        guard let value else { return "-" }
        return "\(value)月"
    }

    static func brix(min: Double?, max: Double?) -> String {
        switch (min, max) {
        case (.some(let min), .some(let max)):
            return "\(trim(min))-\(trim(max))"
        case (.some(let min), nil):
            return "\(trim(min))-"
        case (nil, .some(let max)):
            return "-\(trim(max))"
        default:
            return "-"
        }
    }

    static func date(_ iso: String?) -> String {
        guard let iso, !iso.isEmpty else { return "-" }
        return iso
    }

    static func trim(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(value)) : String(format: "%.1f", value)
    }
}
