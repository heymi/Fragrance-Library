import SwiftUI

struct ImageProcessingView: View {
    let originalImage: UIImage
    let onContinue: (ProcessedPerfumeImage, OCRResult?, RadarAnalysis?) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var processedResult: ProcessedPerfumeImage?
    @State private var ocrResult: OCRResult?
    @State private var aiAnalysis: RadarAnalysis?
    @State private var progress: Double = 0
    @State private var currentStep: ProcessingStep = .compressing
    @State private var isComplete = false
    @State private var hasError = false
    @State private var errorMessage: String?
    @State private var showAfter = false
    @State private var showContinue = false
    @State private var showImagePreview = false
    @State private var showManualCrop = false
    @State private var task: Task<Void, Never>?

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.top, 34)

            Spacer(minLength: 22)

            imageComparisonArea
                .padding(.horizontal, 24)

            Spacer(minLength: 22)

            bottomSection
                .padding(.horizontal, 32)

            Spacer(minLength: 18)
        }
        .background(PerfumePaperBackground())
        .onAppear {
            startProcessing()
        }
        .onDisappear {
            task?.cancel()
        }
        .fullScreenCover(isPresented: $showImagePreview) {
            if let processedResult {
                ImagePreviewView(image: processedResult.displayImage)
            }
        }
        .fullScreenCover(isPresented: $showManualCrop) {
            ManualBottleCropView(image: originalImage) { normalizedRect in
                showManualCrop = false
                applyManualCrop(normalizedRect)
            }
        }
    }

    private var header: some View {
        VStack(spacing: 8) {
            Text("CUTOUT ATELIER")
                .font(.caption.weight(.semibold))
                .tracking(2.2)
                .foregroundStyle(Color.perfumeAccent)

            Text(isComplete ? completionTitle : "Creating Bottle Cutout")
                .font(.system(size: 26, weight: .regular, design: .serif))
                .foregroundStyle(Color.perfumeText)

            Text(isComplete ? completionSubtitle : "Compressing, isolating the bottle, enhancing, and reading label text locally.")
                .font(.footnote.weight(.medium))
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.perfumeTextSecondary)
                .padding(.horizontal, 32)
        }
    }

    private var completionTitle: String {
        if hasError { return "Needs Bottle Area" }
        if processedResult?.quality.confidence == .medium { return "Needs Check" }
        if processedResult?.quality.confidence == .low { return "Needs Refine" }
        return "Cutout Ready"
    }

    private var completionSubtitle: String {
        if hasError {
            return "The automatic cutout could not confidently isolate the perfume. Select the bottle area for a cleaner result."
        }
        if let quality = processedResult?.quality, quality.confidence != .high {
            return quality.reasons.first ?? "Review the bottle edge before saving."
        }
        return "Tap the image to inspect transparency, outline, and edges before saving."
    }

    @ViewBuilder
    private var bottomSection: some View {
        if !isComplete {
            progressSection
        } else if hasError {
            errorSection
        } else if showContinue {
            successSection
                .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    @ViewBuilder
    private var imageComparisonArea: some View {
        if isComplete, !hasError, let result = processedResult {
            Image(uiImage: result.displayImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .shadow(color: Color.perfumeShadow, radius: 12, y: 4)
                .frame(maxHeight: 380)
                .contentShape(Rectangle())
                .onTapGesture {
                    showImagePreview = true
                }
                .opacity(showAfter ? 1 : 0)
                .animation(.fadeUp, value: showAfter)
        } else {
            ZStack(alignment: .bottomLeading) {
                Image(uiImage: originalImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .frame(maxHeight: 340)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(Color.perfumeBorder, lineWidth: 1)
                    )

                Label(currentStep.label, systemImage: "wand.and.stars")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.perfumeText.opacity(0.72))
                    .clipShape(Capsule())
                    .padding(14)
            }
        }
    }

    private var progressSection: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .stroke(Color.perfumeBorder, lineWidth: 6)
                    .frame(width: 72, height: 72)

                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        Color.perfumeAccent,
                        style: StrokeStyle(lineWidth: 6, lineCap: .round)
                    )
                    .frame(width: 72, height: 72)
                    .rotationEffect(.degrees(-90))
                    .animation(.smoothProgress, value: progress)

                Text("\(Int(progress * 100))%")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.perfumeAccent)
            }

            VStack(spacing: 10) {
                ForEach(ProcessingStep.allCases) { step in
                    stepRow(step)
                }
            }
        }
    }

    private var successSection: some View {
        VStack(spacing: 10) {
            if let quality = processedResult?.quality {
                qualityBadge(quality)
            }

            Button {
                Haptic.medium()
                if let processedResult {
                    onContinue(processedResult, ocrResult, aiAnalysis)
                }
            } label: {
                Text("Continue to Details")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.perfumeAccent)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(PremiumPrimaryButtonStyle())

            Button {
                showManualCrop = true
            } label: {
                Label("Refine Bottle Area", systemImage: "crop")
            }
            .buttonStyle(PremiumSecondaryButtonStyle())

            Text("OCR is only a starting point. You can edit every field next.")
                .font(.footnote.weight(.medium))
                .foregroundStyle(Color.perfumeTextSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
        }
    }

    private var errorSection: some View {
        VStack(spacing: 12) {
            Text(errorMessage ?? "Processing failed.")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.perfumeDanger)

            Button("Retry Smart Cutout") {
                startProcessing()
            }
            .buttonStyle(PremiumPrimaryButtonStyle())

            Button("Manually Select Bottle") {
                showManualCrop = true
            }
            .buttonStyle(PremiumSecondaryButtonStyle())

            Button("Continue with Safe Crop") {
                startProcessing(useSmartCrop: false)
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Color.perfumeTextSecondary)
        }
    }

    private func qualityBadge(_ quality: CutoutQualityReport) -> some View {
        HStack(spacing: 8) {
            Image(systemName: quality.confidence == .high ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
            Text("\(quality.confidence.title) · \(quality.score)")
                .font(.caption.weight(.semibold))
        }
        .foregroundStyle(quality.confidence == .high ? Color.perfumeAccent : Color.perfumeDanger)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill((quality.confidence == .high ? Color.perfumeAccent : Color.perfumeDanger).opacity(0.1))
        )
    }

    @ViewBuilder
    private func stepRow(_ step: ProcessingStep) -> some View {
        HStack(spacing: 10) {
            switch step.status(currentStep: currentStep, hasError: hasError) {
            case .complete:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Color.perfumeAccent)
                    .scaleEffect(step == currentStep ? 1.1 : 1.0)
                    .animation(.checkPop, value: currentStep)
            case .inProgress:
                ProgressView()
                    .scaleEffect(0.7)
                    .frame(width: 20, height: 20)
            case .error:
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(Color.perfumeDanger)
            case .pending:
                Circle()
                    .stroke(Color.perfumeBorder, lineWidth: 1.5)
                    .frame(width: 20, height: 20)
            }

            Text(step.label)
                .font(.subheadline)
                .foregroundStyle(
                    step.status(currentStep: currentStep, hasError: hasError) == .pending
                        ? Color.perfumeTextSecondary
                        : Color.perfumeText
                )

            Spacer()
        }
    }

    private func startProcessing(useSmartCrop: Bool = true) {
        hasError = false
        isComplete = false
        showAfter = false
        showContinue = false
        progress = 0
        currentStep = .compressing
        processedResult = nil
        ocrResult = nil

        task?.cancel()
        task = Task {
            await processImage(useSmartCrop: useSmartCrop)
        }
    }

    private func applyManualCrop(_ normalizedRect: CGRect) {
        hasError = false
        isComplete = false
        showAfter = false
        showContinue = false
        progress = 0
        currentStep = .cropping
        processedResult = nil
        ocrResult = nil

        task?.cancel()
        task = Task {
            await processManualCrop(normalizedRect)
        }
    }

    private func processImage(useSmartCrop: Bool) async {
        let pipeline = PerfumeImageProcessingPipeline()
        let ocrService = OCRService()

        await MainActor.run { currentStep = .compressing }
        await animateProgress(to: 0.25)
        try? await Task.sleep(for: .milliseconds(160))

        await MainActor.run { currentStep = .cropping }
        await animateProgress(to: 0.50)
        try? await Task.sleep(for: .milliseconds(160))

        await MainActor.run { currentStep = .enhancing }
        await animateProgress(to: 0.70)
        let mode: PerfumeProcessingMode = useSmartCrop ? .automatic : .safeCrop
        guard let result = await pipeline.process(originalImage, mode: mode) else {
            await handleError("Failed to process this image.")
            return
        }
        guard !Task.isCancelled else { return }
        try? await Task.sleep(for: .milliseconds(160))

        await MainActor.run { currentStep = .rendering }
        await animateProgress(to: 0.90)

        if useSmartCrop && result.quality.confidence == .low {
            await MainActor.run {
                processedResult = result
            }
            await handleError("Could not confidently isolate the perfume bottle. Select the bottle area so the app can cut inside that region.")
            return
        }

        async let bestOCR = ocrService.recognizeBestText(from: result.ocrImages)
        let ocr = await bestOCR
        debugLogOCR(result: ocr, source: result.source)

        // AI analysis — non-blocking, silent skip on failure
        var analysis: RadarAnalysis? = nil
        let text = ocr.fullText
        if !text.isEmpty {
            await MainActor.run { currentStep = .aiAnalyze }
            await animateProgress(to: 0.97)
            analysis = await DeepSeekService().analyze(ocrText: text)
        }

        await MainActor.run {
            processedResult = result
            self.ocrResult = ocr
            self.aiAnalysis = analysis
            progress = 1.0
            currentStep = .rendering
            isComplete = true

            withAnimation(.fadeUp) {
                showAfter = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                withAnimation(.spring(duration: 0.4, bounce: 0.2)) {
                    showContinue = true
                }
            }
        }
    }

    private func processManualCrop(_ normalizedRect: CGRect) async {
        let pipeline = PerfumeImageProcessingPipeline()
        let ocrService = OCRService()

        await animateProgress(to: 0.25)
        await MainActor.run { currentStep = .cropping }
        await animateProgress(to: 0.55)
        guard let result = await pipeline.process(originalImage, mode: .manualRegion(normalizedRect)) else {
            await handleError("Could not isolate the bottle inside the selected area. Try framing only the perfume, with less hand or background.")
            return
        }
        guard !Task.isCancelled else { return }

        await MainActor.run { currentStep = .rendering }
        await animateProgress(to: 0.90)

        async let bestOCR = ocrService.recognizeBestText(from: result.ocrImages)
        let ocr = await bestOCR
        debugLogOCR(result: ocr, source: result.source)

        var analysis: RadarAnalysis? = nil
        let text = ocr.fullText
        if !text.isEmpty {
            await MainActor.run { currentStep = .aiAnalyze }
            await animateProgress(to: 0.97)
            analysis = await DeepSeekService().analyze(ocrText: text)
        }

        await MainActor.run {
            processedResult = result
            self.ocrResult = ocr
            self.aiAnalysis = analysis
            progress = 1.0
            currentStep = .rendering
            isComplete = true

            withAnimation(.fadeUp) {
                showAfter = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                withAnimation(.spring(duration: 0.4, bounce: 0.2)) {
                    showContinue = true
                }
            }
        }
    }

    private func animateProgress(to target: Double) async {
        let start = progress
        let steps = 20
        for i in 1...steps {
            let fraction = Double(i) / Double(steps)
            await MainActor.run {
                progress = start + (target - start) * fraction
            }
            try? await Task.sleep(for: .milliseconds(16))
        }
    }

    @MainActor
    private func handleError(_ message: String) {
        hasError = true
        errorMessage = message
        isComplete = true
        Haptic.error()
    }

    private func debugLogOCR(result: OCRResult, source: ProcessingSource) {
        #if DEBUG
        let summary = [result.brand, result.name, result.concentration, result.volume]
            .compactMap { $0 }
            .joined(separator: " | ")
        print("ImageProcessingView: bestOCR source=\(source.debugName) textLength=\(result.fullText.count) fields=\(summary)")
        #endif
    }
}

enum ProcessingStep: Int, CaseIterable, Identifiable {
    case compressing = 0
    case cropping
    case enhancing
    case rendering
    case aiAnalyze

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .compressing: return "Preparing photo"
        case .cropping: return "Finding bottle region"
        case .enhancing: return "Enhancing label visibility"
        case .rendering: return "Building transparent cutout"
        case .aiAnalyze: return "AI scoring your perfume"
        }
    }

    enum Status {
        case pending, inProgress, complete, error
    }

    func status(currentStep: ProcessingStep, hasError: Bool) -> Status {
        if hasError && self == currentStep { return .error }
        if rawValue < currentStep.rawValue { return .complete }
        if rawValue == currentStep.rawValue { return .inProgress }
        return .pending
    }
}

struct OCRResult {
    let fullText: String
    let brand: String?
    let name: String?
    let concentration: String?
    let volume: String?
}
