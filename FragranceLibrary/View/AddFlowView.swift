import SwiftUI

struct AddFlowView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var selectedImage: UIImage?
    @State private var processedImage: UIImage?
    @State private var rawCutoutImage: UIImage?
    @State private var ocrResult: OCRResult?
    @State private var aiAnalysis: RadarAnalysis?
    @State private var showProcessing = false
    @State private var showConfirm = false

    var body: some View {
        NavigationStack {
            AddPerfumeView { image in
                selectedImage = image
                showProcessing = true
            }
            .navigationDestination(isPresented: $showProcessing) {
                if let image = selectedImage {
                    ImageProcessingView(originalImage: image) { rendered, rawCutout, ocr, analysis in
                        processedImage = rendered
                        rawCutoutImage = rawCutout
                        ocrResult = ocr
                        aiAnalysis = analysis
                        showConfirm = true
                    }
                }
            }
            .navigationDestination(isPresented: $showConfirm) {
                if let processed = processedImage {
                    InfoConfirmView(
                        originalImage: selectedImage,
                        processedImage: processed,
                        rawCutoutImage: rawCutoutImage,
                        ocrResult: ocrResult,
                        aiAnalysis: aiAnalysis,
                        onSaved: { dismiss() }
                    )
                }
            }
        }
    }
}

#Preview {
    AddFlowView()
}
