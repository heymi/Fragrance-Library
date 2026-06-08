import UIKit
import Vision

/// Uses Apple Vision to recognize text from perfume bottle images.
final class OCRService {

    func recognizeText(from image: UIImage) async -> OCRResult {
        guard let cgImage = image.cgImage else {
            return OCRResult(fullText: "", brand: nil, name: nil, concentration: nil, volume: nil)
        }

        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.recognitionLanguages = ["en", "fr", "zh-Hans"]

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
}
