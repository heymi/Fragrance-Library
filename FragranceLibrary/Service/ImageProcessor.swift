import UIKit
import CoreImage
import Vision

/// Processes perfume photos: compress, crop, enhance, render with card-style border.
final class ImageProcessor {

    // MARK: - Downscale

    func downscale(_ image: UIImage, maxWidth: CGFloat) -> UIImage? {
        let scale = image.size.width > maxWidth ? maxWidth / image.size.width : 1.0
        let targetSize = CGSize(
            width: image.size.width * scale,
            height: image.size.height * scale
        )
        return resize(image, to: targetSize)
    }

    // MARK: - Center Crop to Card Ratio

    func centerCropToCardRatio(_ image: UIImage) -> UIImage {
        let ratio = PerfumeLayout.cardAspectRatio
        let imageRatio = image.size.width / image.size.height

        let cropRect: CGRect
        if imageRatio > ratio {
            // Image is wider — crop width
            let newWidth = image.size.height * ratio
            let x = (image.size.width - newWidth) / 2
            cropRect = CGRect(x: x, y: 0, width: newWidth, height: image.size.height)
        } else {
            // Image is taller — crop height
            let newHeight = image.size.width / ratio
            let y = (image.size.height - newHeight) / 2
            cropRect = CGRect(x: 0, y: y, width: image.size.width, height: newHeight)
        }

        guard let cgImage = image.cgImage?.cropping(to: cropRect) else {
            return image
        }
        return UIImage(cgImage: cgImage, scale: image.scale, orientation: image.imageOrientation)
    }

    // MARK: - Enhance Colors

    func enhance(_ image: UIImage) -> UIImage {
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
        return UIImage(cgImage: outputCG, scale: image.scale, orientation: image.imageOrientation)
    }

    // MARK: - Saliency-Based Smart Crop

    /// Detects the most prominent object region using Vision saliency.
    /// Returns a normalized bounding box (0–1), or nil if nothing stands out.
    func detectSalientRegion(_ image: UIImage) async -> CGRect? {
        guard let cgImage = image.cgImage else { return nil }

        let request = VNGenerateObjectnessBasedSaliencyImageRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

        do {
            try handler.perform([request])
        } catch {
            return nil
        }

        guard let result = request.results?.first,
              let objects = result.salientObjects, !objects.isEmpty else {
            return nil
        }

        // Merge all salient object bounding boxes into one
        var unionRect = objects[0].boundingBox
        for obj in objects.dropFirst() {
            unionRect = unionRect.union(obj.boundingBox)
        }
        return unionRect
    }

    /// Crops the image with the salient region centered, falling back to
    /// a gentle center crop if no region is detected.
    func smartCrop(_ image: UIImage) async -> UIImage {
        let ratio = PerfumeLayout.cardAspectRatio

        guard let salientRect = await detectSalientRegion(image) else {
            // Fallback: gentle center crop (keep 90% of the image area)
            return gentleCenterCrop(image, ratio: ratio, preservation: 0.90)
        }

        // Convert normalized Vision rect (origin bottom-left) to image coordinates
        let imageSize = image.size
        let visionRect = VNImageRectForNormalizedRect(salientRect, Int(imageSize.width), Int(imageSize.height))

        // Center of the salient region
        let centerX = visionRect.midX
        let centerY = visionRect.midY

        // Desired crop size at the card ratio
        let cropWidth: CGFloat
        let cropHeight: CGFloat

        let imageRatio = imageSize.width / imageSize.height
        if imageRatio > ratio {
            // Image is wider than card — crop width to match ratio
            cropHeight = imageSize.height
            cropWidth = cropHeight * ratio
        } else {
            // Image is taller — crop height to match ratio
            cropWidth = imageSize.width
            cropHeight = cropWidth / ratio
        }

        // Clamp crop origin so we don't go out of bounds
        let x = min(max(centerX - cropWidth / 2, 0), imageSize.width - cropWidth)
        let y = min(max(centerY - cropHeight / 2, 0), imageSize.height - cropHeight)

        let cropRect = CGRect(x: x, y: y, width: cropWidth, height: cropHeight)

        guard let cgImage = image.cgImage?.cropping(to: cropRect) else {
            return centerCropToCardRatio(image)
        }
        return UIImage(cgImage: cgImage, scale: image.scale, orientation: image.imageOrientation)
    }

    /// A less aggressive center crop that preserves more of the original image.
    private func gentleCenterCrop(_ image: UIImage, ratio: CGFloat, preservation: CGFloat) -> UIImage {
        let imageSize = image.size
        let imageRatio = imageSize.width / imageSize.height

        if abs(imageRatio - ratio) < 0.05 {
            return image // Already close to target ratio
        }

        let scale = preservation
        let cropRect: CGRect
        if imageRatio > ratio {
            let newWidth = imageSize.height * ratio
            let maxX = (imageSize.width - newWidth) / 2 * (2 - scale)
            let x = (imageSize.width - newWidth) / 2 * (2 - scale)
            cropRect = CGRect(x: x, y: 0, width: newWidth + (imageSize.width - newWidth) * (1 - scale), height: imageSize.height)
        } else {
            let newHeight = imageSize.width / ratio
            let maxShift = (imageSize.height - newHeight) / 2
            let y = maxShift * (1 - preservation)
            cropRect = CGRect(x: 0, y: y, width: imageSize.width, height: newHeight + (imageSize.height - newHeight) * preservation)
        }

        guard let cgImage = image.cgImage?.cropping(to: cropRect) else {
            return image
        }
        return UIImage(cgImage: cgImage, scale: image.scale, orientation: image.imageOrientation)
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

    // MARK: - Private Helpers

    private func resize(_ image: UIImage, to size: CGSize) -> UIImage? {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }
}
