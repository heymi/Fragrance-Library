import SwiftUI

/// Container that wraps the entire "Add Perfume" flow in a single NavigationStack.
/// Eliminates cross-presentation-level state conflicts present in the old
/// sheet + fullScreenCover approach on HomeView.
struct AddFlowView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var selectedImage: UIImage?
    @State private var processedImage: UIImage?
    @State private var rawCutoutImage: UIImage?
    @State private var ocrResult: OCRResult?
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
                    ImageProcessingView(originalImage: image) { rendered, rawCutout, ocr in
                        processedImage = rendered
                        rawCutoutImage = rawCutout
                        ocrResult = ocr
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
