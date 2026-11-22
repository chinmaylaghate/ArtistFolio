import CloudKit
import CryptoKit
import ImageIO
import SwiftUI
import UniformTypeIdentifiers

enum ImageStore {
    private static var directory: URL {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let url = base.appendingPathComponent("ArtworkImages", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    static func cache(_ asset: CKAsset, key: String) -> URL? {
        guard let source = asset.fileURL else { return nil }
        return cacheFile(source, key: key)
    }

    static func cacheFile(_ source: URL, key: String) -> URL? {
        let hash = SHA256.hash(data: Data(key.utf8)).map { String(format: "%02x", $0) }.joined()
        let target = directory.appendingPathComponent(hash).appendingPathExtension("jpg")
        if FileManager.default.fileExists(atPath: target.path) { return target }
        do {
            try FileManager.default.copyItem(at: source, to: target)
            return target
        } catch {
            return FileManager.default.fileExists(atPath: target.path) ? target : nil
        }
    }

    static func temporaryFile(_ data: Data) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("jpg")
        try data.write(to: url, options: .atomic)
        return url
    }
}

enum ImageProcessor {
    static let fullPixels = 2048
    static let thumbnailPixels = 600

    static func process(_ data: Data) throws -> ProcessedImage {
        guard let full = encode(data, maxPixels: fullPixels, quality: 0.82),
              let thumbnail = encode(data, maxPixels: thumbnailPixels, quality: 0.75) else {
            throw AppError.invalidImage
        }
        return ProcessedImage(full: full, thumbnail: thumbnail)
    }

    static func downsample(_ url: URL, maxPixels: Int) -> UIImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, [kCGImageSourceShouldCache: false] as CFDictionary),
              let image = thumbnail(source, maxPixels: maxPixels) else { return nil }
        return UIImage(cgImage: image)
    }

    private static func encode(_ data: Data, maxPixels: Int, quality: CGFloat) -> Data? {
        guard let source = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary),
              let image = thumbnail(source, maxPixels: maxPixels) else { return nil }
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(output, UTType.jpeg.identifier as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary)
        return CGImageDestinationFinalize(destination) ? output as Data : nil
    }

    private static func thumbnail(_ source: CGImageSource, maxPixels: Int) -> CGImage? {
        CGImageSourceCreateThumbnailAtIndex(source, 0, [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixels
        ] as CFDictionary)
    }
}

struct CloudImage: View {
    let url: URL?
    var maxPixels: Int = 900
    var contentMode: ContentMode = .fill
    @State private var image: UIImage?

    var body: some View {
        ZStack {
            Color(uiColor: .secondarySystemBackground)
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
                    .transition(.opacity)
            } else {
                Image(systemName: "photo.artframe")
                    .font(.title)
                    .foregroundStyle(.tertiary)
            }
        }
        .task(id: url) {
            guard let url else { image = nil; return }
            let pixels = maxPixels
            let loaded = await Task.detached(priority: .userInitiated) {
                ImageProcessor.downsample(url, maxPixels: pixels)
            }.value
            guard !Task.isCancelled else { return }
            withAnimation(.easeIn(duration: 0.15)) { image = loaded }
        }
    }
}
