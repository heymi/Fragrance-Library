import SwiftUI

struct ManualBottleCropView: View {
    let image: UIImage
    let onUseArea: (CGRect) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var selection = CGRect(x: 0.28, y: 0.12, width: 0.44, height: 0.76)
    @State private var dragStartSelection: CGRect?
    @State private var resizeStartSelection: CGRect?

    var body: some View {
        VStack(spacing: 0) {
            header

            GeometryReader { proxy in
                ZStack {
                    Color.black.opacity(0.92)

                    fittedImage(in: proxy.size) { imageRect in
                        Image(uiImage: image.fragranceNormalizedUp())
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: imageRect.width, height: imageRect.height)
                            .position(x: imageRect.midX, y: imageRect.midY)

                        selectionOverlay(in: imageRect)
                    }
                }
            }

            controls
        }
        .background(Color.black)
    }

    private var header: some View {
        HStack {
            Button("Cancel") {
                dismiss()
            }
            .foregroundStyle(.white.opacity(0.8))

            Spacer()

            Text("Select Bottle")
                .font(.headline.weight(.semibold))
                .foregroundStyle(.white)

            Spacer()

            Button("Use") {
                Haptic.medium()
                onUseArea(selection)
            }
            .font(.body.weight(.bold))
            .foregroundStyle(Color.perfumeAccent)
        }
        .padding(.horizontal, 20)
        .padding(.top, 18)
        .padding(.bottom, 14)
        .background(Color.black)
    }

    private var controls: some View {
        VStack(spacing: 12) {
            Text("Frame only the perfume bottle. Exclude hands when possible; the app will re-isolate the bottle inside this area.")
                .font(.footnote.weight(.medium))
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.72))
                .padding(.horizontal, 26)

            HStack(spacing: 12) {
                Button("Tighter") {
                    resizeSelection(by: 0.88)
                }
                .buttonStyle(ManualCropButtonStyle())

                Button("Wider") {
                    resizeSelection(by: 1.12)
                }
                .buttonStyle(ManualCropButtonStyle())

                Button("Reset") {
                    withAnimation(.buttonPress) {
                        selection = CGRect(x: 0.28, y: 0.12, width: 0.44, height: 0.76)
                    }
                }
                .buttonStyle(ManualCropButtonStyle())
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 18)
        .background(Color.black)
    }

    private func fittedImage(
        in size: CGSize,
        @ViewBuilder content: @escaping (CGRect) -> some View
    ) -> some View {
        let imageSize = image.fragranceNormalizedUp().size
        let scale = min(size.width / imageSize.width, size.height / imageSize.height)
        let fittedSize = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        let rect = CGRect(
            x: (size.width - fittedSize.width) / 2,
            y: (size.height - fittedSize.height) / 2,
            width: fittedSize.width,
            height: fittedSize.height
        )

        return content(rect)
    }

    private func selectionOverlay(in imageRect: CGRect) -> some View {
        let rect = displayRect(for: selection, in: imageRect)

        return ZStack {
            Rectangle()
                .fill(.black.opacity(0.46))
                .mask {
                    Rectangle()
                        .overlay(
                            Rectangle()
                                .frame(width: rect.width, height: rect.height)
                                .position(x: rect.midX, y: rect.midY)
                                .blendMode(.destinationOut)
                        )
                }
                .compositingGroup()

            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(.white, lineWidth: 3)
                .frame(width: rect.width, height: rect.height)
                .position(x: rect.midX, y: rect.midY)
                .shadow(color: .black.opacity(0.45), radius: 12)

            resizeHandles(for: rect, imageRect: imageRect)

            VStack {
                Image(systemName: "arrow.up.and.down.and.arrow.left.and.right")
                    .font(.caption.weight(.bold))
                Text("Drag frame or corners")
                    .font(.caption2.weight(.semibold))
            }
            .foregroundStyle(.white)
            .padding(8)
            .background(.black.opacity(0.45))
            .clipShape(Capsule())
            .position(x: rect.midX, y: rect.minY - 22)
        }
        .contentShape(Rectangle())
        .gesture(
            DragGesture()
                .onChanged { value in
                    if dragStartSelection == nil {
                        dragStartSelection = selection
                    }
                    guard let start = dragStartSelection else { return }
                    let dx = value.translation.width / max(imageRect.width, 1)
                    let dy = value.translation.height / max(imageRect.height, 1)
                    selection = clampedSelection(
                        CGRect(
                            x: start.minX + dx,
                            y: start.minY + dy,
                            width: start.width,
                            height: start.height
                        )
                    )
                }
                .onEnded { _ in
                    dragStartSelection = nil
                }
        )
    }

    private func resizeHandles(for rect: CGRect, imageRect: CGRect) -> some View {
        ZStack {
            cornerHandle(.topLeading, rect: rect, imageRect: imageRect)
            cornerHandle(.topTrailing, rect: rect, imageRect: imageRect)
            cornerHandle(.bottomLeading, rect: rect, imageRect: imageRect)
            cornerHandle(.bottomTrailing, rect: rect, imageRect: imageRect)

            edgeHandle(.top, rect: rect, imageRect: imageRect)
            edgeHandle(.bottom, rect: rect, imageRect: imageRect)
            edgeHandle(.leading, rect: rect, imageRect: imageRect)
            edgeHandle(.trailing, rect: rect, imageRect: imageRect)
        }
    }

    private func cornerHandle(_ corner: ResizeHandle, rect: CGRect, imageRect: CGRect) -> some View {
        handleDot
            .position(position(for: corner, in: rect))
            .gesture(resizeGesture(corner, imageRect: imageRect))
    }

    private func edgeHandle(_ edge: ResizeHandle, rect: CGRect, imageRect: CGRect) -> some View {
        Capsule()
            .fill(.white)
            .frame(
                width: edge.isHorizontal ? 34 : 10,
                height: edge.isHorizontal ? 10 : 34
            )
            .overlay(
                Capsule()
                    .strokeBorder(.black.opacity(0.25), lineWidth: 1)
            )
            .position(position(for: edge, in: rect))
            .gesture(resizeGesture(edge, imageRect: imageRect))
    }

    private var handleDot: some View {
        Circle()
            .fill(.white)
            .frame(width: 24, height: 24)
            .overlay(
                Circle()
                    .strokeBorder(.black.opacity(0.22), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.35), radius: 5, y: 2)
            .contentShape(Circle().size(width: 44, height: 44))
    }

    private func position(for handle: ResizeHandle, in rect: CGRect) -> CGPoint {
        switch handle {
        case .topLeading:
            return CGPoint(x: rect.minX, y: rect.minY)
        case .topTrailing:
            return CGPoint(x: rect.maxX, y: rect.minY)
        case .bottomLeading:
            return CGPoint(x: rect.minX, y: rect.maxY)
        case .bottomTrailing:
            return CGPoint(x: rect.maxX, y: rect.maxY)
        case .top:
            return CGPoint(x: rect.midX, y: rect.minY)
        case .bottom:
            return CGPoint(x: rect.midX, y: rect.maxY)
        case .leading:
            return CGPoint(x: rect.minX, y: rect.midY)
        case .trailing:
            return CGPoint(x: rect.maxX, y: rect.midY)
        }
    }

    private func resizeGesture(_ handle: ResizeHandle, imageRect: CGRect) -> some Gesture {
        DragGesture()
            .onChanged { value in
                if resizeStartSelection == nil {
                    resizeStartSelection = selection
                }
                guard let start = resizeStartSelection else { return }
                let dx = value.translation.width / max(imageRect.width, 1)
                let dy = value.translation.height / max(imageRect.height, 1)
                selection = resizedSelection(from: start, handle: handle, dx: dx, dy: dy)
            }
            .onEnded { _ in
                resizeStartSelection = nil
            }
    }

    private func resizedSelection(
        from start: CGRect,
        handle: ResizeHandle,
        dx: CGFloat,
        dy: CGFloat
    ) -> CGRect {
        let minWidth: CGFloat = 0.16
        let minHeight: CGFloat = 0.24
        var minX = start.minX
        var maxX = start.maxX
        var minY = start.minY
        var maxY = start.maxY

        if handle.movesLeading {
            minX = min(max(start.minX + dx, 0), maxX - minWidth)
        }
        if handle.movesTrailing {
            maxX = max(min(start.maxX + dx, 1), minX + minWidth)
        }
        if handle.movesTop {
            minY = min(max(start.minY + dy, 0), maxY - minHeight)
        }
        if handle.movesBottom {
            maxY = max(min(start.maxY + dy, 1), minY + minHeight)
        }

        return CGRect(
            x: minX,
            y: minY,
            width: maxX - minX,
            height: maxY - minY
        )
    }

    private func displayRect(for normalizedRect: CGRect, in imageRect: CGRect) -> CGRect {
        CGRect(
            x: imageRect.minX + normalizedRect.minX * imageRect.width,
            y: imageRect.minY + normalizedRect.minY * imageRect.height,
            width: normalizedRect.width * imageRect.width,
            height: normalizedRect.height * imageRect.height
        )
    }

    private func resizeSelection(by factor: CGFloat) {
        let center = CGPoint(x: selection.midX, y: selection.midY)
        let nextSize = CGSize(
            width: min(max(selection.width * factor, 0.22), 0.86),
            height: min(max(selection.height * factor, 0.32), 0.92)
        )

        withAnimation(.buttonPress) {
            selection = clampedSelection(
                CGRect(
                    x: center.x - nextSize.width / 2,
                    y: center.y - nextSize.height / 2,
                    width: nextSize.width,
                    height: nextSize.height
                )
            )
        }
    }

    private func clampedSelection(_ rect: CGRect) -> CGRect {
        let width = min(max(rect.width, 0.18), 0.92)
        let height = min(max(rect.height, 0.28), 0.96)
        let x = min(max(rect.minX, 0), 1 - width)
        let y = min(max(rect.minY, 0), 1 - height)
        return CGRect(x: x, y: y, width: width, height: height)
    }
}

private struct ManualCropButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(.white.opacity(configuration.isPressed ? 0.22 : 0.14))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private enum ResizeHandle {
    case topLeading
    case topTrailing
    case bottomLeading
    case bottomTrailing
    case top
    case bottom
    case leading
    case trailing

    var movesLeading: Bool {
        self == .topLeading || self == .bottomLeading || self == .leading
    }

    var movesTrailing: Bool {
        self == .topTrailing || self == .bottomTrailing || self == .trailing
    }

    var movesTop: Bool {
        self == .topLeading || self == .topTrailing || self == .top
    }

    var movesBottom: Bool {
        self == .bottomLeading || self == .bottomTrailing || self == .bottom
    }

    var isHorizontal: Bool {
        self == .top || self == .bottom
    }
}

#Preview {
    ManualBottleCropView(image: UIImage(systemName: "photo")!) { _ in }
}
