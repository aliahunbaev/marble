import SwiftUI
import SwiftData
import PhotosUI
import UIKit

struct ClosingRitualView: View {
    let workout: Workout

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var noteText: String = ""
    @State private var capturedImage: UIImage?
    @State private var capturedPhoto: ProgressPhoto?
    @State private var showingCamera = false
    @State private var showingLibrary = false
    @State private var libraryItem: PhotosPickerItem?
    @FocusState private var noteFocused: Bool

    var body: some View {
        ZStack {
            Color("marbleBackground").ignoresSafeArea()

            VStack(spacing: 0) {
                // Top bar with close
                HStack {
                    Spacer()
                    Button {
                        save(skipping: true)
                    } label: {
                        Text("Skip")
                            .font(.custom("ABCFavoritVariable-Trial", size: 14).weight(.light))
                            .foregroundStyle(Color("marbleSecondary"))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)

                ScrollView {
                    VStack(spacing: 32) {
                        // Title
                        VStack(spacing: 12) {
                            Text("HOW DID IT FEEL?")
                                .font(.custom("ABC Favorit Mono Variable Unlicensed Trial", size: 11).weight(.medium))
                                .tracking(2)
                                .foregroundStyle(Color("marbleSecondary"))

                            Text(formattedDuration)
                                .font(.custom("ABC Favorit Mono Variable Unlicensed Trial", size: 13).weight(.light))
                                .tracking(1)
                                .foregroundStyle(Color("marbleSecondary").opacity(0.6))
                        }
                        .padding(.top, 32)

                        // Photo zone
                        photoZone
                            .padding(.horizontal, 20)

                        // Note zone
                        noteZone
                            .padding(.horizontal, 20)
                    }
                    .padding(.bottom, 40)
                }

                Spacer(minLength: 0)

                // Save button
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    save(skipping: false)
                } label: {
                    Text("SAVE")
                        .font(.custom("ABC Favorit Mono Variable Unlicensed Trial", size: 12).weight(.medium))
                        .tracking(2)
                        .foregroundStyle(Color("marbleBackground"))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color("marblePrimary"))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
            }
        }
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
        .onTapGesture {
            noteFocused = false
        }
    }

    // MARK: - Photo Zone

    private var photoZone: some View {
        Group {
            if let img = capturedImage {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: 280)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(alignment: .topTrailing) {
                        Button {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            capturedImage = nil
                            if let photo = capturedPhoto {
                                PhotoStorageService.shared.delete(photo, context: modelContext)
                                capturedPhoto = nil
                            }
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 11, weight: .light))
                                .foregroundStyle(.white)
                                .padding(8)
                                .background(.black.opacity(0.4))
                                .clipShape(Circle())
                        }
                        .padding(8)
                    }
            } else {
                HStack(spacing: 10) {
                    captureOption(icon: "camera", label: "PHOTO") {
                        showingCamera = true
                    }
                    captureOption(icon: "photo.on.rectangle", label: "LIBRARY") {
                        showingLibrary = true
                    }
                }
            }
        }
    }

    private func captureOption(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        } label: {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .ultraLight))
                Text(label)
                    .font(.custom("ABC Favorit Mono Variable Unlicensed Trial", size: 10).weight(.light))
                    .tracking(1.5)
            }
            .foregroundStyle(Color("marbleSecondary"))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 40)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color("marblePrimary").opacity(0.12), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Note Zone

    private var noteZone: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("NOTE")
                .font(.custom("ABC Favorit Mono Variable Unlicensed Trial", size: 10).weight(.light))
                .tracking(1.5)
                .foregroundStyle(Color("marbleSecondary"))

            ZStack(alignment: .topLeading) {
                if noteText.isEmpty {
                    Text("A line about today.")
                        .font(.custom("ABCFavoritVariable-Trial", size: 16).weight(.light))
                        .foregroundStyle(Color("marbleSecondary").opacity(0.4))
                        .padding(.top, 8)
                        .padding(.leading, 4)
                }
                TextEditor(text: $noteText)
                    .font(.custom("ABCFavoritVariable-Trial", size: 16).weight(.light))
                    .foregroundStyle(Color("marblePrimary"))
                    .focused($noteFocused)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 80)
            }
            Rectangle()
                .fill(Color("marblePrimary").opacity(0.15))
                .frame(height: 0.5)
        }
    }

    // MARK: - Save

    private func handleImage(_ image: UIImage) {
        capturedImage = image
        capturedPhoto = PhotoStorageService.shared.savePhoto(
            image,
            workoutCloudID: workout.cloudID,
            context: modelContext
        )
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    private func save(skipping: Bool) {
        let trimmed = noteText.trimmingCharacters(in: .whitespaces)
        if !skipping || !trimmed.isEmpty {
            workout.notes = trimmed.isEmpty ? nil : trimmed
            try? modelContext.save()
            CloudSyncService.shared.uploadWorkout(workout)
        }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        dismiss()
    }

    // MARK: - Helpers

    private var formattedDuration: String {
        let totalMinutes = Int(workout.duration) / 60
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }
}
