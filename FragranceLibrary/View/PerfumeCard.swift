import SwiftUI

struct PerfumeCard: View {
    let perfume: Perfume
    let index: Int
    var onOpenDetail: () -> Void = {}
    var onOpenImage: () -> Void = {}

    @State private var appeared = false

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Button(action: onOpenImage) {
                imageView
                    .aspectRatio(0.78, contentMode: .fit)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("View large image of \(perfume.displayTitle)")

            Button(action: onOpenDetail) {
                infoBlock
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 12)
        .animation(.cardStagger(index: index, baseDelay: 0.035), value: appeared)
        .onAppear {
            appeared = true
        }
    }

    private var infoBlock: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(perfume.brand.isEmpty ? "Unknown House" : perfume.brand.uppercased())
                .font(PerfumeType.label(9.5))
                .tracking(1.5)
                .foregroundStyle(Color.perfumeTextSecondary)
                .lineLimit(1)

            Text(perfume.name.isEmpty ? perfume.displayTitle : perfume.name)
                .font(PerfumeType.bodyMedium(13))
                .foregroundStyle(Color.perfumeText)
                .lineLimit(1)

            if !perfume.subtitle.isEmpty {
                Text(perfume.subtitle)
                    .font(PerfumeType.body(11))
                    .foregroundStyle(Color.perfumeTextSecondary.opacity(0.86))
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 2)
    }

    @ViewBuilder
    private var imageView: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.perfumeIvory.opacity(0.84))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(Color.perfumeBorder.opacity(0.72), lineWidth: 0.8)
                )

            if let image = loadedImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .padding(12)
            } else {
                Image(systemName: "spray.bottle")
                    .font(.system(size: 34, weight: .ultraLight))
                    .foregroundStyle(Color.perfumeTextSecondary.opacity(0.48))
            }
        }
    }

    private var loadedImage: UIImage? {
        if let image = ImageStorageManager.shared.loadImage(
            filename: perfume.processedImageFilename,
            type: .processed
        ) {
            return image
        }
        return ImageStorageManager.shared.loadImage(
            filename: perfume.originalImageFilename,
            type: .original
        )
    }
}
