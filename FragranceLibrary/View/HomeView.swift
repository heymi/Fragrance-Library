import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Perfume.createdAt, order: .reverse) private var perfumes: [Perfume]

    @State private var showAddFlow = false

    var body: some View {
        NavigationStack {
            Group {
                if perfumes.isEmpty {
                    EmptyStateView()
                } else {
                    perfumeGrid
                }
            }
            .navigationTitle("My Perfumes")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        Haptic.light()
                        showAddFlow = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.title3.weight(.semibold))
                    }
                }
            }
            .fullScreenCover(isPresented: $showAddFlow) {
                AddFlowView()
            }
        }
    }

    // MARK: - Perfume Grid

    private var perfumeGrid: some View {
        ScrollView {
            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: PerfumeLayout.gridSpacing),
                    GridItem(.flexible(), spacing: PerfumeLayout.gridSpacing)
                ],
                spacing: PerfumeLayout.gridSpacing
            ) {
                ForEach(Array(perfumes.enumerated()), id: \.element.id) { index, perfume in
                    NavigationLink {
                        DetailView(perfume: perfume)
                    } label: {
                        PerfumeCard(perfume: perfume, index: index)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button(role: .destructive) {
                            deletePerfume(perfume)
                        } label: {
                            Label("Remove", systemImage: "trash")
                        }
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            deletePerfume(perfume)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
            .padding(PerfumeLayout.cardHPadding)
        }
    }

    // MARK: - Delete

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
