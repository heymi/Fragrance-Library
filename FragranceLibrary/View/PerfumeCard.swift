import SwiftUI

struct PerfumeCard: View {
    let perfume: Perfume
    let index: Int

    @State private var appeared = false
    @GestureState private var isPressed = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Image area
            imageView
                .aspectRatio(PerfumeLayout.cardAspectRatio, contentMode: .fill)
                .clipped()

            // Info
            VStack(alignment: .leading, spacing: 2) {
                if !perfume.brand.isEmpty {
                    Text(perfume.brand)
                        .font(.caption.weight(.semibold))
                        .fontDesign(.serif)
                        .foregroundStyle(Color.perfumeAccent)
                        .lineLimit(1)
                }

                if !perfume.name.isEmpty {
                    Text(perfume.name)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color.perfumeText)
                        .lineLimit(1)
                }

                if !perfume.subtitle.isEmpty {
                    Text(perfume.subtitle)
                        .font(.caption2)
                        .foregroundStyle(Color.perfumeTextSecondary)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 10)
            .padding(.bottom, 10)
            .padding(.top, 4)
        }
        .background(Color.perfumeCard)
        .clipShape(RoundedRectangle(cornerRadius: PerfumeLayout.cardCornerRadius))
        .shadow(
            color: Color.perfumeShadow,
            radius: isPressed ? 6 : 2,
            y: isPressed ? 4 : 1
        )
        .scaleEffect(isPressed ? 0.96 : 1.0)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 20)
        .animation(.cardStagger(index: index), value: appeared)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .updating($isPressed) { _, state, _ in
                    state = true
                }
        )
        .onAppear {
            appeared = true
        }
    }

    // MARK: - Image View

    @ViewBuilder
    private var imageView: some View {
        if let filename = perfume.processedImageFilename,
           let image = ImageStorageManager.shared.loadImage(filename: filename, type: .processed) {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else {
            // Placeholder
            ZStack {
                Color.perfumeBorder
                Image(systemName: "spray.bottle")
                    .font(.largeTitle)
                    .foregroundStyle(Color.perfumeTextSecondary)
            }
        }
    }
}
