import UIKit
import Foundation

/// Manages reading and writing perfume images to the local filesystem.
/// Database stores only filenames; this service resolves full paths.
final class ImageStorageManager {

    static let shared = ImageStorageManager()

    private let fileManager = FileManager.default

    private var imagesDirectory: URL {
        let documents = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documents.appendingPathComponent("PerfumeImages", isDirectory: true)
    }

    private var originalDirectory: URL {
        imagesDirectory.appendingPathComponent("original", isDirectory: true)
    }

    private var processedDirectory: URL {
        imagesDirectory.appendingPathComponent("processed", isDirectory: true)
    }

    private init() {
        createDirectoriesIfNeeded()
    }

    // MARK: - Setup

    private func createDirectoriesIfNeeded() {
        for dir in [imagesDirectory, originalDirectory, processedDirectory] {
            if !fileManager.fileExists(atPath: dir.path) {
                try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
            }
        }
    }

    // MARK: - Save

    /// Save original image and return the filename
    func saveOriginal(_ image: UIImage) -> String? {
        let filename = "\(UUID().uuidString).jpg"
        let fileURL = originalDirectory.appendingPathComponent(filename)
        guard let data = image.jpegData(compressionQuality: 0.9) else { return nil }
        do {
            try data.write(to: fileURL)
            return filename
        } catch {
            print("ImageStorageManager: Failed to save original — \(error)")
            return nil
        }
    }

    /// Save processed image and return the filename
    func saveProcessed(_ image: UIImage) -> String? {
        let filename = "\(UUID().uuidString).png"
        let fileURL = processedDirectory.appendingPathComponent(filename)
        guard let data = image.pngData() else { return nil }
        do {
            try data.write(to: fileURL)
            return filename
        } catch {
            print("ImageStorageManager: Failed to save processed — \(error)")
            return nil
        }
    }

    // MARK: - Load

    func loadImage(filename: String?, type: ImageType) -> UIImage? {
        guard let filename = filename else { return nil }
        let dir = type == .original ? originalDirectory : processedDirectory
        let fileURL = dir.appendingPathComponent(filename)
        guard fileManager.fileExists(atPath: fileURL.path) else { return nil }
        return UIImage(contentsOfFile: fileURL.path)
    }

    // MARK: - Delete

    func deleteImage(filename: String?, type: ImageType) {
        guard let filename = filename else { return }
        let dir = type == .original ? originalDirectory : processedDirectory
        let fileURL = dir.appendingPathComponent(filename)
        try? fileManager.removeItem(at: fileURL)
    }

    func deleteAll(for originalFilename: String?, processedFilename: String?) {
        deleteImage(filename: originalFilename, type: .original)
        deleteImage(filename: processedFilename, type: .processed)
    }
}

enum ImageType {
    case original
    case processed
}
