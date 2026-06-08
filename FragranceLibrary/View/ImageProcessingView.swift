import SwiftUI

struct ImageProcessingView: View {
    let originalImage: UIImage
    let onContinue: (UIImage, OCRResult?) -> Void

    @State private var processedImage: UIImage?
    @State private var ocrResult: OCRResult?

    @State private var progress: Double = 0
    @State private var currentStep: ProcessingStep = .compressing
    @State private var isComplete = false
    @State private var hasError = false
    @State private var errorMessage: String?
    @State private var showAfter = false
    @State private var showContinue = false
    @State private var task: Task<Void, Never>?

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
                // Header
                Text(isComplete ? "Processing Complete" : "Processing Image")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Color.perfumeText)
                    .padding(.top, 40)

                Spacer()

                // Image area
                imageComparisonArea
                    .padding(.horizontal, 24)

                Spacer()

                // Progress / Steps
                if !isComplete {
                    progressSection
                        .padding(.horizontal, 32)
                } else if !hasError {
                    // Continue button on success
                    if showContinue {
                        Button {
                            Haptic.medium()
                            if let processed = processedImage {
                                onContinue(processed, ocrResult)
                            }
                        } label: {
                            Text("Continue")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color.perfumeAccent)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .padding(.horizontal, 32)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                } else {
                    // Error + retry
                    VStack(spacing: 12) {
                        Text(errorMessage ?? "Processing failed.")
                            .font(.subheadline)
                            .foregroundStyle(Color.perfumeDanger)
                        Button("Retry") {
                            startProcessing()
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding(.horizontal, 32)
                }

                Spacer()
            }
            .background(Color.perfumeBg)
            .onAppear {
                startProcessing()
            }
    }

    // MARK: - Image Comparison

    @ViewBuilder
    private var imageComparisonArea: some View {
        if isComplete, let processed = processedImage {
            // Show processed result
            Image(uiImage: processed)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: PerfumeLayout.cardCornerRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: PerfumeLayout.cardCornerRadius)
                        .strokeBorder(.white, lineWidth: PerfumeLayout.imageBorderWidth)
                )
                .shadow(color: Color.perfumeShadow, radius: 12, y: 4)
                .frame(maxHeight: 360)
                .opacity(showAfter ? 1 : 0)
                .animation(.fadeUp, value: showAfter)
        } else {
            // Show original during processing
            Image(uiImage: originalImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .frame(maxHeight: 320)
        }
    }

    // MARK: - Progress Section

    private var progressSection: some View {
        VStack(spacing: 20) {
            // Circular progress
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

            // Steps
            VStack(spacing: 10) {
                ForEach(ProcessingStep.allCases) { step in
                    stepRow(step)
                }
            }
        }
    }

    @ViewBuilder
    private func stepRow(_ step: ProcessingStep) -> some View {
        HStack(spacing: 10) {
            if step.status(currentStep: currentStep, hasError: hasError) == .complete {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Color.perfumeAccent)
                    .scaleEffect(step == currentStep ? 1.1 : 1.0)
                    .animation(.checkPop, value: currentStep)
            } else if step.status(currentStep: currentStep, hasError: hasError) == .inProgress {
                ProgressView()
                    .scaleEffect(0.7)
                    .frame(width: 20, height: 20)
            } else if step.status(currentStep: currentStep, hasError: hasError) == .error {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(Color.perfumeDanger)
            } else {
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

    // MARK: - Processing

    private func startProcessing() {
        hasError = false
        isComplete = false
        showAfter = false
        showContinue = false
        progress = 0
        currentStep = .compressing
        processedImage = nil
        ocrResult = nil

        task?.cancel()
        task = Task {
            await processImage()
        }
    }

    private func processImage() async {
        let processor = ImageProcessor()
        let ocrService = OCRService()

        // Step 1: Compress
        currentStep = .compressing
        await animateProgress(to: 0.25)
        guard let compressed = processor.downscale(originalImage, maxWidth: 1024) else {
            await handleError("Failed to compress image.")
            return
        }
        try? await Task.sleep(for: .milliseconds(200))

        // Step 2: Crop
        currentStep = .cropping
        await animateProgress(to: 0.50)
        let cropped = await processor.smartCrop(compressed)
        try? await Task.sleep(for: .milliseconds(200))

        // Step 3: Adjust colors
        currentStep = .enhancing
        await animateProgress(to: 0.70)
        let enhanced = processor.enhance(cropped)
        try? await Task.sleep(for: .milliseconds(200))

        // Step 4: Render with border
        currentStep = .rendering
        await animateProgress(to: 0.90)

        // Run OCR in parallel with rendering
        async let ocrResult = ocrService.recognizeText(from: originalImage)

        guard let rendered = processor.renderWithCardStyle(enhanced) else {
            await handleError("Failed to render final image.")
            return
        }

        let ocr = await ocrResult

        await MainActor.run {
            processedImage = rendered
            self.ocrResult = ocr
            progress = 1.0
            currentStep = .rendering // all steps complete
            isComplete = true

            // Animate after state entrance
            withAnimation(.fadeUp) {
                showAfter = true
            }
            // Delay continue button
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
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
            try? await Task.sleep(for: .milliseconds(16)) // ~60fps
        }
    }

    @MainActor
    private func handleError(_ message: String) {
        hasError = true
        errorMessage = message
        isComplete = true
        Haptic.error()
    }
}

// MARK: - Processing Steps

enum ProcessingStep: Int, CaseIterable, Identifiable {
    case compressing = 0
    case cropping
    case enhancing
    case rendering

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .compressing: return "Compressing image"
        case .cropping: return "Cropping to card ratio"
        case .enhancing: return "Enhancing colors"
        case .rendering: return "Creating display image"
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

// MARK: - OCR Result

struct OCRResult {
    let fullText: String
    let brand: String?
    let name: String?
    let concentration: String?
    let volume: String?
}
