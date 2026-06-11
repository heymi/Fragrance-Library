import SwiftUI
import SwiftData

struct InfoConfirmView: View {
    let originalImage: UIImage?
    let ocrResult: OCRResult?
    let onSaved: () -> Void

    @Environment(\.modelContext) private var modelContext

    @State private var brand: String
    @State private var name: String
    @State private var concentration: String
    @State private var volume: String
    @State private var notes: String
    @State private var currentProcessedImage: UIImage
    @State private var rawCutoutImage: UIImage?
    @State private var imageQuality: CutoutQualityReport
    @State private var fieldAppeared: [Bool] = [false, false, false, false, false]
    @State private var isSaving = false
    @State private var isRefining = false
    @State private var saveSuccess = false
    @State private var saveFailed = false
    @State private var shakeOffset: CGFloat = 0
    @State private var showImagePreview = false
    @State private var showManualCrop = false
    @State private var showManualErase = false
    @State private var showOCRText = false
    @State private var validationMessage: String?

    @FocusState private var focusedField: Field?

    enum Field: Hashable {
        case brand, name, concentration, volume, notes
    }

    private var trimmedBrand: String {
        brand.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSave: Bool {
        !isSaving && !saveSuccess && (!trimmedBrand.isEmpty || !trimmedName.isEmpty)
    }

    /// The image to display: always the card-styled version with alpha-aware outline.
    private var displayImage: Image {
        Image(uiImage: currentProcessedImage)
    }

    /// Image passed to the erase tool — always the raw cutout when available
    private var eraseSourceImage: UIImage {
        rawCutoutImage ?? currentProcessedImage
    }

    private let aiAnalysis: RadarAnalysis?

    init(
        originalImage: UIImage? = nil,
        processedResult: ProcessedPerfumeImage,
        ocrResult: OCRResult?,
        aiAnalysis: RadarAnalysis? = nil,
        onSaved: @escaping () -> Void
    ) {
        self.originalImage = originalImage
        self.aiAnalysis = aiAnalysis
        self.ocrResult = ocrResult
        self.onSaved = onSaved
        _rawCutoutImage = State(initialValue: processedResult.rawCutoutImage)
        _imageQuality = State(initialValue: processedResult.quality)
        // Pre-fill from AI if available, otherwise from OCR
        let cleanedName = aiAnalysis?.cleaned ?? ""
        _brand = State(initialValue: cleanedName.isEmpty ? (ocrResult?.brand ?? "") : cleanedName)
        _name = State(initialValue: cleanedName.isEmpty ? (ocrResult?.name ?? "") : "")
        _concentration = State(initialValue: ocrResult?.concentration ?? "")
        _volume = State(initialValue: ocrResult?.volume ?? "")
        _notes = State(initialValue: aiAnalysis?.review ?? "")
        _currentProcessedImage = State(initialValue: processedResult.displayImage)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                displayImage
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .shadow(color: Color.perfumeShadow, radius: 12, y: 4)
                    .frame(maxHeight: 300)
                    .padding(.horizontal, 32)
                    .padding(.top, 8)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        showImagePreview = true
                    }
                    .overlay {
                        if isRefining {
                            ZStack {
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(Color.perfumeIvory.opacity(0.72))

                                VStack(spacing: 8) {
                                    ProgressView()
                                        .tint(Color.perfumeAccent)
                                    Text("Refining cutout")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(Color.perfumeTextSecondary)
                                }
                            }
                        }
                    }

                imageQualitySummary

                detectionSummary

                if let analysis = aiAnalysis {
                    VStack(spacing: 12) {
                        HStack(spacing: 6) {
                            Text("✨")
                            Text("AI scored this perfume")
                                .font(.caption.weight(.semibold))
                        }
                        .foregroundStyle(Color.perfumeAccent)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Color.perfumeAccent.opacity(0.1))
                        )

                        // Compact radar preview
                        RadarChartView(
                            axes: [
                                RadarChartAxis(label: "👴", value: analysis.elder),
                                RadarChartAxis(label: "💕", value: analysis.date),
                                RadarChartAxis(label: "👯", value: analysis.girlApproved),
                                RadarChartAxis(label: "💼", value: analysis.office),
                                RadarChartAxis(label: "🧘", value: analysis.selfComfort),
                                RadarChartAxis(label: "✨", value: analysis.impression),
                            ],
                            color: Color.perfumeAccent
                        )
                        .frame(width: 200, height: 200)
                    }
                }

                // Image refinement tools
                VStack(spacing: 6) {
                    Divider().background(Color.perfumeBorder)
                    Text("IMAGE TOOLS")
                        .font(PerfumeType.label(10))
                        .tracking(2.0)
                        .foregroundStyle(Color.perfumeTextSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    HStack(spacing: 12) {
                        if originalImage != nil {
                            Button {
                                showManualCrop = true
                            } label: {
                                Label("Refine", systemImage: "crop")
                            }
                            .buttonStyle(PremiumSecondaryButtonStyle())
                            .disabled(isRefining || isSaving || saveSuccess)
                        }

                        Button {
                            showManualErase = true
                        } label: {
                            Label("Clean Edges", systemImage: "eraser")
                        }
                        .buttonStyle(PremiumSecondaryButtonStyle())
                        .disabled(isRefining || isSaving || saveSuccess)
                    }
                }
                .padding(.horizontal, 24)

                VStack(spacing: 14) {
                    fieldRow(
                        label: "Brand",
                        icon: "building.2.fill",
                        text: $brand,
                        field: .brand,
                        index: 0
                    )

                    fieldRow(
                        label: "Name",
                        icon: "tag.fill",
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

                if let validationMessage {
                    Label(validationMessage, systemImage: "exclamationmark.circle.fill")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(Color.perfumeDanger)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }

                if imageQuality.confidence == .low {
                    Label("This image may not be a complete bottle cutout. Refine the bottle area before saving when possible.", systemImage: "exclamationmark.triangle.fill")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(Color.perfumeDanger)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }

                saveButton
                    .offset(x: shakeOffset)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
            }
        }
        .background(PerfumePaperBackground())
        .navigationTitle("Confirm")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    focusedField = nil
                }
            }
        }
        .onAppear {
            animateFieldsIn()
        }
        .sensoryFeedback(.success, trigger: saveSuccess) { _, new in new }
        .sensoryFeedback(.error, trigger: saveFailed) { _, new in new }
        .fullScreenCover(isPresented: $showImagePreview) {
            ImagePreviewView(image: currentProcessedImage)
        }
        .fullScreenCover(isPresented: $showManualCrop) {
            if let originalImage {
                ManualBottleCropView(image: originalImage) { normalizedRect in
                    showManualCrop = false
                    refineCutout(normalizedRect)
                }
            }
        }
        .fullScreenCover(isPresented: $showManualErase) {
            ManualCutoutEraseView(image: eraseSourceImage) { editedImage in
                if let result = PerfumeImageProcessingPipeline()
                    .restyleEditedCutout(editedImage) {
                    rawCutoutImage = result.rawCutoutImage
                    currentProcessedImage = result.displayImage
                    imageQuality = result.quality
                } else {
                    rawCutoutImage = editedImage
                    currentProcessedImage = editedImage
                    imageQuality = CutoutQualityReport(
                        confidence: .low,
                        score: 35,
                        reasons: ["Manual cleanup could not be restyled."],
                        suggestedAction: .review
                    )
                }
                validationMessage = nil
                showManualErase = false
            }
        }
    }

    private var imageQualitySummary: some View {
        VStack(spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: imageQuality.confidence == .high ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                Text(imageQuality.confidence.title)
                    .font(.caption.weight(.semibold))
                Text("\(imageQuality.score)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.perfumeTextSecondary)
            }
            .foregroundStyle(imageQuality.confidence == .high ? Color.perfumeAccent : Color.perfumeDanger)

            if let reason = imageQuality.reasons.first {
                Text(reason)
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color.perfumeTextSecondary)
                    .padding(.horizontal, 28)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill((imageQuality.confidence == .high ? Color.perfumeAccent : Color.perfumeDanger).opacity(0.08))
        )
        .padding(.horizontal, 24)
    }

    @ViewBuilder
    private var detectionSummary: some View {
        if ocrResult?.fullText.isEmpty ?? true {
            Label("No label text detected. Fill in Brand or Name manually.", systemImage: "info.circle.fill")
                .font(.caption.weight(.medium))
                .foregroundStyle(Color.perfumeTextSecondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.perfumeAccent.opacity(0.08))
                .clipShape(Capsule())
        } else {
            DisclosureGroup(isExpanded: $showOCRText) {
                Text(ocrResult?.fullText ?? "")
                    .font(.caption)
                    .foregroundStyle(Color.perfumeTextSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 8)
            } label: {
                Label("OCR found label text", systemImage: "text.viewfinder")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.perfumeAccent)
            }
            .padding(14)
            .background(Color.perfumeCard.opacity(0.82))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Color.perfumeBorder, lineWidth: 1)
            )
            .padding(.horizontal, 24)
        }
    }

    private var saveButton: some View {
        Button(action: savePerfume) {
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
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(saveSuccess ? Color.green : (canSave ? Color.perfumeAccent : Color.perfumeTextSecondary.opacity(0.45)))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .disabled(isSaving || saveSuccess)
    }

    private func fieldRow(
        label: String,
        icon: String,
        text: Binding<String>,
        field: Field,
        index: Int,
        placeholder: String = ""
    ) -> some View {
        HStack(alignment: field == .notes ? .top : .center, spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(
                    focusedField == field
                        ? Color.perfumeAccent
                        : Color.perfumeTextSecondary
                )
                .frame(width: 24)
                .padding(.top, field == .notes ? 8 : 0)
                .animation(.spring(duration: 0.25), value: focusedField)

            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Color.perfumeTextSecondary)

                TextField(
                    placeholder.isEmpty ? placeholderFor(label: label) : placeholder,
                    text: text,
                    axis: field == .notes ? .vertical : .horizontal
                )
                .lineLimit(field == .notes ? 3...5 : 1...1)
                .textInputAutocapitalization(.words)
                .font(.body)
                .foregroundStyle(Color.perfumeText)
                .focused($focusedField, equals: field)
                .onChange(of: text.wrappedValue) { _, _ in
                    validationMessage = nil
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.perfumeCard.opacity(0.84))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(
                    focusedField == field
                        ? Color.perfumeAccent
                        : Color.perfumeBorder,
                    lineWidth: focusedField == field ? 1.5 : 1
                )
        )
        .opacity(fieldAppeared[index] ? 1 : 0)
        .offset(x: fieldAppeared[index] ? 0 : -20)
        .animation(.fadeUp.delay(Double(index) * 0.08), value: fieldAppeared[index])
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

    private func animateFieldsIn() {
        for i in 0..<5 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.08) {
                withAnimation {
                    fieldAppeared[i] = true
                }
            }
        }
    }

    private func savePerfume() {
        guard canSave else {
            validationMessage = "Add at least a brand or perfume name before saving."
            triggerSaveFailureFeedback()
            focusedField = trimmedBrand.isEmpty ? .brand : .name
            return
        }

        isSaving = true
        validationMessage = nil
        Haptic.medium()

        let storage = ImageStorageManager.shared
        guard let processedFilename = storage.saveProcessed(currentProcessedImage) else {
            isSaving = false
            validationMessage = "Could not save the processed image. Please try again."
            triggerSaveFailureFeedback()
            return
        }
        let originalFilename = originalImage.flatMap { storage.saveOriginal($0.fragranceNormalizedUp()) }

        let perfume = Perfume(
            brand: trimmedBrand,
            name: trimmedName,
            concentration: concentration.trimmingCharacters(in: .whitespacesAndNewlines),
            volume: volume.trimmingCharacters(in: .whitespacesAndNewlines),
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
            processedImageFilename: processedFilename,
            originalImageFilename: originalFilename,
            ocrText: ocrResult?.fullText,
            radarElder: aiAnalysis?.elder ?? 0,
            radarDate: aiAnalysis?.date ?? 0,
            radarGirlApproved: aiAnalysis?.girlApproved ?? 0,
            radarOffice: aiAnalysis?.office ?? 0,
            radarSelf: aiAnalysis?.selfComfort ?? 0,
            radarImpression: aiAnalysis?.impression ?? 0,
            strategyLine: aiAnalysis?.review.prefix(12).trimmingCharacters(in: .whitespaces) ?? ""
        )

        modelContext.insert(perfume)

        do {
            try modelContext.save()
            Haptic.success()
            withAnimation(.checkPop) {
                isSaving = false
                saveSuccess = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                onSaved()
            }
        } catch {
            storage.deleteImage(filename: processedFilename, type: .processed)
            storage.deleteImage(filename: originalFilename, type: .original)
            isSaving = false
            validationMessage = "Could not save this perfume. Please try again."
            triggerSaveFailureFeedback()
        }
    }

    private func triggerSaveFailureFeedback() {
        Haptic.error()
        saveFailed.toggle()
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

    private func refineCutout(_ normalizedRect: CGRect) {
        guard let originalImage else { return }
        isRefining = true
        validationMessage = nil

        Task {
            guard let result = await PerfumeImageProcessingPipeline()
                .process(originalImage, mode: .manualRegion(normalizedRect)) else {
                await MainActor.run {
                    isRefining = false
                    validationMessage = "Could not isolate the bottle in that area. Try a tighter frame around only the perfume."
                    triggerSaveFailureFeedback()
                }
                return
            }

            await MainActor.run {
                withAnimation(.galleryBloom) {
                    rawCutoutImage = result.rawCutoutImage
                    currentProcessedImage = result.displayImage
                    imageQuality = result.quality
                    isRefining = false
                }
                Haptic.success()
            }
        }
    }
}

#Preview {
    NavigationStack {
        InfoConfirmView(
            processedResult: ProcessedPerfumeImage(
                displayImage: UIImage(systemName: "photo")!,
                rawCutoutImage: nil,
                ocrImages: [],
                quality: CutoutQualityReport(
                    confidence: .high,
                    score: 90,
                    reasons: [],
                    suggestedAction: .accept
                ),
                source: .automaticOriginalMask
            ),
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
