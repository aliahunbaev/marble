import SwiftUI
import SwiftData
import PhotosUI
import UIKit

struct ClosingRitualView: View {
    let workout: Workout

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @State private var noteText: String = ""
    @State private var capturedImage: UIImage?
    @State private var capturedPhoto: ProgressPhoto?
    @State private var showingCamera = false
    @State private var showingLibrary = false
    @State private var libraryItem: PhotosPickerItem?
    @State private var isRecorded: Bool = false
    @FocusState private var noteFocused: Bool

    var body: some View {
        ZStack {
            Color("marbleBackground").ignoresSafeArea()

            // Tonal gradient matches the rest of the content surfaces. The
            // reverence of the "Recorded." moment comes from typography +
            // spacing, not from a flat background — the subtle warm wash
            // actually enhances the ceremonial quality.
            LinearGradient(
                colors: colorScheme == .dark
                    ? [
                        Color(red: 0.13, green: 0.12, blue: 0.11),
                        Color("marbleBackground"),
                        Color(red: 0.10, green: 0.10, blue: 0.11)
                      ]
                    : [
                        Color(red: 0.97, green: 0.95, blue: 0.92),
                        Color("marbleBackground"),
                        Color(red: 0.94, green: 0.94, blue: 0.95)
                      ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            if isRecorded {
                recordedView
            } else {
                ritualView
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

    // MARK: - Ritual (photo + note)

    private var ritualView: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 28) {
                    Text(formattedDuration)
                        .font(.marbleMono(12))
                        .tracking(2)
                        .foregroundStyle(Color("marbleSecondary"))
                        .padding(.top, 24)

                    photoZone
                        .padding(.horizontal, 20)

                    noteZone
                        .padding(.horizontal, 20)
                }
                .padding(.bottom, 40)
            }

            Spacer(minLength: 0)

            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                save(skipping: false)
            } label: {
                Text("SAVE")
                    .marbleGlassPrimaryCapsule(horizontalPadding: 24, height: 52)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
        }
    }

    // MARK: - Recorded (final closing screen)

    @State private var recordedOpacity: Double = 0

    private var recordedView: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 24) {
                Text("MARBLE")
                    .font(.marbleBody(16))
                    .tracking(6)
                    .foregroundStyle(Color("marblePrimary"))

                Rectangle()
                    .fill(Color("marblePrimary").opacity(0.2))
                    .frame(width: 24, height: 0.5)

                Text("Recorded.")
                    .font(.marbleBody(32))
                    .foregroundStyle(Color("marblePrimary"))

                Text(formattedDate)
                    .font(.marbleMono(11))
                    .tracking(2)
                    .foregroundStyle(Color("marbleSecondary"))
            }
            .opacity(recordedOpacity)

            Spacer()

            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                dismiss()
            } label: {
                Text("DONE")
                    .marbleSecondaryButton()
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
            .opacity(recordedOpacity)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) {
                recordedOpacity = 1
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            }
        }
    }

    // MARK: - Photo Zone

    private var photoZone: some View {
        Group {
            if let img = capturedImage {
                Color.clear
                    .frame(maxWidth: .infinity)
                    .frame(height: 280)
                    .overlay {
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFill()
                    }
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
                    .font(.marbleMono(10))
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
                .font(.marbleMono(10))
                .tracking(1.5)
                .foregroundStyle(Color("marbleSecondary"))

            ZStack(alignment: .topLeading) {
                if noteText.isEmpty {
                    Text("A line about today.")
                        .font(.marbleBody(16))
                        .foregroundStyle(Color("marbleSecondary").opacity(0.4))
                        .padding(.top, 8)
                        .padding(.leading, 4)
                }
                TextEditor(text: $noteText)
                    .font(.marbleBody(16))
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
        noteFocused = false
        withAnimation(.easeInOut(duration: 0.5)) {
            isRecorded = true
        }
    }

    private var formattedDate: String {
        workout.date.formatted(.dateTime.month(.wide).day().year())
            .uppercased()
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
