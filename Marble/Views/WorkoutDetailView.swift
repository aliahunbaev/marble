import SwiftUI
import SwiftData

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
                        .font(.custom("ABC Favorit Variable Unlicensed Trial", size: 24).weight(.light))
                        .foregroundStyle(Color("marblePrimary"))

                    HStack(spacing: 12) {
                        Text(formattedDate)
                            .font(.custom("ABC Favorit Mono Variable Unlicensed Trial", size: 12).weight(.light))
                            .foregroundStyle(Color("marbleSecondary"))

                        Text(formattedDuration)
                            .font(.custom("ABC Favorit Mono Variable Unlicensed Trial", size: 12).weight(.light))
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
                        .font(.custom("ABCFavoritVariable-Trial", size: 16).weight(.light))
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

                // Delete button
                Button(role: .destructive) {
                    showingDeleteConfirmation = true
                } label: {
                    Text("Delete Workout")
                        .font(.custom("ABC Favorit Mono Variable Unlicensed Trial", size: 13).weight(.light))
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Color.red.opacity(0.3), lineWidth: 0.5)
                        )
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 20)
                .padding(.top, 32)
            }
            .padding(.bottom, 40)
        }
        .background(Color("marbleBackground"))
        .navigationBarTitleDisplayMode(.inline)
        .alert("Delete this workout? This cannot be undone.", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                let cloudID = workout.cloudID
                modelContext.delete(workout)
                try? modelContext.save()
                CloudSyncService.shared.deleteWorkout(cloudID: cloudID)
                dismiss()
            }
        }
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
            .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private func exerciseSection(log: ExerciseLog) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Exercise name
            Text(log.exercise?.name ?? "Unknown")
                .font(.custom("ABC Favorit Variable Unlicensed Trial", size: 18).weight(.light))
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
            .font(.custom("ABC Favorit Mono Variable Unlicensed Trial", size: 10).weight(.light))
            .tracking(0.5)
            .foregroundStyle(Color("marbleSecondary"))
            .padding(.horizontal, 20)
            .padding(.bottom, 8)

            // Set rows
            let completedSets = log.sets.filter { $0.isCompleted }
            ForEach(Array(completedSets.enumerated()), id: \.offset) { index, set in
                HStack(spacing: 12) {
                    Text("\(index + 1)")
                        .font(.custom("ABC Favorit Mono Variable Unlicensed Trial", size: 13).weight(.light))
                        .foregroundStyle(Color("marbleSecondary"))
                        .frame(width: 36, alignment: .center)

                    Text(formattedWeight(set.weight))
                        .font(.custom("ABC Favorit Mono Variable Unlicensed Trial", size: 13).weight(.light))
                        .foregroundStyle(Color("marblePrimary"))
                        .frame(maxWidth: .infinity)

                    Text("\(set.reps)")
                        .font(.custom("ABC Favorit Mono Variable Unlicensed Trial", size: 13).weight(.light))
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
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter.string(from: workout.date)
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
