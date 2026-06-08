import UIKit
import CoreImage
import Vision

/// Processes perfume photos: compress, crop, enhance, render with card-style border.
final class ImageProcessor {

    // MARK: - Orientation

    func normalizeOrientation(_ image: UIImage) -> UIImage {
        image.fragranceNormalizedUp()
    }

    // MARK: - Downscale

    func downscale(_ image: UIImage, maxWidth: CGFloat) -> UIImage? {
        let normalized = normalizeOrientation(image)
        let scale = normalized.size.width > maxWidth ? maxWidth / normalized.size.width : 1.0
        let targetSize = CGSize(
            width: normalized.size.width * scale,
            height: normalized.size.height * scale
        )
        return resize(normalized, to: targetSize)
    }

    // MARK: - Center Crop to Card Ratio

    func centerCropToCardRatio(_ image: UIImage) -> UIImage {
        let image = normalizeOrientation(image)
        let ratio = PerfumeLayout.cardAspectRatio
        guard let cgImage = image.cgImage else { return image }

        let imageSize = CGSize(width: cgImage.width, height: cgImage.height)
        let cropRect = centeredAspectCrop(
            in: CGRect(origin: .zero, size: imageSize),
            around: CGPoint(x: imageSize.width / 2, y: imageSize.height / 2),
            ratio: ratio
        )

        guard let croppedCGImage = cgImage.cropping(to: safePixelRect(cropRect, in: cgImage)) else {
            return image
        }
        return UIImage(cgImage: croppedCGImage, scale: image.scale, orientation: .up)
    }

    // MARK: - Enhance Colors

    func enhance(_ image: UIImage) -> UIImage {
        let image = normalizeOrientation(image)
        guard let ciImage = CIImage(image: image) else { return image }

        let controls = ciImage
            .applyingFilter("CIColorControls", parameters: [
                kCIInputBrightnessKey: 0.05,
                kCIInputContrastKey: 1.10,
                kCIInputSaturationKey: 0.95
            ])

        let context = CIContext()
        guard let outputCG = context.createCGImage(controls, from: controls.extent) else {
            return image
        }
        return UIImage(cgImage: outputCG, scale: image.scale, orientation: .up)
    }

    // MARK: - Saliency-Based Smart Crop

    /// Detects the most prominent object region using Vision saliency.
    /// Returns a normalized bounding box (0–1), or nil if nothing stands out.
    func detectSalientRegion(_ image: UIImage) async -> CGRect? {
        let image = normalizeOrientation(image)
        guard let cgImage = image.cgImage else { return nil }
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

        let objectnessRequest = VNGenerateObjectnessBasedSaliencyImageRequest()
        if let rect = performSaliencyRequest(objectnessRequest, handler: handler) {
            return rect
        }

        let attentionRequest = VNGenerateAttentionBasedSaliencyImageRequest()
        return performSaliencyRequest(attentionRequest, handler: handler)
    }

    private func performSaliencyRequest(
        _ request: VNImageBasedRequest,
        handler: VNImageRequestHandler
    ) -> CGRect? {
        do {
            try handler.perform([request])
        } catch {
            return nil
        }

        guard let result = request.results?.first as? VNSaliencyImageObservation,
              let objects = result.salientObjects, !objects.isEmpty else {
            return nil
        }

        return prominentSaliencyRect(from: objects.map(\.boundingBox))
    }

    /// Crops the image with the salient region centered, falling back to
    /// a gentle center crop if no region is detected.
    func smartCrop(_ image: UIImage) async -> UIImage {
        let image = normalizeOrientation(image)
        let ratio = PerfumeLayout.cardAspectRatio
        guard let cgImage = image.cgImage else { return image }

        let imageBounds = CGRect(
            x: 0,
            y: 0,
            width: CGFloat(cgImage.width),
            height: CGFloat(cgImage.height)
        )

        let saliencyRect = await detectSalientRegion(image)
        let rectangleRect = detectBottleLikeRectangle(in: image)
        let subjectRect = preferredSubjectRect(saliencyRect: saliencyRect, rectangleRect: rectangleRect)

        guard let subjectRect else {
            return crop(image, to: centeredAspectCrop(
                in: imageBounds,
                around: CGPoint(x: imageBounds.midX, y: imageBounds.midY),
                ratio: ratio
            ))
        }

        let focusRect = pixelRect(fromVisionNormalizedRect: subjectRect, in: imageBounds.size)
        let focusCenter = CGPoint(x: focusRect.midX, y: focusRect.midY)
        let cropRect = centeredAspectCrop(in: imageBounds, around: focusCenter, ratio: ratio)

        return crop(image, to: cropRect)
    }

    // MARK: - Foreground Cutout

    func foregroundCutout(_ image: UIImage) async -> UIImage? {
        let image = normalizeOrientation(image)
        guard let cgImage = image.cgImage else { return nil }

        let request = VNGenerateForegroundInstanceMaskRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

        do {
            try handler.perform([request])
            guard let observation = request.results?.first,
                  !observation.allInstances.isEmpty else {
                return nil
            }

            guard let selectedInstances = preferredForegroundInstances(from: observation) else {
                return nil
            }
            let pixelBuffer = try observation.generateMaskedImage(
                ofInstances: selectedInstances,
                from: handler,
                croppedToInstancesExtent: true
            )

            return makeImage(from: pixelBuffer, scale: image.scale)
        } catch {
            return nil
        }
    }

    func approximateBottleRegionCutout(_ image: UIImage) -> UIImage? {
        let image = normalizeOrientation(image)
        guard let cgImage = image.cgImage,
              let bottleRect = detectBottleLikeRectangle(in: image) else {
            return nil
        }

        let imageBounds = CGRect(
            x: 0,
            y: 0,
            width: CGFloat(cgImage.width),
            height: CGFloat(cgImage.height)
        )
        let pixelBounds = pixelRect(fromVisionNormalizedRect: bottleRect, in: imageBounds.size)
        let padded = pixelBounds
            .insetBy(dx: -pixelBounds.width * 0.12, dy: -pixelBounds.height * 0.16)
            .intersection(imageBounds)
        let cropped = crop(image, to: padded)

        return roundedTransparentImage(cropped, cornerRadiusRatio: 0.08)
    }

    func manualBottleRegionCutout(_ image: UIImage, normalizedRect: CGRect) async -> UIImage? {
        let image = normalizeOrientation(image)
        guard let cgImage = image.cgImage else { return nil }

        let unitBounds = CGRect(x: 0, y: 0, width: 1, height: 1)
        let clippedRect = normalizedRect
            .standardized
            .intersection(unitBounds)

        guard !clippedRect.isNull, !clippedRect.isEmpty else {
            return nil
        }

        let imageBounds = CGRect(
            x: 0,
            y: 0,
            width: CGFloat(cgImage.width),
            height: CGFloat(cgImage.height)
        )
        let pixelRect = CGRect(
            x: clippedRect.minX * imageBounds.width,
            y: clippedRect.minY * imageBounds.height,
            width: clippedRect.width * imageBounds.width,
            height: clippedRect.height * imageBounds.height
        )
        let cropped = crop(image, to: pixelRect)

        if let cutout = await foregroundCutout(cropped) {
            return cutout
        }
        return approximateBottleRegionCutout(cropped)
    }

    private struct ForegroundMaskCandidate {
        let instance: Int
        let rect: CGRect
        let area: CGFloat
    }

    private func preferredForegroundInstances(from observation: VNInstanceMaskObservation) -> IndexSet? {
        let candidates = foregroundMaskCandidates(
            from: observation.instanceMask,
            allowedInstances: observation.allInstances
        )

        guard let best = candidates.max(by: {
            foregroundMaskScore($0) < foregroundMaskScore($1)
        }) else {
            return nil
        }

        let bestRectArea = best.rect.width * best.rect.height
        let bestLooksLikeWholeScene = bestRectArea > 0.82 || best.area > 0.72
        if bestLooksLikeWholeScene && candidates.count == 1 {
            return nil
        }

        var selected = IndexSet(integer: best.instance)
        let unitBounds = CGRect(x: 0, y: 0, width: 1, height: 1)
        let catchment = best.rect
            .insetBy(dx: -best.rect.width * 0.18, dy: -best.rect.height * 0.16)
            .intersection(unitBounds)

        for candidate in candidates where candidate.instance != best.instance {
            let centerAligned = abs(candidate.rect.midX - best.rect.midX) < 0.16
            let verticalGap = max(
                max(best.rect.minY - candidate.rect.maxY, candidate.rect.minY - best.rect.maxY),
                0
            )
            let relatedBottlePart = candidate.rect.intersects(catchment)
                || (centerAligned && verticalGap < 0.12)

            if relatedBottlePart && candidate.area < best.area * 0.75 {
                selected.insert(candidate.instance)
            }
        }

        return selected
    }

    private func foregroundMaskCandidates(
        from pixelBuffer: CVPixelBuffer,
        allowedInstances: IndexSet
    ) -> [ForegroundMaskCandidate] {
        let allowed = Set(allowedInstances)
        guard !allowed.isEmpty else { return [] }

        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }

        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else { return [] }

        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        let pixelFormat = CVPixelBufferGetPixelFormatType(pixelBuffer)

        var bounds: [Int: (minX: Int, minY: Int, maxX: Int, maxY: Int, count: Int)] = [:]

        func record(instance: Int, x: Int, y: Int) {
            guard allowed.contains(instance) else { return }

            if var existing = bounds[instance] {
                existing.minX = min(existing.minX, x)
                existing.minY = min(existing.minY, y)
                existing.maxX = max(existing.maxX, x)
                existing.maxY = max(existing.maxY, y)
                existing.count += 1
                bounds[instance] = existing
            } else {
                bounds[instance] = (x, y, x, y, 1)
            }
        }

        if pixelFormat == kCVPixelFormatType_OneComponent8 {
            let rows = baseAddress.assumingMemoryBound(to: UInt8.self)
            for y in 0..<height {
                let row = rows.advanced(by: y * bytesPerRow)
                for x in 0..<width {
                    let instance = Int(row[x])
                    if instance > 0 {
                        record(instance: instance, x: x, y: y)
                    }
                }
            }
        } else if pixelFormat == kCVPixelFormatType_OneComponent32Float {
            for y in 0..<height {
                let row = baseAddress
                    .advanced(by: y * bytesPerRow)
                    .assumingMemoryBound(to: Float.self)
                for x in 0..<width {
                    let instance = Int(row[x].rounded())
                    if instance > 0 {
                        record(instance: instance, x: x, y: y)
                    }
                }
            }
        } else {
            return allowed.map {
                ForegroundMaskCandidate(
                    instance: $0,
                    rect: CGRect(x: 0, y: 0, width: 1, height: 1),
                    area: 1
                )
            }
        }

        let totalPixels = CGFloat(width * height)
        return bounds.map { instance, value in
            let rect = CGRect(
                x: CGFloat(value.minX) / CGFloat(width),
                y: CGFloat(value.minY) / CGFloat(height),
                width: CGFloat(value.maxX - value.minX + 1) / CGFloat(width),
                height: CGFloat(value.maxY - value.minY + 1) / CGFloat(height)
            )

            return ForegroundMaskCandidate(
                instance: instance,
                rect: rect,
                area: CGFloat(value.count) / totalPixels
            )
        }
    }

    private func foregroundMaskScore(_ candidate: ForegroundMaskCandidate) -> CGFloat {
        let rectArea = candidate.rect.width * candidate.rect.height
        let centerDistance = hypot(candidate.rect.midX - 0.5, candidate.rect.midY - 0.5)
        let centerScore = max(0, 1 - centerDistance * 2.4)
        let verticality = min(candidate.rect.height / max(candidate.rect.width, 0.01), 5) / 5
        let usefulArea = min(candidate.area / 0.32, 1)
        let tooLargePenalty: CGFloat = rectArea > 0.82 ? 0.8 : 0
        let tooTinyPenalty: CGFloat = candidate.area < 0.015 ? 0.5 : 0

        return centerScore * 0.36
            + verticality * 0.34
            + usefulArea * 0.30
            - tooLargePenalty
            - tooTinyPenalty
    }

    private func detectBottleLikeRectangle(in image: UIImage) -> CGRect? {
        let image = normalizeOrientation(image)
        guard let cgImage = image.cgImage else { return nil }

        let request = VNDetectRectanglesRequest()
        request.minimumAspectRatio = 0.18
        request.maximumAspectRatio = 0.95
        request.minimumSize = 0.12
        request.maximumObservations = 12
        request.quadratureTolerance = 30

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
            try handler.perform([request])
        } catch {
            return nil
        }

        let imageBounds = CGRect(x: 0, y: 0, width: 1, height: 1)
        return request.results?
            .map(\.boundingBox)
            .map { $0.standardized.intersection(imageBounds) }
            .filter { !$0.isNull && !$0.isEmpty }
            .max(by: { bottleRectangleScore($0) < bottleRectangleScore($1) })
            .map { rect in
                rect.insetBy(dx: -rect.width * 0.32, dy: -rect.height * 0.42)
                    .intersection(imageBounds)
            }
    }

    private func bottleRectangleScore(_ rect: CGRect) -> CGFloat {
        let area = rect.width * rect.height
        let centerDistance = hypot(rect.midX - 0.5, rect.midY - 0.5)
        let centerScore = max(0, 1 - centerDistance * 2.2)
        let verticality = min(rect.height / max(rect.width, 0.01), 4) / 4
        let usableArea = min(area / 0.35, 1)
        return centerScore * 0.45 + verticality * 0.35 + usableArea * 0.20
    }

    private func preferredSubjectRect(saliencyRect: CGRect?, rectangleRect: CGRect?) -> CGRect? {
        switch (saliencyRect, rectangleRect) {
        case let (saliency?, rectangle?):
            let saliencyArea = saliency.width * saliency.height
            let rectangleArea = rectangle.width * rectangle.height
            let centerDelta = abs(saliency.midX - rectangle.midX)

            if saliency.intersects(rectangle) || centerDelta < 0.18 {
                return saliency.union(rectangle)
                    .intersection(CGRect(x: 0, y: 0, width: 1, height: 1))
            }

            if saliencyArea > 0.70 && rectangleArea > 0.04 {
                return rectangle
            }

            return bottleRectangleScore(rectangle) > 0.55 ? rectangle : saliency

        case let (saliency?, nil):
            return saliency

        case let (nil, rectangle?):
            return rectangle

        case (nil, nil):
            return nil
        }
    }

    private func prominentSaliencyRect(from rawRects: [CGRect]) -> CGRect? {
        let rects = rawRects
            .map { $0.standardized.intersection(CGRect(x: 0, y: 0, width: 1, height: 1)) }
            .filter { !$0.isNull && !$0.isEmpty && $0.width * $0.height > 0.01 }

        guard !rects.isEmpty else { return nil }

        func score(_ rect: CGRect) -> CGFloat {
            let area = rect.width * rect.height
            let centerDistance = hypot(rect.midX - 0.5, rect.midY - 0.5)
            let centerScore = max(0, 1 - centerDistance * 2)
            let portraitScore = min(rect.height / max(rect.width, 0.01), 4) / 4
            let hugePenalty: CGFloat = area > 0.85 ? 0.8 : 0
            return area * 1.4 + centerScore * 0.35 + portraitScore * 0.25 - hugePenalty
        }

        guard let primary = rects.max(by: { score($0) < score($1) }) else { return nil }

        var combined = primary
        let catchment = primary.insetBy(dx: -0.12, dy: -0.18)
            .intersection(CGRect(x: 0, y: 0, width: 1, height: 1))

        for rect in rects where rect != primary {
            let closeHorizontally = abs(rect.midX - primary.midX) < 0.22
            let verticalGap = max(max(primary.minY - rect.maxY, rect.minY - primary.maxY), 0)
            if rect.intersects(catchment) || (closeHorizontally && verticalGap < 0.18) {
                combined = combined.union(rect)
            }
        }

        let padded = combined.insetBy(
            dx: -combined.width * 0.18,
            dy: -combined.height * 0.14
        )
        return padded.intersection(CGRect(x: 0, y: 0, width: 1, height: 1))
    }

    private func pixelRect(fromVisionNormalizedRect rect: CGRect, in imageSize: CGSize) -> CGRect {
        let x = rect.minX * imageSize.width
        let width = rect.width * imageSize.width
        let height = rect.height * imageSize.height
        let y = (1 - rect.maxY) * imageSize.height
        return CGRect(x: x, y: y, width: width, height: height)
    }

    private func centeredAspectCrop(in bounds: CGRect, around center: CGPoint, ratio: CGFloat) -> CGRect {
        let imageRatio = bounds.width / bounds.height
        let cropSize: CGSize

        if imageRatio > ratio {
            cropSize = CGSize(width: bounds.height * ratio, height: bounds.height)
        } else {
            cropSize = CGSize(width: bounds.width, height: bounds.width / ratio)
        }

        let originX = min(max(center.x - cropSize.width / 2, bounds.minX), bounds.maxX - cropSize.width)
        let originY = min(max(center.y - cropSize.height / 2, bounds.minY), bounds.maxY - cropSize.height)
        return CGRect(x: originX, y: originY, width: cropSize.width, height: cropSize.height)
    }

    private func crop(_ image: UIImage, to rect: CGRect) -> UIImage {
        guard let cgImage = image.cgImage,
              let cropped = cgImage.cropping(to: safePixelRect(rect, in: cgImage)) else {
            return centerCropToCardRatio(image)
        }
        return UIImage(cgImage: cropped, scale: image.scale, orientation: .up)
    }

    // MARK: - Render Card-Style Image

    func renderWithCardStyle(_ image: UIImage) -> UIImage? {
        let padding: CGFloat = 24
        let borderWidth: CGFloat = PerfumeLayout.imageBorderWidth
        let totalPadding = padding + borderWidth

        let imageSize = image.size
        let renderWidth = imageSize.width + totalPadding * 2
        let renderHeight = imageSize.height + totalPadding * 2

        let renderer = UIGraphicsImageRenderer(
            size: CGSize(width: renderWidth, height: renderHeight)
        )

        return renderer.image { ctx in
            // Background — warm light gray
            UIColor(red: 0.96, green: 0.95, blue: 0.93, alpha: 1.0).setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: renderWidth, height: renderHeight))

            // White border (thick)
            let borderRect = CGRect(
                x: padding,
                y: padding,
                width: imageSize.width + borderWidth * 2,
                height: imageSize.height + borderWidth * 2
            )
            UIColor.white.setFill()
            let borderPath = UIBezierPath(roundedRect: borderRect, cornerRadius: 8)
            borderPath.fill()

            // Shadow behind image
            ctx.cgContext.setShadow(
                offset: CGSize(width: 0, height: 4),
                blur: 8,
                color: UIColor.black.withAlphaComponent(0.1).cgColor
            )

            // Draw image centered inside border
            let imageRect = CGRect(
                x: padding + borderWidth,
                y: padding + borderWidth,
                width: imageSize.width,
                height: imageSize.height
            )
            image.draw(in: imageRect)
        }
    }

    func renderCutoutCardStyle(_ subjectImage: UIImage) -> UIImage? {
        let canvasSize = CGSize(width: 900, height: 1125)
        let subjectMaxArea = CGRect(origin: .zero, size: canvasSize)
            .insetBy(dx: 110, dy: 96)
        let subjectRect = aspectFitRect(for: subjectImage.size, in: subjectMaxArea)
        let outlineImage = subjectImage.withTintColor(.white, renderingMode: .alwaysTemplate)

        let format = UIGraphicsImageRendererFormat.default()
        format.opaque = false
        format.scale = 1

        let renderer = UIGraphicsImageRenderer(size: canvasSize, format: format)
        return renderer.image { ctx in
            ctx.cgContext.saveGState()
            ctx.cgContext.setShadow(
                offset: CGSize(width: 0, height: 14),
                blur: 20,
                color: UIColor.black.withAlphaComponent(0.18).cgColor
            )
            subjectImage.draw(in: subjectRect)
            ctx.cgContext.restoreGState()

            let outlineRadius: CGFloat = 13
            let outlineOffsets: [CGPoint] = stride(from: 0.0, to: 360.0, by: 15.0).map { degrees in
                let radians = degrees * .pi / 180
                return CGPoint(
                    x: cos(radians) * outlineRadius,
                    y: sin(radians) * outlineRadius
                )
            }

            for offset in outlineOffsets {
                outlineImage.draw(in: subjectRect.offsetBy(dx: offset.x, dy: offset.y))
            }

            subjectImage.draw(in: subjectRect)
        }
    }

    // MARK: - Private Helpers

    private func resize(_ image: UIImage, to size: CGSize) -> UIImage? {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }

    private func makeImage(from pixelBuffer: CVPixelBuffer, scale: CGFloat) -> UIImage? {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext()
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
            return nil
        }
        return UIImage(cgImage: cgImage, scale: scale, orientation: .up)
    }

    private func roundedTransparentImage(_ image: UIImage, cornerRadiusRatio: CGFloat) -> UIImage? {
        let image = normalizeOrientation(image)
        let format = UIGraphicsImageRendererFormat.default()
        format.opaque = false
        format.scale = image.scale

        let renderer = UIGraphicsImageRenderer(size: image.size, format: format)
        return renderer.image { _ in
            let rect = CGRect(origin: .zero, size: image.size)
            let radius = min(image.size.width, image.size.height) * cornerRadiusRatio
            UIBezierPath(roundedRect: rect, cornerRadius: radius).addClip()
            image.draw(in: rect)
        }
    }

    private func aspectFitRect(for size: CGSize, in bounds: CGRect) -> CGRect {
        guard size.width > 0, size.height > 0 else { return bounds }

        let scale = min(bounds.width / size.width, bounds.height / size.height)
        let fittedSize = CGSize(width: size.width * scale, height: size.height * scale)
        return CGRect(
            x: bounds.midX - fittedSize.width / 2,
            y: bounds.midY - fittedSize.height / 2,
            width: fittedSize.width,
            height: fittedSize.height
        )
    }

    private func safePixelRect(_ rect: CGRect, in image: CGImage) -> CGRect {
        let bounds = CGRect(
            x: 0,
            y: 0,
            width: CGFloat(image.width),
            height: CGFloat(image.height)
        )
        let clipped = rect.intersection(bounds)
        guard !clipped.isNull && !clipped.isEmpty else { return bounds }

        let x = max(bounds.minX, floor(clipped.minX))
        let y = max(bounds.minY, floor(clipped.minY))
        let maxX = min(bounds.maxX, ceil(clipped.maxX))
        let maxY = min(bounds.maxY, ceil(clipped.maxY))

        return CGRect(
            x: x,
            y: y,
            width: max(1, maxX - x),
            height: max(1, maxY - y)
        )
    }
}

extension UIImage {
    func fragranceNormalizedUp() -> UIImage {
        guard imageOrientation != .up else { return self }

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = scale
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
    }
}
