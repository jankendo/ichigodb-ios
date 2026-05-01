import Foundation
import UIKit

final class ImageCacheStore {
    private let memory = NSCache<NSString, UIImage>()
    private let baseURL: URL

    init(folderName: String = "IchigoDBImageCache") {
        let root = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        self.baseURL = root.appendingPathComponent(folderName, isDirectory: true)
        try? FileManager.default.createDirectory(at: baseURL, withIntermediateDirectories: true)
        memory.countLimit = 240
        memory.totalCostLimit = 96 * 1024 * 1024
    }

    func image(bucket: String, path: String) -> UIImage? {
        let key = cacheKey(bucket: bucket, path: path)
        if let cached = memory.object(forKey: key as NSString) {
            return cached
        }
        let url = fileURL(for: key)
        guard let data = try? Data(contentsOf: url),
              let image = UIImage(data: data) else {
            return nil
        }
        memory.setObject(image, forKey: key as NSString, cost: data.count)
        return image
    }

    func store(_ data: Data, bucket: String, path: String) -> UIImage? {
        guard let image = UIImage(data: data) else { return nil }
        let key = cacheKey(bucket: bucket, path: path)
        memory.setObject(image, forKey: key as NSString, cost: data.count)
        try? data.write(to: fileURL(for: key), options: .atomic)
        return image
    }

    func remove(bucket: String, path: String) {
        let key = cacheKey(bucket: bucket, path: path)
        memory.removeObject(forKey: key as NSString)
        try? FileManager.default.removeItem(at: fileURL(for: key))
    }

    func removeAll() {
        memory.removeAllObjects()
        try? FileManager.default.removeItem(at: baseURL)
        try? FileManager.default.createDirectory(at: baseURL, withIntermediateDirectories: true)
    }

    private func cacheKey(bucket: String, path: String) -> String {
        "\(bucket)/\(path)"
    }

    private func fileURL(for key: String) -> URL {
        baseURL.appendingPathComponent(safeKey(key)).appendingPathExtension("img")
    }

    private func safeKey(_ key: String) -> String {
        key.map { character in
            character.isLetter || character.isNumber || character == "-" || character == "_" ? character : "_"
        }.reduce(into: "") { $0.append($1) }
    }
}
