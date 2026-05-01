import Foundation

final class LocalCacheStore {
    private let baseURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(folderName: String = "IchigoDBCache") {
        let root = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        self.baseURL = root.appendingPathComponent(folderName, isDirectory: true)
        try? FileManager.default.createDirectory(at: baseURL, withIntermediateDirectories: true)
    }

    func save<T: Encodable>(_ value: T, for key: String) {
        let url = baseURL.appendingPathComponent("\(safeKey(key)).json")
        do {
            let data = try encoder.encode(value)
            try data.write(to: url, options: .atomic)
        } catch {
            // Cache writes are best effort.
        }
    }

    func load<T: Decodable>(_ type: T.Type, for key: String) -> T? {
        let url = baseURL.appendingPathComponent("\(safeKey(key)).json")
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? decoder.decode(type, from: data)
    }

    func clear(key: String) {
        try? FileManager.default.removeItem(at: baseURL.appendingPathComponent("\(safeKey(key)).json"))
    }

    private func safeKey(_ key: String) -> String {
        key.map { character in
            character.isLetter || character.isNumber || character == "-" || character == "_" ? character : "_"
        }.reduce(into: "") { $0.append($1) }
    }
}
