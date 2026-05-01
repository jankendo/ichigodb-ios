import Foundation

enum ValidationError: LocalizedError, Equatable {
    case required(String)
    case length(String, Int)
    case range(String)
    case invalid(String)

    var errorDescription: String? {
        switch self {
        case .required(let label):
            return "\(label)は必須です。"
        case .length(let label, let max):
            return "\(label)は\(max)文字以内で入力してください。"
        case .range(let label):
            return "\(label)の範囲が不正です。"
        case .invalid(let label):
            return "\(label)が不正です。"
        }
    }
}

enum Validation {
    static func cleaned(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    static func requireName(_ value: String) throws -> String {
        let name = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { throw ValidationError.required("品種名") }
        guard name.count <= 100 else { throw ValidationError.length("品種名", 100) }
        return name
    }

    static func validateYear(_ value: Int?) throws -> Int? {
        guard let value else { return nil }
        let currentYear = Calendar.current.component(.year, from: Date()) + 1
        guard (1900...currentYear).contains(value) else {
            throw ValidationError.range("登録年")
        }
        return value
    }

    static func validateMonth(_ value: Int?) throws -> Int? {
        guard let value else { return nil }
        guard (1...12).contains(value) else { throw ValidationError.range("月") }
        return value
    }

    static func validateBrix(min: Double?, max: Double?) throws {
        if let min, !(0...30).contains(min) {
            throw ValidationError.range("糖度下限")
        }
        if let max, !(0...30).contains(max) {
            throw ValidationError.range("糖度上限")
        }
        if let min, let max, min > max {
            throw ValidationError.invalid("糖度")
        }
    }

    static func validateScore(_ value: Int, range: ClosedRange<Int>, label: String) throws -> Int {
        guard range.contains(value) else { throw ValidationError.range(label) }
        return value
    }

    static func isoDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    static func date(fromISO value: String) -> Date {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: value) ?? Date()
    }
}
