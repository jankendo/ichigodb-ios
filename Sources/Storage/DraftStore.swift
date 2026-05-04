import Foundation

struct DraftEnvelope<Value: Codable>: Codable {
    var version: Int
    var savedAt: Date
    var value: Value
}

final class DraftStore {
    private let baseURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(folderName: String = "IchigoDBDrafts") {
        let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        self.baseURL = root.appendingPathComponent(folderName, isDirectory: true)
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
        try? FileManager.default.createDirectory(at: baseURL, withIntermediateDirectories: true)
    }

    func save<Value: Codable>(_ value: Value, for key: String, version: Int) {
        let envelope = DraftEnvelope(version: version, savedAt: Date(), value: value)
        do {
            let data = try encoder.encode(envelope)
            try data.write(to: fileURL(for: key), options: .atomic)
        } catch {
            // Draft persistence must never block the primary operation.
        }
    }

    func load<Value: Codable>(_ type: Value.Type, for key: String, version: Int) -> Value? {
        guard let data = try? Data(contentsOf: fileURL(for: key)),
              let envelope = try? decoder.decode(DraftEnvelope<Value>.self, from: data),
              envelope.version == version else {
            return nil
        }
        return envelope.value
    }

    func clear(_ key: String) {
        try? FileManager.default.removeItem(at: fileURL(for: key))
    }

    private func fileURL(for key: String) -> URL {
        baseURL.appendingPathComponent("\(safeKey(key)).json")
    }

    private func safeKey(_ key: String) -> String {
        key.map { character in
            character.isLetter || character.isNumber || character == "-" || character == "_" ? character : "_"
        }.reduce(into: "") { $0.append($1) }
    }
}
