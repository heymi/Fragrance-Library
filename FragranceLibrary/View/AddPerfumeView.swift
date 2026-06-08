import SwiftUI
import PhotosUI
import AVFoundation

struct AddPerfumeView: View {
    let onImageSelected: (UIImage) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var photoPickerItem: PhotosPickerItem?
    @State private var showCamera = false
    @State private var showCameraDeniedAlert = false
    @State private var optionAppeared: [Bool] = [false, false]

    var body: some View {
        VStack(spacing: 24) {
            HStack {
                Button("Close") { dismiss() }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.perfumeAccent)
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)

            Spacer()

            VStack(spacing: 12) {
                Text("SCENT ARCHIVE")
                    .font(.caption.weight(.semibold))
                    .tracking(2.4)
                    .foregroundStyle(Color.perfumeAccent)

                Text("Add Perfume")
                    .font(.system(size: 30, weight: .regular, design: .serif))
                    .foregroundStyle(Color.perfumeText)

                Text("A quiet front-facing photo makes the bottle cutout cleaner.")
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color.perfumeTextSecondary)
                    .padding(.horizontal, 28)
            }

            shootingGuide
                .padding(.horizontal, 24)

            VStack(spacing: 14) {
                optionButton(
                    icon: "camera.fill",
                    title: "Take Photo",
                    subtitle: "Best for adding a bottle now",
                    color: Color.perfumeAccent
                ) {
                    requestCameraAndShow()
                }
                .offset(x: optionAppeared[0] ? 0 : 60)
                .opacity(optionAppeared[0] ? 1 : 0)
                .animation(.fadeUp.delay(0.05), value: optionAppeared[0])

                PhotosPicker(
                    selection: $photoPickerItem,
                    matching: .images,
                    photoLibrary: .shared()
                ) {
                    optionButtonLabel(
                        icon: "photo.on.rectangle",
                        title: "Choose from Library",
                        subtitle: "Use an existing bottle photo",
                        color: Color.perfumeText
                    )
                }
                .onChange(of: photoPickerItem) { _, newItem in
                    Task {
                        if let data = try? await newItem?.loadTransferable(type: Data.self),
                           let image = UIImage(data: data) {
                            await MainActor.run {
                                Haptic.medium()
                                photoPickerItem = nil
                                onImageSelected(image.fragranceNormalizedUp())
                            }
                        }
                    }
                }
                .offset(x: optionAppeared[1] ? 0 : 60)
                .opacity(optionAppeared[1] ? 1 : 0)
                .animation(.fadeUp.delay(0.15), value: optionAppeared[1])
            }
            .padding(.horizontal, 24)

            VStack(spacing: 6) {
                Label("Everything stays on this device", systemImage: "lock.fill")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(Color.perfumeTextSecondary)
                Text("Photos, OCR text, and collection data are stored locally.")
                    .font(.caption)
                    .foregroundStyle(Color.perfumeTextSecondary.opacity(0.8))
            }

            Spacer()
        }
        .background(PerfumePaperBackground())
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

    private func requestCameraAndShow() {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .authorized:
            showCamera = true
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    if granted {
                        showCamera = true
                    } else {
                        showCameraDeniedAlert = true
                    }
                }
            }
        case .denied, .restricted:
            showCameraDeniedAlert = true
        @unknown default:
            showCamera = true
        }
    }

    private var shootingGuide: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "viewfinder")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.perfumeAccent)

                Text("Best capture")
                    .font(PerfumeType.label(11))
                    .tracking(1.6)
                    .foregroundStyle(Color.perfumeTextSecondary)
            }

            VStack(spacing: 9) {
                guideRow("Keep hands outside the bottle edge")
                guideRow("Use a simple light background")
                guideRow("Include cap, label, and base")
            }
        }
        .padding(15)
        .background(Color.perfumeCard.opacity(0.68))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.perfumeBorder.opacity(0.78), lineWidth: 1)
        )
    }

    private func guideRow(_ text: String) -> some View {
        HStack(spacing: 9) {
            Circle()
                .fill(Color.perfumeAccent.opacity(0.58))
                .frame(width: 4, height: 4)

            Text(text)
                .font(PerfumeType.body(12))
                .foregroundStyle(Color.perfumeText)

            Spacer()
        }
    }

    private func optionButton(
        icon: String,
        title: String,
        subtitle: String,
        color: Color,
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
        .background(Color.perfumeCard.opacity(0.82))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.perfumeBorder, lineWidth: 1)
        )
    }
}

struct OptionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.buttonPress, value: configuration.isPressed)
    }
}

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
                parent.onImagePicked(image.fragranceNormalizedUp())
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
