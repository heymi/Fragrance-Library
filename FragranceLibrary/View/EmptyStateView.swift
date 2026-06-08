import SwiftUI

/// Empty state shown when no perfumes are in the collection.
struct EmptyStateView: View {
    var onAdd: () -> Void = {}

    @State private var appeared = false
    @State private var iconFloat = false

    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.perfumeCard.opacity(0.78))
                    .frame(height: 270)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(Color.perfumeBorder, lineWidth: 1)
                    )
                    .shadow(color: Color.perfumeShadow, radius: 10, y: 6)

                VStack(spacing: 18) {
                    Image(systemName: "spray.bottle")
                        .font(.system(size: 58, weight: .ultraLight))
                        .foregroundStyle(Color.perfumeAccent.opacity(0.75))
                        .offset(y: iconFloat ? -5 : 5)
                        .animation(
                            .easeInOut(duration: 2.0).repeatForever(autoreverses: true),
                            value: iconFloat
                        )

                    VStack(spacing: 8) {
                        Text("Start your perfume collection")
                            .font(.system(.title3, design: .serif, weight: .semibold))
                            .foregroundStyle(Color.perfumeText)

                        Text("Take or choose a bottle photo. We will isolate the perfume, read the label, and save it as a clean collectible card.")
                            .font(.subheadline)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(Color.perfumeTextSecondary)
                            .padding(.horizontal, 24)
                    }

                    Button(action: onAdd) {
                        Text("Add your first bottle")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 11)
                            .background(Color.perfumeText)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                }
            }
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 14)
        }
        .frame(maxWidth: .infinity)
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
