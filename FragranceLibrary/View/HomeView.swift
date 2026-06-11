import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Perfume.createdAt, order: .reverse) private var perfumes: [Perfume]

    @State private var showAddFlow = false
    @State private var perfumePendingDeletion: Perfume?
    @State private var detailPerfumeID: UUID?
    @State private var galleryStartID: UUID?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    topBar

                    if perfumes.isEmpty {
                        EmptyStateView(onAdd: showAddPerfumeFlow)
                            .padding(.top, 28)
                    } else {
                        catalogueHeader
                        perfumeGrid
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 8)
                .padding(.bottom, 28)
            }
            .scrollIndicators(.hidden)
            .background(PerfumePaperBackground())
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(
                isPresented: Binding(
                    get: { detailPerfumeID != nil },
                    set: { if !$0 { detailPerfumeID = nil } }
                )
            ) {
                if let detailPerfumeID,
                   let perfume = perfumes.first(where: { $0.id == detailPerfumeID }) {
                    DetailView(perfume: perfume)
                }
            }
            .fullScreenCover(isPresented: Binding(
                get: { galleryStartID != nil },
                set: { if !$0 { galleryStartID = nil } }
            )) {
                if let galleryStartID {
                    PerfumeGalleryView(
                        perfumes: perfumes,
                        startID: galleryStartID
                    )
                }
            }
            .fullScreenCover(isPresented: $showAddFlow) {
                AddFlowView()
            }
            .confirmationDialog(
                "Remove this perfume?",
                isPresented: Binding(
                    get: { perfumePendingDeletion != nil },
                    set: { if !$0 { perfumePendingDeletion = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("Remove from Collection", role: .destructive) {
                    if let perfume = perfumePendingDeletion {
                        deletePerfume(perfume)
                    }
                    perfumePendingDeletion = nil
                }
                Button("Cancel", role: .cancel) {
                    perfumePendingDeletion = nil
                }
            } message: {
                Text("The saved bottle image and original photo will also be deleted from this device.")
            }
        }
    }

    private var topBar: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 3) {
                Text("FRAGRANCE")
                    .font(PerfumeType.label(10))
                    .tracking(2.6)
                    .foregroundStyle(Color.perfumeTextSecondary)

                Text("Library")
                    .font(PerfumeType.title(25))
                    .foregroundStyle(Color.perfumeText)
            }

            Spacer()

            Button(action: showAddPerfumeFlow) {
                Image(systemName: "plus")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(Color.perfumeText)
                    .frame(width: 42, height: 42)
                    .background(Color.perfumeCard.opacity(0.72))
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .strokeBorder(Color.perfumeBorder, lineWidth: 1)
                    )
            }
            .accessibilityLabel("Add perfume")
        }
    }

    private var catalogueHeader: some View {
        HStack {
            Text("\(perfumes.count) bottle\(perfumes.count == 1 ? "" : "s")")
                .font(PerfumeType.bodyMedium(13))
                .foregroundStyle(Color.perfumeTextSecondary)

            Spacer()

            Button(action: showAddPerfumeFlow) {
                Text("Add")
                    .font(PerfumeType.label(12))
                    .tracking(1.2)
                    .foregroundStyle(Color.perfumeAccent)
            }
        }
        .padding(.top, 2)
    }

    private var perfumeGrid: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: 14),
                GridItem(.flexible(), spacing: 14)
            ],
            spacing: 18
        ) {
            ForEach(Array(perfumes.enumerated()), id: \.element.id) { index, perfume in
                PerfumeCard(
                    perfume: perfume,
                    index: index,
                    onOpenDetail: {
                        detailPerfumeID = perfume.id
                    }
                )
                .contextMenu {
                    Button {
                        detailPerfumeID = perfume.id
                    } label: {
                        Label("Details", systemImage: "info.circle")
                    }

                    Button {
                        galleryStartID = perfume.id
                    } label: {
                        Label("View Image", systemImage: "photo")
                    }

                    Button(role: .destructive) {
                        perfumePendingDeletion = perfume
                    } label: {
                        Label("Remove", systemImage: "trash")
                    }
                }
            }
        }
    }

    private func showAddPerfumeFlow() {
        Haptic.light()
        showAddFlow = true
    }

    private func deletePerfume(_ perfume: Perfume) {
        Haptic.heavy()
        ImageStorageManager.shared.deleteAll(
            for: perfume.originalImageFilename,
            processedFilename: perfume.processedImageFilename
        )
        modelContext.delete(perfume)
        try? modelContext.save()
    }
}

#Preview {
    HomeView()
        .modelContainer(for: Perfume.self, inMemory: true)
}
