import SwiftUI
import SwiftData

/// Detail view for a workout entry from the YOU feed. Same cohesion treatment
/// as the other content detail surfaces (BodyweightDetailView,
/// ExerciseLiftDetailView): tonal gradient background, marble typography
/// helpers, marbleDestructiveButton for the delete action.
struct WorkoutDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let workout: Workout

    @Query(sort: \ProgressPhoto.date, order: .reverse) private var allPhotos: [ProgressPhoto]
    @State private var showingDeleteConfirmation = false
    @State private var selectedPhoto: ProgressPhoto?

    private var linkedPhotos: [ProgressPhoto] {
        allPhotos.filter { $0.workoutCloudID == workout.cloudID }
    }

    var body: some View {
        ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Header
                    VStack(alignment: .leading, spacing: 6) {
                        Text(workout.name)
                            .font(.marbleBody(28))
                            .foregroundStyle(Color("marblePrimary"))

                        HStack(spacing: 12) {
                            Text(formattedDate)
                                .font(.marbleMono(12))
                                .foregroundStyle(Color("marbleSecondary"))

                            Text(formattedDuration)
                                .font(.marbleMono(12))
                                .foregroundStyle(Color("marbleSecondary"))
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 28)

                    // Linked photos
                    if !linkedPhotos.isEmpty {
                        photosStrip
                            .padding(.bottom, 24)
                    }

                    // Note (if exists)
                    if let note = workout.notes, !note.isEmpty {
                        Text(note)
                            .font(.marbleBody(16))
                            .foregroundStyle(Color("marblePrimary"))
                            .lineSpacing(4)
                            .padding(.horizontal, 20)
                            .padding(.bottom, 28)
                    }

                    // Exercise logs
                    ForEach(Array(workout.exerciseLogs.enumerated()), id: \.element.id) { index, log in
                        exerciseSection(log: log)

                        if index < workout.exerciseLogs.count - 1 {
                            Rectangle()
                                .fill(Color("marblePrimary").opacity(0.06))
                                .frame(height: 0.5)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 20)
                        }
                    }

                    Button {
                        showingDeleteConfirmation = true
                    } label: {
                        Text("DELETE WORKOUT")
                            .marbleDestructiveButton()
                    }
                    .buttonStyle(.plain)
                .padding(.horizontal, 20)
                .padding(.top, 32)
            }
            .padding(.bottom, 140)
        }
        .marbleAtmosphereBackground()
        .navigationBarTitleDisplayMode(.inline)
        .marbleDialog(
            "Delete this workout?",
            message: "This cannot be undone.",
            isPresented: $showingDeleteConfirmation,
            buttons: [
                .destructive("Delete") {
                    let cloudID = workout.cloudID
                    PhotoStorageService.shared.deletePhotosLinkedToWorkout(
                        cloudID: cloudID,
                        context: modelContext
                    )
                    modelContext.delete(workout)
                    try? modelContext.save()
                    Task { await CloudSyncService.shared.deleteWorkout(cloudID: cloudID) }
                    dismiss()
                },
                .cancel(),
            ]
        )
        .fullScreenCover(item: $selectedPhoto) { photo in
            PhotoViewerView(
                photo: photo,
                workout: workout,
                onDelete: {
                    PhotoStorageService.shared.delete(photo, context: modelContext)
                    selectedPhoto = nil
                }
            )
        }
    }

    private var photosStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(linkedPhotos) { photo in
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        selectedPhoto = photo
                    } label: {
                        photoTile(photo: photo)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
        }
    }

    private func photoTile(photo: ProgressPhoto) -> some View {
        Color.clear
            .frame(width: 220, height: 280)
            .overlay {
                if let img = PhotoStorageService.shared.image(for: photo) {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                } else {
                    Color("marbleFieldBackground")
                }
            }
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func exerciseSection(log: ExerciseLog) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Exercise name
            Text(log.exercise?.name ?? "Unknown")
                .font(.marbleBody(18))
                .foregroundStyle(Color("marblePrimary"))
                .padding(.horizontal, 20)
                .padding(.bottom, 12)

            // Column headers
            HStack(spacing: 12) {
                Text("SET")
                    .frame(width: 36, alignment: .center)
                Text("LBS")
                    .frame(maxWidth: .infinity)
                Text("REPS")
                    .frame(maxWidth: .infinity)
            }
            .font(.marbleMono(10))
            .tracking(1)
            .foregroundStyle(Color("marbleSecondary"))
            .padding(.horizontal, 20)
            .padding(.bottom, 8)

            // Set rows
            let completedSets = log.sets.filter { $0.isCompleted }
            ForEach(Array(completedSets.enumerated()), id: \.offset) { index, set in
                HStack(spacing: 12) {
                    Text("\(index + 1)")
                        .font(.marbleMono(13))
                        .foregroundStyle(Color("marbleSecondary"))
                        .frame(width: 36, alignment: .center)

                    Text(formattedWeight(set.weight))
                        .font(.marbleMono(13))
                        .foregroundStyle(Color("marblePrimary"))
                        .frame(maxWidth: .infinity)

                    Text("\(set.reps)")
                        .font(.marbleMono(13))
                        .foregroundStyle(Color("marblePrimary"))
                        .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 6)
            }
        }
    }

    private func formattedWeight(_ weight: Double) -> String {
        if weight == floor(weight) {
            return "\(Int(weight))"
        }
        return String(format: "%.1f", weight)
    }

    private var formattedDate: String {
        workout.date.marbleFullDate()
    }

    private var formattedDuration: String {
        let minutes = Int(workout.duration) / 60
        if minutes < 60 {
            return "\(minutes) min"
        }
        let hours = minutes / 60
        let remainingMinutes = minutes % 60
        return "\(hours)h \(remainingMinutes)m"
    }
}

#Preview {
    NavigationStack {
        WorkoutDetailView(workout: Workout(name: "Push Day", date: .now, duration: 3600))
    }
    .modelContainer(for: [Workout.self, Exercise.self], inMemory: true)
}
