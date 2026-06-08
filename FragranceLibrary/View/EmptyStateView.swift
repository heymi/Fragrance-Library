import SwiftUI

/// Empty state shown when no perfumes are in the collection.
struct EmptyStateView: View {
    @State private var appeared = false
    @State private var iconFloat = false

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            // Floating icon
            Image(systemName: "spray.bottle")
                .font(.system(size: 56, weight: .ultraLight))
                .foregroundStyle(Color.perfumeTextSecondary.opacity(0.5))
                .offset(y: iconFloat ? -4 : 4)
                .animation(
                    .easeInOut(duration: 2.0).repeatForever(autoreverses: true),
                    value: iconFloat
                )

            VStack(spacing: 8) {
                Text("Start your perfume collection")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Color.perfumeText)

                Text("Take a photo of your first bottle.")
                    .font(.subheadline)
                    .foregroundStyle(Color.perfumeTextSecondary)
            }
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 10)

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .background(Color.perfumeBg)
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) {
                appeared = true
            }
            iconFloat = true
        }
    }
}

#Preview {
    EmptyStateView()
}
