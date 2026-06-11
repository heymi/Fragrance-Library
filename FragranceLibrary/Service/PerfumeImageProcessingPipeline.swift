import UIKit

enum CutoutConfidence: String {
    case high
    case medium
    case low

    var title: String {
        switch self {
        case .high: return "Excellent"
        case .medium: return "Needs Check"
        case .low: return "Needs Refine"
        }
    }
}

enum CutoutSuggestedAction {
    case accept
    case review
    case manualRegion
}

struct CutoutQualityReport {
    let confidence: CutoutConfidence
    let score: Int
    let reasons: [String]
    let suggestedAction: CutoutSuggestedAction

    var allowsAutomaticSuccess: Bool {
        confidence != .low
    }
}

enum ProcessingSource: String {
    case automaticOriginalMask
    case automaticSmartCropMask
    case manualRegionMask
    case safeCropPreview

    var debugName: String { rawValue }
}

struct ProcessedPerfumeImage {
    let displayImage: UIImage
    let rawCutoutImage: UIImage?
    let ocrImages: [UIImage]
    let quality: CutoutQualityReport
    let source: ProcessingSource
}

struct CutoutCandidateScore {
    let source: ProcessingSource
    let quality: CutoutQualityReport
}

enum CutoutCandidateSelector {
    static func best(_ candidates: [CutoutCandidateScore]) -> CutoutCandidateScore? {
        candidates.max {
            rank($0) < rank($1)
        }
    }

    private static func rank(_ candidate: CutoutCandidateScore) -> Int {
        var score = candidate.quality.score
        if candidate.source == .manualRegionMask {
            score += 8
        }
        return score
    }
}

enum PerfumeProcessingMode {
    case automatic
    case manualRegion(CGRect)
    case safeCrop
}

final class PerfumeImageProcessingPipeline {
    private let processor: ImageProcessor
    private let maxVisionInputWidth: CGFloat

    init(processor: ImageProcessor = ImageProcessor(), maxVisionInputWidth: CGFloat = 1280) {
        self.processor = processor
        self.maxVisionInputWidth = maxVisionInputWidth
    }

    func process(_ image: UIImage, mode: PerfumeProcessingMode) async -> ProcessedPerfumeImage? {
        let normalized = processor.normalizeOrientation(image)
        guard let compressed = processor.downscale(normalized, maxWidth: maxVisionInputWidth) else {
            return nil
        }

        switch mode {
        case .automatic:
            return await processAutomatic(normalized: normalized, compressed: compressed)
        case let .manualRegion(rect):
            return await processManualRegion(normalized: normalized, compressed: compressed, rect: rect)
        case .safeCrop:
            return processSafeCrop(normalized: normalized, compressed: compressed)
        }
    }

    func restyleEditedCutout(_ image: UIImage) -> ProcessedPerfumeImage? {
        let quality = CutoutQualityEvaluator.evaluate(image, source: .manualRegionMask)
        let mergedQuality = CutoutQualityReport(
            confidence: quality.confidence,
            score: quality.score,
            reasons: quality.reasons.isEmpty ? ["Manual edge cleanup applied."] : quality.reasons,
            suggestedAction: quality.confidence == .low ? .review : .accept
        )

        guard let display = processor.renderCutoutCardStyle(image) else { return nil }
        debugLogFinal(
            candidates: [
                ProcessingCandidate(source: .manualRegionMask, cutout: image, quality: mergedQuality)
            ],
            selected: .manualRegionMask,
            ocrSource: "edited cutout"
        )
        return ProcessedPerfumeImage(
            displayImage: display,
            rawCutoutImage: image,
            ocrImages: [image],
            quality: mergedQuality,
            source: .manualRegionMask
        )
    }

    private func processAutomatic(normalized: UIImage, compressed: UIImage) async -> ProcessedPerfumeImage? {
        let smartCrop = await processor.smartCrop(compressed)
        let centerCrop = processor.centerCropToCardRatio(compressed)
        let enhancedSmartCrop = processor.enhance(smartCrop)

        async let originalCutout = processor.foregroundCutout(compressed)
        async let smartCutout = processor.foregroundCutout(smartCrop)

        var candidates: [ProcessingCandidate] = []
        if let cutout = await originalCutout {
            candidates.append(candidate(source: .automaticOriginalMask, cutout: cutout))
        }
        if let cutout = await smartCutout {
            candidates.append(candidate(source: .automaticSmartCropMask, cutout: cutout))
        }

        if let best = selectBestCandidate(from: candidates),
           let display = processor.renderCutoutCardStyle(best.cutout) {
            debugLogFinal(
                candidates: candidates,
                selected: best.source,
                ocrSource: "raw cutout + smart crop + center crop + original"
            )
            return ProcessedPerfumeImage(
                displayImage: display,
                rawCutoutImage: best.cutout,
                ocrImages: limitedOCRImages([best.cutout, enhancedSmartCrop, centerCrop, normalized]),
                quality: best.quality,
                source: best.source
            )
        }

        let fallback = processSafeCrop(normalized: normalized, compressed: compressed)
        debugLogFinal(candidates: candidates, selected: fallback?.source, ocrSource: "safe crop fallback")
        return fallback
    }

    private func processManualRegion(
        normalized: UIImage,
        compressed: UIImage,
        rect: CGRect
    ) async -> ProcessedPerfumeImage? {
        guard let cutout = await processor.manualBottleRegionCutout(compressed, normalizedRect: rect),
              let display = processor.renderCutoutCardStyle(cutout) else {
            return nil
        }

        let manualCandidate = candidate(source: .manualRegionMask, cutout: cutout)
        debugLogFinal(
            candidates: [manualCandidate],
            selected: .manualRegionMask,
            ocrSource: "manual cutout + original"
        )
        return ProcessedPerfumeImage(
            displayImage: display,
            rawCutoutImage: cutout,
            ocrImages: limitedOCRImages([cutout, compressed, normalized]),
            quality: manualCandidate.quality,
            source: .manualRegionMask
        )
    }

    private func processSafeCrop(normalized: UIImage, compressed: UIImage) -> ProcessedPerfumeImage? {
        let centerCrop = processor.centerCropToCardRatio(compressed)
        let enhanced = processor.enhance(centerCrop)
        guard let display = processor.renderWithCardStyle(enhanced) else { return nil }
        let quality = CutoutQualityReport(
            confidence: .low,
            score: 35,
            reasons: ["Using a safe crop because no reliable bottle cutout was found."],
            suggestedAction: .review
        )
        return ProcessedPerfumeImage(
            displayImage: display,
            rawCutoutImage: nil,
            ocrImages: limitedOCRImages([enhanced, centerCrop, normalized]),
            quality: quality,
            source: .safeCropPreview
        )
    }

    private func candidate(source: ProcessingSource, cutout: UIImage) -> ProcessingCandidate {
        ProcessingCandidate(
            source: source,
            cutout: cutout,
            quality: CutoutQualityEvaluator.evaluate(cutout, source: source)
        )
    }

    private func selectBestCandidate(from candidates: [ProcessingCandidate]) -> ProcessingCandidate? {
        let scores = candidates.map {
            CutoutCandidateScore(source: $0.source, quality: $0.quality)
        }
        guard let selected = CutoutCandidateSelector.best(scores) else {
            return nil
        }
        return candidates.first { $0.source == selected.source && $0.quality.score == selected.quality.score }
    }

    private func limitedOCRImages(_ images: [UIImage]) -> [UIImage] {
        Array(images.prefix(4))
    }

    private func debugLogFinal(
        candidates: [ProcessingCandidate],
        selected: ProcessingSource?,
        ocrSource: String
    ) {
        #if DEBUG
        print("PerfumeImageProcessingPipeline: candidates=\(candidates.count)")
        for candidate in candidates {
            print(
                "PerfumeImageProcessingPipeline: candidate source=\(candidate.source.debugName) " +
                "score=\(candidate.quality.score) confidence=\(candidate.quality.confidence.rawValue) " +
                "reasons=\(candidate.quality.reasons.joined(separator: " | "))"
            )
        }
        print("PerfumeImageProcessingPipeline: selected=\(selected?.debugName ?? "none")")
        print("PerfumeImageProcessingPipeline: ocrSource=\(ocrSource)")
        #endif
    }
}

private struct ProcessingCandidate {
    let source: ProcessingSource
    let cutout: UIImage
    let quality: CutoutQualityReport
}

enum CutoutQualityEvaluator {
    static func evaluate(_ image: UIImage, source: ProcessingSource) -> CutoutQualityReport {
        guard let stats = AlphaMaskStats(image: image) else {
            return CutoutQualityReport(
                confidence: .low,
                score: 0,
                reasons: ["Could not inspect the cutout alpha mask."],
                suggestedAction: .manualRegion
            )
        }

        var score = 82
        var reasons: [String] = []
        var fatal = false

        if stats.alphaFraction < 0.015 {
            score = min(score, 12)
            fatal = true
            reasons.append("Foreground is too small to be a complete bottle.")
        }

        if stats.alphaFraction > 0.72 {
            score = min(score, 20)
            fatal = true
            reasons.append("Foreground covers too much of the photo; likely the whole scene.")
        }

        if stats.boundingBoxArea > 0.85 {
            score = min(score, 24)
            fatal = true
            reasons.append("Detected subject fills almost the entire image.")
        }

        if stats.heightWidthRatio < 0.45 && stats.boundingBoxArea > 0.20 {
            score -= 26
            reasons.append("Detected subject is very horizontal; it may include a table or hand.")
        }

        if stats.centerOffset > 0.28 {
            score -= 12
            reasons.append("Bottle subject is far from center.")
        }

        if stats.componentCount > 12 || stats.smallComponentFraction > 0.08 {
            score -= 15
            reasons.append("Cutout edge has many fragments; clean edges before saving.")
        }

        if source == .manualRegionMask {
            score += 6
        }

        score = min(100, max(0, score))

        let confidence: CutoutConfidence
        if fatal || score < 50 {
            confidence = .low
        } else if score < 72 {
            confidence = .medium
        } else {
            confidence = .high
        }

        let suggestedAction: CutoutSuggestedAction
        switch confidence {
        case .high:
            suggestedAction = .accept
        case .medium:
            suggestedAction = .review
        case .low:
            suggestedAction = fatal ? .manualRegion : .review
        }

        return CutoutQualityReport(
            confidence: confidence,
            score: score,
            reasons: reasons,
            suggestedAction: suggestedAction
        )
    }
}

private struct AlphaMaskStats {
    let alphaFraction: CGFloat
    let boundingBoxArea: CGFloat
    let heightWidthRatio: CGFloat
    let centerOffset: CGFloat
    let componentCount: Int
    let smallComponentFraction: CGFloat

    init?(image: UIImage) {
        guard let cgImage = image.cgImage else { return nil }

        let maxDimension = 160
        let scale = min(
            1,
            CGFloat(maxDimension) / CGFloat(max(cgImage.width, cgImage.height))
        )
        let width = max(1, Int(CGFloat(cgImage.width) * scale))
        let height = max(1, Int(CGFloat(cgImage.height) * scale))
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        var pixels = [UInt8](repeating: 0, count: width * height * bytesPerPixel)

        guard let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }

        context.interpolationQuality = .medium
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        var foreground = [Bool](repeating: false, count: width * height)
        var count = 0
        var minX = width
        var minY = height
        var maxX = 0
        var maxY = 0

        for y in 0..<height {
            for x in 0..<width {
                let index = (y * width + x) * bytesPerPixel + 3
                if pixels[index] > 18 {
                    let maskIndex = y * width + x
                    foreground[maskIndex] = true
                    count += 1
                    minX = min(minX, x)
                    minY = min(minY, y)
                    maxX = max(maxX, x)
                    maxY = max(maxY, y)
                }
            }
        }

        guard count > 0 else {
            alphaFraction = 0
            boundingBoxArea = 0
            heightWidthRatio = 0
            centerOffset = 1
            componentCount = 0
            smallComponentFraction = 0
            return
        }

        let boxWidth = CGFloat(maxX - minX + 1) / CGFloat(width)
        let boxHeight = CGFloat(maxY - minY + 1) / CGFloat(height)
        let boxCenterX = (CGFloat(minX + maxX) / 2) / CGFloat(width)
        let boxCenterY = (CGFloat(minY + maxY) / 2) / CGFloat(height)
        let components = Self.connectedComponents(in: foreground, width: width, height: height)
        let tinyPixels = components
            .filter { $0 < max(6, count / 120) }
            .reduce(0, +)

        alphaFraction = CGFloat(count) / CGFloat(width * height)
        boundingBoxArea = boxWidth * boxHeight
        heightWidthRatio = boxHeight / max(boxWidth, 0.001)
        centerOffset = hypot(boxCenterX - 0.5, boxCenterY - 0.5)
        componentCount = components.count
        smallComponentFraction = CGFloat(tinyPixels) / CGFloat(count)
    }

    private static func connectedComponents(in foreground: [Bool], width: Int, height: Int) -> [Int] {
        var visited = [Bool](repeating: false, count: foreground.count)
        var sizes: [Int] = []
        let neighbors = [(1, 0), (-1, 0), (0, 1), (0, -1)]

        for start in foreground.indices where foreground[start] && !visited[start] {
            var stack = [start]
            visited[start] = true
            var size = 0

            while let current = stack.popLast() {
                size += 1
                let x = current % width
                let y = current / width

                for neighbor in neighbors {
                    let nextX = x + neighbor.0
                    let nextY = y + neighbor.1
                    guard nextX >= 0, nextX < width, nextY >= 0, nextY < height else {
                        continue
                    }
                    let next = nextY * width + nextX
                    if foreground[next] && !visited[next] {
                        visited[next] = true
                        stack.append(next)
                    }
                }
            }

            sizes.append(size)
        }

        return sizes
    }
}
