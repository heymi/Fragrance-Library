import Foundation
import SwiftData

@Model
final class Perfume {
    var id: UUID
    var brand: String
    var name: String
    var concentration: String
    var volume: String
    var notes: String
    var processedImageFilename: String?
    var originalImageFilename: String?
    var ocrText: String?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        brand: String = "",
        name: String = "",
        concentration: String = "",
        volume: String = "",
        notes: String = "",
        processedImageFilename: String? = nil,
        originalImageFilename: String? = nil,
        ocrText: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.brand = brand
        self.name = name
        self.concentration = concentration
        self.volume = volume
        self.notes = notes
        self.processedImageFilename = processedImageFilename
        self.originalImageFilename = originalImageFilename
        self.ocrText = ocrText
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    /// Formatted date string for display
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: createdAt)
    }

    /// Display title: brand + name, or placeholder
    var displayTitle: String {
        if brand.isEmpty && name.isEmpty {
            return "Untitled Perfume"
        }
        if brand.isEmpty { return name }
        if name.isEmpty { return brand }
        return "\(brand) \(name)"
    }

    /// Concentration + Volume as subtitle
    var subtitle: String {
        var parts: [String] = []
        if !concentration.isEmpty { parts.append(concentration) }
        if !volume.isEmpty { parts.append(volume) }
        return parts.isEmpty ? "" : parts.joined(separator: " · ")
    }
}
