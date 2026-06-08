import SwiftUI
import UIKit

private enum CutoutEraseTool: String, Hashable {
    case erase
    case restore

    var title: String {
        switch self {
        case .erase:
            return "Erase"
        case .restore:
            return "Restore"
        }
    }
}

struct ManualCutoutEraseView: View {
    let onApply: (UIImage) -> Void

    @Environment(\.dismiss) private var dismiss

    private let sourceImage: UIImage

    @State private var workingImage: UIImage
    @State private var tool: CutoutEraseTool = .erase
    @State private var brushSize: CGFloat = 0.045
    @State private var activeStroke: [CGPoint] = []
    @State private var undoStack: [UIImage] = []

    init(image: UIImage, onApply: @escaping (UIImage) -> Void) {
        let normalized = image.fragranceNormalizedUp()
        self.sourceImage = normalized
        self.onApply = onApply
        _workingImage = State(initialValue: normalized)
    }

    var body: some View {
        VStack(spacing: 0) {
            CutoutEraseHeader(
                canUndo: !undoStack.isEmpty,
                onCancel: { dismiss() },
                onUndo: undo,
                onApply: { onApply(workingImage) }
            )

            CutoutEraseCanvas(
                image: workingImage,
                tool: tool,
                brushSize: brushSize,
                activeStroke: $activeStroke,
                onCommitStroke: commitStroke
            )

            CutoutEraseControls(
                tool: $tool,
                brushSize: $brushSize
            )
        }
        .background(Color.perfumeIvory)
    }

    private func commitStroke(_ points: [CGPoint]) {
        guard !points.isEmpty else { return }
        undoStack.append(workingImage)
        workingImage = workingImage.applyingCutoutStroke(
            points,
            brushSize: brushSize,
            tool: tool,
            sourceImage: sourceImage
        )
        activeStroke = []
    }

    private func undo() {
        guard let previous = undoStack.popLast() else { return }
        withAnimation(.buttonPress) {
            workingImage = previous
        }
    }
}

private struct CutoutEraseHeader: View {
    let canUndo: Bool
    let onCancel: () -> Void
    let onUndo: () -> Void
    let onApply: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            Button("Cancel", action: onCancel)
                .foregroundStyle(Color.perfumeTextSecondary)

            Spacer()

            VStack(spacing: 2) {
                Text("Clean Cutout")
                    .font(PerfumeType.display(size: 18, weight: .semibold))
                    .foregroundStyle(Color.perfumeText)

                Text("Erase hands or restore bottle edges")
                    .font(PerfumeType.label(10))
                    .tracking(1.2)
                    .foregroundStyle(Color.perfumeTextSecondary)
            }

            Spacer()

            Button(action: onUndo) {
                Image(systemName: "arrow.uturn.backward")
            }
            .disabled(!canUndo)
            .foregroundStyle(canUndo ? Color.perfumeText : Color.perfumeTextSecondary.opacity(0.35))

            Button("Use", action: onApply)
                .font(.body.weight(.bold))
                .foregroundStyle(Color.perfumeAccent)
        }
        .padding(.horizontal, 18)
        .padding(.top, 18)
        .padding(.bottom, 14)
        .background(Color.perfumeIvory.opacity(0.96))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.perfumeBorder)
                .frame(height: 1)
        }
    }
}

private struct CutoutEraseCanvas: View {
    let image: UIImage
    let tool: CutoutEraseTool
    let brushSize: CGFloat
    @Binding var activeStroke: [CGPoint]
    let onCommitStroke: ([CGPoint]) -> Void

    var body: some View {
        GeometryReader { proxy in
            let imageRect = fittedImageRect(in: proxy.size)

            ZStack {
                Color.perfumeIvory

                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: imageRect.width, height: imageRect.height)
                    .position(x: imageRect.midX, y: imageRect.midY)
                    .shadow(color: Color.perfumeShadow.opacity(0.22), radius: 18, y: 10)

                if !activeStroke.isEmpty {
                    activeStrokePath(in: imageRect)
                        .stroke(
                            tool == .erase ? Color.perfumeDanger.opacity(0.72) : Color.perfumeAccent.opacity(0.72),
                            style: StrokeStyle(
                                lineWidth: max(12, brushSize * min(imageRect.width, imageRect.height)),
                                lineCap: .round,
                                lineJoin: .round
                            )
                        )
                        .shadow(color: .white.opacity(0.85), radius: 1)
                }

                VStack {
                    Text(tool == .erase ? "Paint over anything to remove" : "Paint to restore from the original cutout")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Color.perfumeTextSecondary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color.white.opacity(0.72))
                        .clipShape(Capsule())

                    Spacer()
                }
                .padding(.top, 18)
            }
            .coordinateSpace(name: "erase-editor")
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .named("erase-editor"))
                    .onChanged { value in
                        activeStroke.append(normalizedPoint(for: value.location, in: imageRect))
                    }
                    .onEnded { _ in
                        onCommitStroke(activeStroke)
                    }
            )
        }
    }

    private func fittedImageRect(in size: CGSize) -> CGRect {
        let imageSize = image.size
        let scale = min(size.width / max(imageSize.width, 1), size.height / max(imageSize.height, 1))
        let fittedSize = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)

        return CGRect(
            x: (size.width - fittedSize.width) / 2,
            y: (size.height - fittedSize.height) / 2,
            width: fittedSize.width,
            height: fittedSize.height
        )
    }

    private func normalizedPoint(for location: CGPoint, in imageRect: CGRect) -> CGPoint {
        CGPoint(
            x: ((location.x - imageRect.minX) / max(imageRect.width, 1)).clamped(to: 0...1),
            y: ((location.y - imageRect.minY) / max(imageRect.height, 1)).clamped(to: 0...1)
        )
    }

    private func activeStrokePath(in imageRect: CGRect) -> Path {
        Path { path in
            guard let first = activeStroke.first else { return }
            path.move(to: displayPoint(first, in: imageRect))

            for point in activeStroke.dropFirst() {
                path.addLine(to: displayPoint(point, in: imageRect))
            }
        }
    }

    private func displayPoint(_ point: CGPoint, in imageRect: CGRect) -> CGPoint {
        CGPoint(
            x: imageRect.minX + point.x * imageRect.width,
            y: imageRect.minY + point.y * imageRect.height
        )
    }
}

private struct CutoutEraseControls: View {
    @Binding var tool: CutoutEraseTool
    @Binding var brushSize: CGFloat

    var body: some View {
        VStack(spacing: 16) {
            Picker("Tool", selection: $tool) {
                Text(CutoutEraseTool.erase.title).tag(CutoutEraseTool.erase)
                Text(CutoutEraseTool.restore.title).tag(CutoutEraseTool.restore)
            }
            .pickerStyle(.segmented)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Brush")
                        .font(PerfumeType.label(11))
                        .tracking(1.8)
                        .foregroundStyle(Color.perfumeTextSecondary)

                    Spacer()

                    Circle()
                        .fill(tool == .erase ? Color.perfumeDanger.opacity(0.75) : Color.perfumeAccent.opacity(0.75))
                        .frame(width: max(12, brushSize * 240), height: max(12, brushSize * 240))
                }

                Slider(value: $brushSize, in: 0.018...0.12)
                    .tint(Color.perfumeAccent)
            }

            Text("Tip: use Erase for fingers and background scraps. Switch to Restore if you remove part of the bottle by mistake.")
                .font(.footnote)
                .foregroundStyle(Color.perfumeTextSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 18)
        .padding(.top, 18)
        .padding(.bottom, 22)
        .background(Color.perfumeCard)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.perfumeBorder)
                .frame(height: 1)
        }
    }
}

private extension UIImage {
    func applyingCutoutStroke(
        _ normalizedPoints: [CGPoint],
        brushSize: CGFloat,
        tool: CutoutEraseTool,
        sourceImage: UIImage
    ) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        format.opaque = false

        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { context in
            let bounds = CGRect(origin: .zero, size: size)
            draw(in: bounds)

            let path = CGMutablePath()
            let firstPoint = imagePoint(normalizedPoints[0])
            path.move(to: firstPoint)

            if normalizedPoints.count == 1 {
                path.addLine(to: CGPoint(x: firstPoint.x + 0.1, y: firstPoint.y + 0.1))
            } else {
                for point in normalizedPoints.dropFirst() {
                    path.addLine(to: imagePoint(point))
                }
            }

            let lineWidth = max(6, brushSize * min(size.width, size.height))
            context.cgContext.setLineCap(.round)
            context.cgContext.setLineJoin(.round)
            context.cgContext.setLineWidth(lineWidth)

            switch tool {
            case .erase:
                context.cgContext.setBlendMode(.clear)
                context.cgContext.setStrokeColor(UIColor.black.cgColor)
                context.cgContext.addPath(path)
                context.cgContext.strokePath()
            case .restore:
                let strokedPath = path.copy(
                    strokingWithWidth: lineWidth,
                    lineCap: .round,
                    lineJoin: .round,
                    miterLimit: 10
                )
                context.cgContext.saveGState()
                context.cgContext.addPath(strokedPath)
                context.cgContext.clip()
                sourceImage.draw(in: bounds)
                context.cgContext.restoreGState()
            }
        }
    }

    private func imagePoint(_ normalizedPoint: CGPoint) -> CGPoint {
        CGPoint(
            x: normalizedPoint.x * size.width,
            y: normalizedPoint.y * size.height
        )
    }
}

private extension Comparable {
    func clamped(to limits: ClosedRange<Self>) -> Self {
        min(max(self, limits.lowerBound), limits.upperBound)
    }
}
