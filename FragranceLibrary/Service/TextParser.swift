import Foundation

/// Rule-based parser that extracts perfume metadata from OCR text.
final class TextParser {

    // MARK: - Known Brands (case-insensitive matching)

    private let knownBrands: [String] = [
        "Chanel",
        "Dior",
        "Hermès", "Hermes",
        "Tom Ford",
        "Jo Malone",
        "YSL", "Yves Saint Laurent",
        "Maison Margiela",
        "Le Labo",
        "Byredo",
        "Diptyque",
        "Creed",
        "Gucci",
        "Prada",
        "Armani", "Giorgio Armani",
        "Burberry"
    ]

    // MARK: - Concentration Patterns

    private let concentrationPatterns: [(pattern: String, normalized: String)] = [
        ("Eau\\s+de\\s+Parfum", "EDP"),
        ("Eau\\s+de\\s+Toilette", "EDT"),
        ("Eau\\s+de\\s+Cologne", "EDC"),
        ("Parfum", "Parfum"),
        ("Extrait", "Extrait"),
        ("EDP", "EDP"),
        ("EDT", "EDT"),
        ("EDC", "EDC"),
        ("Cologne", "Cologne")
    ]

    // MARK: - Volume Pattern

    private let volumePattern = try! NSRegularExpression(
        pattern: #"\b(\d{2,3})\s*ml\b"#,
        options: [.caseInsensitive]
    )

    // MARK: - Parse

    struct ParsedResult {
        var brand: String?
        var name: String?
        var concentration: String?
        var volume: String?
    }

    func parse(_ text: String) -> ParsedResult {
        var result = ParsedResult()

        let normalizedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedText.isEmpty else { return result }

        let lines = normalizedText
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        // 1. Brand matching
        result.brand = findBrand(in: lines)

        // 2. Concentration extraction
        result.concentration = findConcentration(in: normalizedText)

        // 3. Volume extraction
        result.volume = findVolume(in: normalizedText)

        // 4. Name inference — longest line that isn't brand/concentration
        result.name = inferName(from: lines, brand: result.brand, concentration: result.concentration)

        return result
    }

    // MARK: - Private Methods

    private func findBrand(in lines: [String]) -> String? {
        let fullText = lines.joined(separator: " ").lowercased()

        for brand in knownBrands {
            if fullText.contains(brand.lowercased()) {
                // Return the canonical form (first in the tuple if variant exists)
                return canonicalBrand(brand)
            }
        }
        return nil
    }

    private func canonicalBrand(_ matched: String) -> String {
        let mapping: [String: String] = [
            "hermes": "Hermès",
            "hermès": "Hermès",
            "ysl": "YSL",
            "yves saint laurent": "YSL",
            "armani": "Armani",
            "giorgio armani": "Armani",
            "tom ford": "Tom Ford",
            "jo malone": "Jo Malone",
            "maison margiela": "Maison Margiela",
            "le labo": "Le Labo"
        ]
        return mapping[matched.lowercased()] ?? matched
    }

    private func findConcentration(in text: String) -> String? {
        for (pattern, normalized) in concentrationPatterns {
            if text.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil {
                return normalized
            }
        }
        return nil
    }

    private func findVolume(in text: String) -> String? {
        let range = NSRange(text.startIndex..., in: text)
        guard let match = volumePattern.firstMatch(in: text, options: [], range: range) else {
            return nil
        }
        if let matchRange = Range(match.range(at: 0), in: text) {
            let matched = String(text[matchRange])
            return matched.replacingOccurrences(of: " ", with: "").lowercased()
        }
        return nil
    }

    private func inferName(
        from lines: [String],
        brand: String?,
        concentration: String?
    ) -> String? {
        // Find the longest line that isn't the brand or concentration
        let candidates = lines.filter { line in
            let lower = line.lowercased()
            if let b = brand, lower.contains(b.lowercased()) { return false }
            if let c = concentration, lower.contains(c.lowercased()) { return false }
            // Filter out volume lines
            if volumePattern.firstMatch(
                in: line,
                options: [],
                range: NSRange(line.startIndex..., in: line)
            ) != nil {
                return false
            }
            // Filter out very short lines / noise
            return line.count > 2
        }

        // Prefer longest candidate
        return candidates.max(by: { $0.count < $1.count })
    }
}
