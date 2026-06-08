import SwiftUI
import SwiftData

// MARK: - Scroll Offset Preference Key

struct ScrollOffsetPreferenceKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - DetailView

struct DetailView: View {
    let perfume: Perfume

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var infoAppeared = false
    @State private var scrollOffset: CGFloat = 0

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Hero image with parallax
                heroImage
                    .frame(height: 340)
                    .offset(y: max(0, -scrollOffset * 0.3))

                // Info section
                VStack(alignment: .leading, spacing: 20) {
                    // Title
                    VStack(alignment: .leading, spacing: 4) {
                        if !perfume.brand.isEmpty {
                            Text(perfume.brand)
                                .font(.title3.weight(.semibold))
                                .fontDesign(.serif)
                                .foregroundStyle(Color.perfumeAccent)
                        }

                        Text(perfume.displayTitle)
                            .font(.title.weight(.bold))
                            .foregroundStyle(Color.perfumeText)
                    }

                    // Details
                    VStack(spacing: 0) {
                        let subtitle = perfume.subtitle
                        if !subtitle.isEmpty {
                            detailRow(
                                icon: "flask.fill",
                                label: "Format",
                                value: subtitle,
                                index: 0
                            )
                        }

                        if !perfume.notes.isEmpty {
                            detailRow(
                                icon: "pencil.line",
                                label: "Notes",
                                value: perfume.notes,
                                index: 1
                            )
                        }

                        detailRow(
                            icon: "calendar",
                            label: "Added",
                            value: perfume.formattedDate,
                            index: 2
                        )
                    }
                    .padding(.top, 8)

                    // Delete button
                    Button(role: .destructive) {
                        deletePerfume()
                    } label: {
                        HStack {
                            Image(systemName: "trash")
                            Text("Remove from Collection")
                        }
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color.perfumeDanger)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(Color.perfumeDanger.opacity(0.3), lineWidth: 1)
                        )
                    }
                    .padding(.top, 8)
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.perfumeBg)
            }
        }
        .background(Color.perfumeBg)
        .coordinateSpace(name: "scroll")
        .ignoresSafeArea(edges: .top)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(perfume.brand)
                    .font(.caption.weight(.semibold))
                    .fontDesign(.serif)
                    .foregroundStyle(Color.perfumeText)
            }
        }
        .onAppear {
            animateInfoIn()
        }
        .background(GeometryReader { geometry in
            Color.clear
                .preference(
                    key: ScrollOffsetPreferenceKey.self,
                    value: geometry.frame(in: .named("scroll")).origin.y
                )
        })
        .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
            scrollOffset = -value
        }
    }

    // MARK: - Hero Image

    @ViewBuilder
    private var heroImage: some View {
        if let filename = perfume.processedImageFilename,
           let image = ImageStorageManager.shared.loadImage(filename: filename, type: .processed) {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .padding(32)
                .background(
                    LinearGradient(
                        colors: [Color.perfumeCard, Color.perfumeBg],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        } else {
            // Fallback placeholder
            ZStack {
                LinearGradient(
                    colors: [Color.perfumeCard, Color.perfumeBg],
                    startPoint: .top,
                    endPoint: .bottom
                )
                Image(systemName: "spray.bottle")
                    .font(.system(size: 60))
                    .foregroundStyle(Color.perfumeTextSecondary.opacity(0.4))
            }
        }
    }

    // MARK: - Detail Row

    private func detailRow(
        icon: String,
        label: String,
        value: String,
        index: Int
    ) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(Color.perfumeAccent)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(Color.perfumeTextSecondary)
                Text(value)
                    .font(.body)
                    .foregroundStyle(Color.perfumeText)
            }
            Spacer()
        }
        .padding(.vertical, 12)
        .overlay(
            Divider()
                .background(Color.perfumeBorder),
            alignment: .bottom
        )
        .opacity(infoAppeared ? 1 : 0)
        .offset(y: infoAppeared ? 0 : 10)
        .animation(.fadeUp.delay(Double(index) * 0.1), value: infoAppeared)
    }

    // MARK: - Actions

    private func animateInfoIn() {
        withAnimation {
            infoAppeared = true
        }
    }

    private func deletePerfume() {
        Haptic.heavy()
        // Delete images
        ImageStorageManager.shared.deleteAll(
            for: perfume.originalImageFilename,
            processedFilename: perfume.processedImageFilename
        )
        // Delete model
        modelContext.delete(perfume)
        try? modelContext.save()
        dismiss()
    }
}

#Preview {
    NavigationStack {
        DetailView(perfume: Perfume(
            brand: "Chanel",
            name: "Bleu de Chanel",
            concentration: "EDP",
            volume: "100ml",
            notes: "My signature scent."
        ))
    }
    .modelContainer(for: Perfume.self, inMemory: true)
}
