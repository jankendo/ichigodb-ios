import Foundation
import ImageIO
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
        image(bucket: bucket, path: path, targetPixelSize: 0)
    }

    func image(bucket: String, path: String, targetPixelSize: Int) -> UIImage? {
        let key = cacheKey(bucket: bucket, path: path)
        if let cached = memory.object(forKey: key as NSString) {
            return cached
        }
        let url = fileURL(for: key)
        guard let data = try? Data(contentsOf: url),
              let image = decode(data, targetPixelSize: targetPixelSize) else {
            return nil
        }
        memory.setObject(image, forKey: key as NSString, cost: data.count)
        return image
    }

    func store(_ data: Data, bucket: String, path: String) -> UIImage? {
        store(data, bucket: bucket, path: path, targetPixelSize: 0)
    }

    func store(_ data: Data, bucket: String, path: String, targetPixelSize: Int) -> UIImage? {
        guard let image = decode(data, targetPixelSize: targetPixelSize) else { return nil }
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

    private func decode(_ data: Data, targetPixelSize: Int) -> UIImage? {
        guard targetPixelSize > 0 else {
            return UIImage(data: data)
        }
        let options: [CFString: Any] = [
            kCGImageSourceShouldCache: false,
            kCGImageSourceShouldCacheImmediately: false
        ]
        guard let source = CGImageSourceCreateWithData(data as CFData, options as CFDictionary) else {
            return UIImage(data: data)
        }
        let downsampleOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: targetPixelSize
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, downsampleOptions as CFDictionary) else {
            return UIImage(data: data)
        }
        return UIImage(cgImage: cgImage)
    }
}
