import SwiftUI

struct PerfumeGalleryView: View {
    let perfumes: [Perfume]
    let startID: UUID

    @Environment(\.dismiss) private var dismiss
    @State private var selectedID: UUID
    @State private var appeared = false
    @State private var verticalDrag: CGFloat = 0

    private var selectedIndex: Int {
        perfumes.firstIndex(where: { $0.id == selectedID }) ?? 0
    }

    init(perfumes: [Perfume], startID: UUID) {
        self.perfumes = perfumes
        self.startID = startID
        _selectedID = State(initialValue: startID)
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            PreviewIvoryBackground()
                .ignoresSafeArea()

            TabView(selection: $selectedID) {
                ForEach(perfumes, id: \.id) { perfume in
                    GalleryPage(perfume: perfume)
                        .tag(perfume.id)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .automatic))
            .ignoresSafeArea()

            HStack {
                Text("\(selectedIndex + 1) / \(max(perfumes.count, 1))")
                    .font(PerfumeType.label(10))
                    .tracking(1.6)
                    .foregroundStyle(Color.perfumeTextSecondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.perfumeCard.opacity(0.76))
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .strokeBorder(Color.perfumeBorder.opacity(0.8), lineWidth: 1)
                    )

                Spacer()
            }
            .padding(20)

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

private struct GalleryPage: View {
    let perfume: Perfume

    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 20) {
            Spacer(minLength: 44)

            if let image = loadedImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .scaleEffect(scale)
                    .shadow(color: Color.black.opacity(0.08), radius: 22, y: 12)
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
                    .padding(.horizontal, 26)
                    .scaleEffect(appeared ? 1 : 0.94)
                    .opacity(appeared ? 1 : 0)
                    .animation(.galleryBloom.delay(0.06), value: appeared)
            } else {
                Image(systemName: "spray.bottle")
                    .font(.system(size: 64, weight: .ultraLight))
                    .foregroundStyle(Color.perfumeTextSecondary.opacity(0.5))
            }

            VStack(spacing: 5) {
                Text(perfume.brand.isEmpty ? "Unknown House" : perfume.brand.uppercased())
                    .font(PerfumeType.label(10))
                    .tracking(1.8)
                    .foregroundStyle(Color.perfumeTextSecondary)

                Text(perfume.name.isEmpty ? perfume.displayTitle : perfume.name)
                    .font(PerfumeType.bodyMedium(15))
                    .foregroundStyle(Color.perfumeText)
                    .lineLimit(2)

                if !perfume.subtitle.isEmpty {
                    Text(perfume.subtitle)
                        .font(PerfumeType.body(12))
                        .foregroundStyle(Color.perfumeTextSecondary)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 42)
            .offset(y: appeared ? 0 : 16)
            .opacity(appeared ? 1 : 0)
            .animation(.editorialReveal.delay(0.16), value: appeared)
        }
        .onAppear {
            appeared = true
        }
        .onChange(of: perfume.id) { _, _ in
            appeared = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.03) {
                appeared = true
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

#Preview {
    PerfumeGalleryView(
        perfumes: [
            Perfume(brand: "Loewe", name: "Aire"),
            Perfume(brand: "Armani Privé", name: "Thé Yulong")
        ],
        startID: UUID()
    )
}
