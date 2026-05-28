import SwiftUI
import PhotosUI
import UIKit

struct PhotoCaptureSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    /// Optional — if provided, photo will be linked to this workout
    var workoutCloudID: String? = nil

    /// Called after a photo is captured (so caller can dismiss/celebrate)
    var onCaptured: ((ProgressPhoto) -> Void)? = nil

    @State private var showingCamera = false
    @State private var showingLibrary = false
    @State private var libraryItem: PhotosPickerItem?

    var body: some View {
        VStack(spacing: 0) {
            // Top drag bar
            Capsule()
                .fill(Color("marbleSecondary").opacity(0.3))
                .frame(width: 36, height: 4)
                .padding(.top, 8)

            Spacer()

            // Title
            VStack(spacing: 8) {
                Text("MARK IT.")
                    .font(.custom("ABC Favorit Mono Variable Unlicensed Trial", size: 13).weight(.medium))
                    .tracking(2)
                    .foregroundStyle(Color("marblePrimary"))

                Text("A photo of the work.")
                    .font(.custom("ABC Favorit Variable Unlicensed Trial", size: 15).weight(.light))
                    .foregroundStyle(Color("marbleSecondary"))
            }

            Spacer()

            // Buttons
            VStack(spacing: 12) {
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    showingCamera = true
                } label: {
                    captureButton(icon: "camera", label: "Take a photo", emphasized: true)
                }

                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    showingLibrary = true
                } label: {
                    captureButton(icon: "photo.on.rectangle", label: "Choose from library", emphasized: false)
                }
            }
            .padding(.horizontal, 32)

            // Skip
            Button("Skip") {
                dismiss()
            }
            .font(.custom("ABC Favorit Variable Unlicensed Trial", size: 14).weight(.light))
            .foregroundStyle(Color("marbleSecondary"))
            .padding(.top, 28)
            .padding(.bottom, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color("marbleBackground").ignoresSafeArea())
        .sheet(isPresented: $showingCamera) {
            CameraPicker { image in
                if let image { handleImage(image) }
                showingCamera = false
            }
            .ignoresSafeArea()
        }
        .photosPicker(isPresented: $showingLibrary, selection: $libraryItem, matching: .images)
        .onChange(of: libraryItem) { _, newItem in
            guard let newItem else { return }
            Task {
                if let data = try? await newItem.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    handleImage(image)
                }
                libraryItem = nil
            }
        }
    }

    private func captureButton(icon: String, label: String, emphasized: Bool) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .light))
            Text(label)
                .font(.custom("ABC Favorit Variable Unlicensed Trial", size: 15).weight(emphasized ? .medium : .regular))
            Spacer()
        }
        .foregroundStyle(emphasized ? Color("marbleBackground") : Color("marblePrimary"))
        .padding(.horizontal, 18)
        .frame(height: 52)
        .background(emphasized ? Color("marblePrimary") : Color("marbleCard"))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(emphasized ? Color.clear : Color("marbleTertiary"), lineWidth: 1)
        )
    }

    private func handleImage(_ image: UIImage) {
        if let photo = PhotoStorageService.shared.savePhoto(
            image,
            workoutCloudID: workoutCloudID,
            context: modelContext
        ) {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            onCaptured?(photo)
        }
        dismiss()
    }
}

// MARK: - Camera Picker (UIImagePickerController wrapper)

struct CameraPicker: UIViewControllerRepresentable {
    var onPicked: (UIImage?) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.allowsEditing = false
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPicker

        init(_ parent: CameraPicker) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            parent.onPicked(info[.originalImage] as? UIImage)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.onPicked(nil)
        }
    }
}
