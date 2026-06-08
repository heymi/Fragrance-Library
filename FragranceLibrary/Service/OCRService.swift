import UIKit
import Vision

/// Uses Apple Vision to recognize text from perfume bottle images.
final class OCRService {

    func recognizeBestText(from images: [UIImage]) async -> OCRResult {
        var best = OCRResult(fullText: "", brand: nil, name: nil, concentration: nil, volume: nil)

        for image in images {
            let result = await recognizeText(from: image)
            if score(result) > score(best) {
                best = result
            }
        }

        return best
    }

    func recognizeText(from image: UIImage) async -> OCRResult {
        let normalized = image.fragranceNormalizedUp()

        guard let cgImage = normalized.cgImage else {
            return OCRResult(fullText: "", brand: nil, name: nil, concentration: nil, volume: nil)
        }

        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.recognitionLanguages = ["en", "fr", "zh-Hans"]
        request.minimumTextHeight = 0.01
        request.customWords = [
            "CHANEL", "DIOR", "HERMES", "HERMÈS", "TOM FORD", "JO MALONE",
            "YSL", "LE LABO", "BYREDO", "DIPTYQUE", "CREED", "EAU DE PARFUM",
            "EAU DE TOILETTE", "PARFUM", "EXTRAIT", "COLOGNE"
        ]

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

        do {
            try handler.perform([request])
        } catch {
            print("OCRService: Vision request failed — \(error)")
            return OCRResult(fullText: "", brand: nil, name: nil, concentration: nil, volume: nil)
        }

        guard let observations = request.results else {
            return OCRResult(fullText: "", brand: nil, name: nil, concentration: nil, volume: nil)
        }

        // Collect recognized text lines, sorted top-to-bottom
        let lines = observations
            .sorted { lhs, rhs in
                let yDistance = abs(lhs.boundingBox.midY - rhs.boundingBox.midY)
                if yDistance > 0.02 {
                    return lhs.boundingBox.midY > rhs.boundingBox.midY
                }
                return lhs.boundingBox.minX < rhs.boundingBox.minX
            }
            .compactMap { $0.topCandidates(1).first?.string }
        let fullText = lines.joined(separator: "\n")

        // Parse with rule-based parser
        let parser = TextParser()
        let parsed = parser.parse(fullText)

        return OCRResult(
            fullText: fullText,
            brand: parsed.brand,
            name: parsed.name,
            concentration: parsed.concentration,
            volume: parsed.volume
        )
    }

    private func score(_ result: OCRResult) -> Int {
        let filledFields = [
            result.brand,
            result.name,
            result.concentration,
            result.volume
        ].filter { ($0?.isEmpty == false) }.count

        return filledFields * 1_000 + result.fullText.count
    }
}
