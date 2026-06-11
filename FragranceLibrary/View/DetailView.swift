import SwiftUI
import SwiftData

struct ScrollOffsetPreferenceKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct DetailView: View {
    let perfume: Perfume

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var infoAppeared = false
    @State private var scrollOffset: CGFloat = 0
    @State private var showImagePreview = false
    @State private var showEdit = false
    @State private var showDeleteConfirm = false

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                heroImage
                    .frame(height: 360)
                    .offset(y: max(0, -scrollOffset * 0.3))

                VStack(alignment: .leading, spacing: 22) {
                    titleBlock

                    VStack(spacing: 0) {
                        if !perfume.subtitle.isEmpty {
                            detailRow(
                                icon: "flask.fill",
                                label: "Format",
                                value: perfume.subtitle,
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
                    .padding(.top, 4)

                    // Scene compass radar chart
                    if perfume.hasRadarScores {
                        VStack(spacing: 6) {
                            Divider().background(Color.perfumeBorder)

                            RadarChartView(
                                axes: perfume.radarAxes,
                                color: Color.perfumeAccent,
                                title: "SCENE COMPASS"
                            )
                            .frame(maxWidth: .infinity)

                            if !perfume.strategyLine.isEmpty {
                                Text("「 \(perfume.strategyLine) 」")
                                    .font(PerfumeType.bodyMedium(13))
                                    .foregroundStyle(Color.perfumeAccent)
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .padding(.top, 4)
                            }
                        }
                        .padding(20)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color.perfumeCard)
                        )
                    }

                    actions
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(PerfumePaperBackground())
            }
        }
        .background(PerfumePaperBackground())
        .coordinateSpace(name: "scroll")
        .ignoresSafeArea(edges: .top)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(perfume.brand.isEmpty ? "Perfume" : perfume.brand)
                    .font(.caption.weight(.semibold))
                    .fontDesign(.serif)
                    .foregroundStyle(Color.perfumeText)
            }
            ToolbarItem(placement: .primaryAction) {
                Button("Edit") {
                    showEdit = true
                }
                .font(.subheadline.weight(.semibold))
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
        .fullScreenCover(isPresented: $showImagePreview) {
            if let image = loadedHeroImage {
                ImagePreviewView(image: image)
            }
        }
        .sheet(isPresented: $showEdit) {
            NavigationStack {
                EditPerfumeView(perfume: perfume)
            }
        }
        .confirmationDialog(
            "Remove this perfume?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Remove from Collection", role: .destructive) {
                deletePerfume()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This deletes the saved bottle image, original photo, and local record from this device.")
        }
    }

    private var loadedHeroImage: UIImage? {
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

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            if !perfume.brand.isEmpty {
                Text(perfume.brand)
                    .font(.title3.weight(.semibold))
                    .fontDesign(.serif)
                    .foregroundStyle(Color.perfumeAccent)
            }

            Text(perfume.displayTitle)
                .font(.system(.title, design: .serif, weight: .bold))
                .foregroundStyle(Color.perfumeText)
                .lineLimit(3)
        }
    }

    private var actions: some View {
        VStack(spacing: 12) {
            Button {
                showEdit = true
            } label: {
                Label("Edit Details", systemImage: "square.and.pencil")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.perfumeText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.perfumeCard.opacity(0.82))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(Color.perfumeBorder, lineWidth: 1)
                    )
            }

            Button(role: .destructive) {
                showDeleteConfirm = true
            } label: {
                Label("Remove from Collection", systemImage: "trash")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.perfumeDanger)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(Color.perfumeDanger.opacity(0.3), lineWidth: 1)
                    )
            }
        }
        .padding(.top, 8)
    }

    @ViewBuilder
    private var heroImage: some View {
        if let image = loadedHeroImage {
            ZStack {
                LinearGradient(
                    colors: [Color.perfumeCard, Color.perfumeBg],
                    startPoint: .top,
                    endPoint: .bottom
                )

                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .padding(34)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        showImagePreview = true
                    }

                VStack {
                    Spacer()
                    Text("Tap to inspect image")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.perfumeTextSecondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(Color.perfumeCard.opacity(0.82))
                        .clipShape(Capsule())
                        .padding(.bottom, 12)
                }
            }
        } else {
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

    private func detailRow(
        icon: String,
        label: String,
        value: String,
        index: Int
    ) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(Color.perfumeAccent)
                .frame(width: 22)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 3) {
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

    private func animateInfoIn() {
        withAnimation {
            infoAppeared = true
        }
    }

    private func deletePerfume() {
        Haptic.heavy()
        ImageStorageManager.shared.deleteAll(
            for: perfume.originalImageFilename,
            processedFilename: perfume.processedImageFilename
        )
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
