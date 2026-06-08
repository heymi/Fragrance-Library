import SwiftUI
import SwiftData

@main
struct FragranceLibraryApp: App {
    let container: ModelContainer

    init() {
        do {
            container = try ModelContainer(for: Perfume.self)
        } catch {
            fatalError("Failed to initialize ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            HomeView()
        }
        .modelContainer(container)
    }
}
