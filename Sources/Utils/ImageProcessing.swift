import Foundation
import UIKit

struct PreparedImage {
    var data: Data
    var fileName: String
    var width: Int
    var height: Int
    var mimeType: String = "image/jpeg"
}

enum ImageProcessing {
    static func prepareJPEG(_ image: UIImage, fileName: String = "image.jpg", maxLongEdge: CGFloat = 2048) -> PreparedImage? {
        let size = image.size
        guard size.width > 0, size.height > 0 else { return nil }
        let scale = min(1, maxLongEdge / max(size.width, size.height))
        let targetSize = CGSize(width: floor(size.width * scale), height: floor(size.height * scale))
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        let rendered = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
        guard let data = rendered.jpegData(compressionQuality: 0.84) else { return nil }
        return PreparedImage(
            data: data,
            fileName: fileName.hasSuffix(".jpg") || fileName.hasSuffix(".jpeg") ? fileName : "\(fileName).jpg",
            width: Int(targetSize.width),
            height: Int(targetSize.height)
        )
    }
}
