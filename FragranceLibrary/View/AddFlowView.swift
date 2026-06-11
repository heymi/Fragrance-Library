import SwiftUI

struct AddFlowView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var selectedImage: UIImage?
    @State private var processedResult: ProcessedPerfumeImage?
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
                    ImageProcessingView(originalImage: image) { result, ocr, analysis in
                        processedResult = result
                        ocrResult = ocr
                        aiAnalysis = analysis
                        showConfirm = true
                    }
                }
            }
            .navigationDestination(isPresented: $showConfirm) {
                if let result = processedResult {
                    InfoConfirmView(
                        originalImage: selectedImage,
                        processedResult: result,
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
