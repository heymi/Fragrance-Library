import SwiftUI
import SwiftData

struct InfoConfirmView: View {
    let processedImage: UIImage
    let ocrResult: OCRResult?
    let onSaved: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var brand: String
    @State private var name: String
    @State private var concentration: String
    @State private var volume: String
    @State private var notes: String

    @State private var fieldAppeared: [Bool] = [false, false, false, false, false]
    @State private var isSaving = false
    @State private var saveSuccess = false
    @State private var saveFailed = false
    @State private var shakeOffset: CGFloat = 0
    @FocusState private var focusedField: Field?

    enum Field: Hashable {
        case brand, name, concentration, volume, notes
    }

    init(processedImage: UIImage, ocrResult: OCRResult?, onSaved: @escaping () -> Void) {
        self.processedImage = processedImage
        self.ocrResult = ocrResult
        self.onSaved = onSaved
        _brand = State(initialValue: ocrResult?.brand ?? "")
        _name = State(initialValue: ocrResult?.name ?? "")
        _concentration = State(initialValue: ocrResult?.concentration ?? "")
        _volume = State(initialValue: ocrResult?.volume ?? "")
        _notes = State(initialValue: "")
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Processed Image
                Image(uiImage: processedImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: PerfumeLayout.cardCornerRadius))
                    .overlay(
                        RoundedRectangle(cornerRadius: PerfumeLayout.cardCornerRadius)
                            .strokeBorder(.white, lineWidth: PerfumeLayout.imageBorderWidth)
                    )
                    .shadow(color: Color.perfumeShadow, radius: 12, y: 4)
                    .frame(maxHeight: 300)
                    .padding(.horizontal, 32)
                    .padding(.top, 8)

                // OCR notice if nothing detected
                if ocrResult?.fullText.isEmpty ?? true {
                    HStack(spacing: 8) {
                        Image(systemName: "info.circle.fill")
                            .foregroundStyle(Color.perfumeAccent)
                        Text("No text detected — fill in manually.")
                            .font(.caption)
                            .foregroundStyle(Color.perfumeTextSecondary)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.perfumeAccent.opacity(0.08))
                    )
                }

                // Fields
                VStack(spacing: 16) {
                    fieldRow(
                        label: "Brand",
                        icon: "building.2.fill",
                        text: $brand,
                        field: .brand,
                        index: 0
                    )

                    fieldRow(
                        label: "Name",
                        icon: "spray.bottle.fill",
                        text: $name,
                        field: .name,
                        index: 1
                    )

                    fieldRow(
                        label: "Concentration",
                        icon: "drop.fill",
                        text: $concentration,
                        field: .concentration,
                        index: 2,
                        placeholder: "EDT / EDP / Parfum"
                    )

                    fieldRow(
                        label: "Volume",
                        icon: "cylinder.fill",
                        text: $volume,
                        field: .volume,
                        index: 3,
                        placeholder: "30ml / 50ml / 100ml"
                    )

                    fieldRow(
                        label: "Notes",
                        icon: "pencil.line",
                        text: $notes,
                        field: .notes,
                        index: 4,
                        placeholder: "Personal notes..."
                    )
                }
                .padding(.horizontal, 24)

                // Save Button
                Button {
                    savePerfume()
                } label: {
                    HStack(spacing: 8) {
                        if isSaving {
                            ProgressView()
                                .tint(.white)
                        } else if saveSuccess {
                            Image(systemName: "checkmark")
                                .fontWeight(.bold)
                        }
                        Text(saveSuccess ? "Saved!" : "Save to Collection")
                            .font(.body.weight(.semibold))
                    }
                    .foregroundStyle(saveSuccess ? .white : .white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        saveSuccess
                            ? Color.green
                            : Color.perfumeAccent
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(isSaving || saveSuccess)
                .offset(x: shakeOffset)
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
        }
        .background(Color.perfumeBg)
        .navigationTitle("Perfume Details")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            animateFieldsIn()
        }
        .sensoryFeedback(.success, trigger: saveSuccess) { _, new in new }
        .sensoryFeedback(.error, trigger: saveFailed) { _, new in new }
    }

    // MARK: - Field Row

    private func fieldRow(
        label: String,
        icon: String,
        text: Binding<String>,
        field: Field,
        index: Int,
        placeholder: String = ""
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(
                    focusedField == field
                        ? Color.perfumeAccent
                        : Color.perfumeTextSecondary
                )
                .frame(width: 24)
                .animation(.spring(duration: 0.25), value: focusedField)

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Color.perfumeTextSecondary)

                TextField(
                    text: text,
                    prompt: Text(placeholder.isEmpty
                        ? placeholderFor(label: label)
                        : placeholder
                    ).foregroundStyle(Color.perfumeTextSecondary.opacity(0.5))
                ) {
                    EmptyView()
                }
                .font(.body)
                .foregroundStyle(Color.perfumeText)
                .focused($focusedField, equals: field)
            }

            if text.wrappedValue.isEmpty && !placeholder.isEmpty {
                Spacer()
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.perfumeCard)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(
                    focusedField == field
                        ? Color.perfumeAccent
                        : Color.perfumeBorder,
                    lineWidth: focusedField == field ? 1.5 : 1
                )
        )
        .opacity(fieldAppeared[index] ? 1 : 0)
        .offset(x: fieldAppeared[index] ? 0 : -20)
        .animation(.fadeUp.delay(Double(index) * 0.1), value: fieldAppeared[index])
    }

    private func placeholderFor(label: String) -> String {
        switch label {
        case "Brand": return "e.g. Chanel"
        case "Name": return "e.g. Bleu de Chanel"
        case "Concentration": return "EDT / EDP / Parfum"
        case "Volume": return "50ml / 100ml"
        case "Notes": return "Personal notes..."
        default: return ""
        }
    }

    // MARK: - Animations

    private func animateFieldsIn() {
        for i in 0..<5 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.1) {
                withAnimation {
                    fieldAppeared[i] = true
                }
            }
        }
    }

    // MARK: - Save

    private func savePerfume() {
        isSaving = true
        Haptic.medium()

        // Save images
        let storage = ImageStorageManager.shared
        let processedFilename = storage.saveProcessed(processedImage)

        // Create model
        let perfume = Perfume(
            brand: brand.trimmingCharacters(in: .whitespaces),
            name: name.trimmingCharacters(in: .whitespaces),
            concentration: concentration.trimmingCharacters(in: .whitespaces),
            volume: volume.trimmingCharacters(in: .whitespaces),
            notes: notes.trimmingCharacters(in: .whitespaces),
            processedImageFilename: processedFilename,
            originalImageFilename: nil,
            ocrText: ocrResult?.fullText
        )

        modelContext.insert(perfume)

        do {
            try modelContext.save()
            Haptic.success()
            withAnimation(.checkPop) {
                isSaving = false
                saveSuccess = true
            }
            // Dismiss after brief delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                onSaved()
            }
        } catch {
            Haptic.error()
            isSaving = false
            saveFailed = true
            // Shake animation
            withAnimation(.spring(duration: 0.1, bounce: 0)) {
                shakeOffset = -5
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                withAnimation(.spring(duration: 0.1, bounce: 0)) { shakeOffset = 5 }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.spring(duration: 0.1, bounce: 0)) { shakeOffset = -5 }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation(.spring(duration: 0.1, bounce: 0)) { shakeOffset = 0 }
            }
        }
    }
}

#Preview {
    NavigationStack {
        InfoConfirmView(
            processedImage: UIImage(systemName: "photo")!,
            ocrResult: OCRResult(
                fullText: "CHANEL\nBLEU DE CHANEL\nEAU DE PARFUM\n100 ml",
                brand: "Chanel",
                name: "Bleu de Chanel",
                concentration: "EDP",
                volume: "100ml"
            ),
            onSaved: {}
        )
    }
    .modelContainer(for: Perfume.self, inMemory: true)
}
