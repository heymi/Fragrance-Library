import SwiftUI
import PhotosUI
import AVFoundation

struct AddPerfumeView: View {
    let onImageSelected: (UIImage) -> Void

    @State private var photoPickerItem: PhotosPickerItem?
    @State private var showCamera = false
    @State private var showCameraDeniedAlert = false
    @State private var optionAppeared: [Bool] = [false, false]

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 24) {
            // Cancel button
            HStack {
                Button("Cancel") { dismiss() }
                    .foregroundStyle(Color.perfumeAccent)
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)

            Spacer()

            // Header
                VStack(spacing: 8) {
                    Image(systemName: "camera.macro")
                        .font(.system(size: 40))
                        .foregroundStyle(Color.perfumeAccent)
                        .padding(.bottom, 4)

                    Text("Add Perfume")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(Color.perfumeText)

                    Text("Capture a photo of your bottle to begin.")
                        .font(.subheadline)
                        .foregroundStyle(Color.perfumeTextSecondary)
                }

                Spacer()

                // Options
                VStack(spacing: 14) {
                    // Take Photo
                    optionButton(
                        icon: "camera.fill",
                        title: "Take Photo",
                        subtitle: "Use your camera",
                        color: Color.perfumeAccent,
                        index: 0
                    ) {
                        requestCameraAndShow()
                    }
                    .offset(x: optionAppeared[0] ? 0 : 60)
                    .opacity(optionAppeared[0] ? 1 : 0)
                    .animation(.fadeUp.delay(0.05), value: optionAppeared[0])

                    // Choose from Library
                    PhotosPicker(
                        selection: $photoPickerItem,
                        matching: .images,
                        photoLibrary: .shared()
                    ) {
                        optionButtonLabel(
                            icon: "photo.on.rectangle",
                            title: "Choose from Library",
                            subtitle: "Select an existing photo",
                            color: Color.perfumeText
                        )
                    }
                    .onChange(of: photoPickerItem) { _, newItem in
                        Task {
                            if let data = try? await newItem?.loadTransferable(type: Data.self),
                               let image = UIImage(data: data) {
                                await MainActor.run {
                                    onImageSelected(image)
                                }
                            }
                        }
                    }
                    .offset(x: optionAppeared[1] ? 0 : 60)
                    .opacity(optionAppeared[1] ? 1 : 0)
                    .animation(.fadeUp.delay(0.15), value: optionAppeared[1])
                }
                .padding(.horizontal, 24)

                Spacer()
                Spacer()
        }
        .background(Color.perfumeBg)
        .onAppear {
            optionAppeared[0] = true
            optionAppeared[1] = true
        }
        .alert("Camera Access Needed", isPresented: $showCameraDeniedAlert) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Please enable camera access in Settings to take photos of your perfume bottles.")
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraPickerView { image in
                showCamera = false
                onImageSelected(image)
            }
        }
    }

    // MARK: - Helpers

    private func requestCameraAndShow() {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .authorized, .notDetermined:
            showCamera = true
        case .denied, .restricted:
            showCameraDeniedAlert = true
        @unknown default:
            showCamera = true
        }
    }

    private func optionButton(
        icon: String,
        title: String,
        subtitle: String,
        color: Color,
        index: Int,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            optionButtonLabel(icon: icon, title: title, subtitle: subtitle, color: color)
        }
        .buttonStyle(OptionButtonStyle())
    }

    private func optionButtonLabel(
        icon: String,
        title: String,
        subtitle: String,
        color: Color
    ) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.perfumeText)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(Color.perfumeTextSecondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.perfumeTextSecondary)
        }
        .padding(16)
        .background(Color.perfumeCard)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - Button Style

struct OptionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.buttonPress, value: configuration.isPressed)
    }
}

// MARK: - Camera Picker (UIKit bridge)

struct CameraPickerView: UIViewControllerRepresentable {
    let onImagePicked: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPickerView

        init(_ parent: CameraPickerView) {
            self.parent = parent
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let image = info[.originalImage] as? UIImage {
                // Don't manually dismiss — let SwiftUI handle it via the showCamera binding.
                parent.onImagePicked(image)
            }
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

#Preview {
    AddPerfumeView { _ in }
}
