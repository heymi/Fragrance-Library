import SwiftUI

struct ImagePreviewView: View {
    let image: UIImage

    @Environment(\.dismiss) private var dismiss
    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var appeared = false
    @State private var verticalDrag: CGFloat = 0

    var body: some View {
        ZStack(alignment: .topTrailing) {
            PreviewIvoryBackground()
                .ignoresSafeArea()

            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .scaleEffect(scale)
                .gesture(
                    MagnifyGesture()
                        .onChanged { value in
                            scale = max(1, min(lastScale * value.magnification, 5))
                        }
                        .onEnded { _ in
                            lastScale = scale
                        }
                )
                .onTapGesture(count: 2) {
                    withAnimation(.galleryBloom) {
                        if scale > 1 {
                            scale = 1
                            lastScale = 1
                        } else {
                            scale = 2.2
                            lastScale = 2.2
                        }
                    }
                }
                .padding(24)

            Button {
                close()
            } label: {
                Image(systemName: "xmark")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.perfumeText)
                    .frame(width: 38, height: 38)
                    .background(Color.perfumeCard.opacity(0.86))
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .strokeBorder(Color.perfumeBorder, lineWidth: 1)
                    )
            }
            .padding(20)
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: max(verticalDrag, 0))
        .scaleEffect(appeared ? max(0.94, 1 - max(verticalDrag, 0) / 1400) : 0.96)
        .simultaneousGesture(
            DragGesture(minimumDistance: 18)
                .onChanged { value in
                    let vertical = value.translation.height
                    let horizontal = abs(value.translation.width)
                    if vertical > 0 && abs(vertical) > horizontal * 1.25 {
                        verticalDrag = vertical
                    }
                }
                .onEnded { value in
                    let vertical = value.translation.height
                    let horizontal = abs(value.translation.width)
                    if vertical > 130 && abs(vertical) > horizontal * 1.25 {
                        close()
                    } else {
                        withAnimation(.galleryBloom) {
                            verticalDrag = 0
                        }
                    }
                }
        )
        .onAppear {
            withAnimation(.galleryBloom) {
                appeared = true
            }
        }
    }

    private func close() {
        withAnimation(.easeInOut(duration: 0.18)) {
            appeared = false
            verticalDrag = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            dismiss()
        }
    }
}

struct PreviewIvoryBackground: View {
    var body: some View {
        ZStack {
            Color.perfumeIvory

            LinearGradient(
                colors: [
                    Color.white.opacity(0.76),
                    Color.perfumeBg.opacity(0.62)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(Color.perfumeBlush.opacity(0.18))
                .frame(width: 280, height: 280)
                .blur(radius: 76)
                .offset(x: -130, y: -230)
        }
    }
}
