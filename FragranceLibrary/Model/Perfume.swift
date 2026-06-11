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

    // Scene compass radar chart
    var radarElder: Double = 0
    var radarDate: Double = 0
    var radarGirlApproved: Double = 0
    var radarOffice: Double = 0
    var radarSelf: Double = 0
    var radarImpression: Double = 0
    var strategyLine: String = ""

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
        updatedAt: Date = Date(),
        radarElder: Double = 0,
        radarDate: Double = 0,
        radarGirlApproved: Double = 0,
        radarOffice: Double = 0,
        radarSelf: Double = 0,
        radarImpression: Double = 0,
        strategyLine: String = ""
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
        self.radarElder = radarElder
        self.radarDate = radarDate
        self.radarGirlApproved = radarGirlApproved
        self.radarOffice = radarOffice
        self.radarSelf = radarSelf
        self.radarImpression = radarImpression
        self.strategyLine = strategyLine
    }

    /// Whether any radar scores have been set
    /// Whether any radar scores have been set
    var hasRadarScores: Bool {
        [radarElder, radarDate, radarGirlApproved,
         radarOffice, radarSelf, radarImpression]
            .contains(where: { $0 > 0 })
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
