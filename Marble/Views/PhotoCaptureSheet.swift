import SwiftUI
import PhotosUI
import UIKit

/// Modal sheet that captures a progress photo via camera or library.
/// Half-height detent — purposefully small so it reads as a single
/// decision, not a screen of options. Two affordances + a Skip out.
///
/// Aligned with the design system in this pass:
///   - Fonts go through `.marbleMono` / `.marbleBody` (previous file
///     hard-coded `.custom("ABC Favorit Mono ...")` strings, which
///     bypassed the centralized font helpers and drifted from the rest
///     of the app's typography rules).
///   - Buttons match the marble button vocabulary — tinted primary +
///     bordered secondary — instead of the bespoke rounded-rect with
///     inline color logic.
struct PhotoCaptureSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    /// Optional — if provided, the photo links back to this workout so
    /// the YOU feed can render it inline with the entry.
    var workoutCloudID: String? = nil

    /// Called after a photo is captured. Lets a caller celebrate or
    /// chain into another flow (e.g. the closing ritual).
    var onCaptured: ((ProgressPhoto) -> Void)? = nil

    @State private var showingCamera = false
    @State private var showingLibrary = false
    @State private var libraryItem: PhotosPickerItem?

    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(Color("marbleSecondary").opacity(0.3))
                .frame(width: 36, height: 4)
                .padding(.top, 8)

            Spacer()

            VStack(spacing: 10) {
                Text("MARK IT.")
                    .font(.marbleMono(13, weight: .medium))
                    .tracking(2)
                    .foregroundStyle(Color("marblePrimary"))

                Text("A photo of the work.")
                    .font(.marbleBody(15))
                    .foregroundStyle(Color("marbleSecondary"))
            }

            Spacer()

            VStack(spacing: 12) {
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    showingCamera = true
                } label: {
                    captureRow(icon: "camera", label: "Take a photo", emphasized: true)
                }
                .buttonStyle(.plain)

                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    showingLibrary = true
                } label: {
                    captureRow(icon: "photo.on.rectangle", label: "Choose from library", emphasized: false)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 32)

            Button("Skip") {
                dismiss()
            }
            .font(.marbleBody(14))
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

    /// Single capture-row affordance. The emphasized variant uses the
    /// tinted marblePrimary fill (primary commit weight); the
    /// non-emphasized uses marbleCard with a faint hairline border —
    /// matches how the rest of the app treats secondary actions
    /// (Settings selectors, banner backgrounds).
    private func captureRow(icon: String, label: String, emphasized: Bool) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .light))
            Text(label)
                .font(.marbleBody(15, weight: emphasized ? .medium : .regular))
            Spacer()
        }
        .foregroundStyle(emphasized ? Color("marbleBackground") : Color("marblePrimary"))
        .padding(.horizontal, 18)
        .frame(height: 52)
        .background(emphasized ? Color("marblePrimary") : Color("marbleCard"))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(
                    emphasized ? Color.clear : Color("marblePrimary").opacity(0.12),
                    lineWidth: 0.5
                )
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
