import SwiftUI

/// Container that wraps the entire "Add Perfume" flow in a single NavigationStack.
/// Eliminates cross-presentation-level state conflicts present in the old
/// sheet + fullScreenCover approach on HomeView.
struct AddFlowView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var selectedImage: UIImage?
    @State private var processedImage: UIImage?
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
                    ImageProcessingView(originalImage: image) { processed, ocr in
                        processedImage = processed
                        ocrResult = ocr
                        showConfirm = true
                    }
                }
            }
            .navigationDestination(isPresented: $showConfirm) {
                if let processed = processedImage {
                    InfoConfirmView(
                        processedImage: processed,
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
