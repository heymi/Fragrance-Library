import XCTest
import UIKit
@testable import FragranceLibrary

final class CutoutQualityReportTests: XCTestCase {
    func testTransparentCutoutIsLowConfidence() {
        let image = alphaMaskImage { _ in }

        let report = CutoutQualityEvaluator.evaluate(image, source: .automaticOriginalMask)

        XCTAssertEqual(report.confidence, .low)
        XCTAssertEqual(report.suggestedAction, .manualRegion)
    }

    func testWholeSceneCutoutIsRejected() {
        let image = alphaMaskImage { rect in
            UIColor.black.setFill()
            UIBezierPath(rect: rect).fill()
        }

        let report = CutoutQualityEvaluator.evaluate(image, source: .automaticOriginalMask)

        XCTAssertEqual(report.confidence, .low)
        XCTAssertTrue(report.reasons.contains { $0.contains("whole scene") || $0.contains("entire image") })
    }

    func testCenteredVerticalBottleShapeIsHighConfidence() {
        let image = alphaMaskImage { rect in
            UIColor.black.setFill()
            let bottle = CGRect(
                x: rect.midX - rect.width * 0.11,
                y: rect.midY - rect.height * 0.34,
                width: rect.width * 0.22,
                height: rect.height * 0.68
            )
            UIBezierPath(roundedRect: bottle, cornerRadius: 18).fill()
        }

        let report = CutoutQualityEvaluator.evaluate(image, source: .automaticSmartCropMask)

        XCTAssertEqual(report.confidence, .high)
        XCTAssertGreaterThanOrEqual(report.score, 72)
    }

    func testHorizontalLargeShapeNeedsReview() {
        let image = alphaMaskImage { rect in
            UIColor.black.setFill()
            let horizontal = CGRect(
                x: rect.width * 0.08,
                y: rect.midY - rect.height * 0.12,
                width: rect.width * 0.84,
                height: rect.height * 0.24
            )
            UIBezierPath(roundedRect: horizontal, cornerRadius: 14).fill()
        }

        let report = CutoutQualityEvaluator.evaluate(image, source: .automaticOriginalMask)

        XCTAssertNotEqual(report.confidence, .high)
        XCTAssertTrue(report.reasons.contains { $0.contains("horizontal") })
    }

    func testManualCandidateWinsWhenScoresAreClose() {
        let automatic = CutoutCandidateScore(
            source: .automaticOriginalMask,
            quality: CutoutQualityReport(
                confidence: .medium,
                score: 65,
                reasons: [],
                suggestedAction: .review
            )
        )
        let manual = CutoutCandidateScore(
            source: .manualRegionMask,
            quality: CutoutQualityReport(
                confidence: .medium,
                score: 61,
                reasons: [],
                suggestedAction: .review
            )
        )

        let selected = CutoutCandidateSelector.best([automatic, manual])

        XCTAssertEqual(selected?.source, .manualRegionMask)
    }

    private func alphaMaskImage(
        size: CGSize = CGSize(width: 300, height: 420),
        draw: (CGRect) -> Void
    ) -> UIImage {
        let format = UIGraphicsImageRendererFormat.default()
        format.opaque = false
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            draw(CGRect(origin: .zero, size: size))
        }
    }
}
