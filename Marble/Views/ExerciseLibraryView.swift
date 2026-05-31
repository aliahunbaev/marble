import SwiftUI
import SwiftData

struct ExerciseLibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Exercise.name) private var allExercises: [Exercise]

    @State private var searchText = ""
    @State private var showingCreate = false
    @State private var newName = ""
    @State private var newMuscleGroup = ""

    let selectedExercises: [Exercise]
    let onToggle: (Exercise) -> Void

    private var filteredExercises: [Exercise] {
        if searchText.isEmpty { return allExercises }
        return allExercises.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.muscleGroup.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var groupedExercises: [(String, [Exercise])] {
        let grouped = Dictionary(grouping: filteredExercises) { $0.muscleGroup }
        return grouped.sorted { $0.key < $1.key }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Search bar
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(Color("marbleSecondary"))
                            .font(.system(size: 14))
                        TextField("Search exercises", text: $searchText)
                            .font(.marbleBody(14))
                            .autocorrectionDisabled()
                    }
                    .padding(12)
                    .background(Color("marbleFieldBackground"))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 20)

                    if filteredExercises.isEmpty {
                        emptyState
                    } else {
                        ForEach(groupedExercises, id: \.0) { group, exercises in
                            muscleGroupSection(group, exercises: exercises)
                        }
                    }
                }
                .padding(.bottom, 40)
            }
            .background(Color("marbleBackground"))
            .navigationTitle("Exercises")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Color("marblePrimary"))
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { dismiss() }
                        .font(.marbleMono(14))
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingCreate = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 14, weight: .medium))
                    }
                }
            }
            .alert("New Exercise", isPresented: $showingCreate) {
                TextField("Exercise name", text: $newName)
                TextField("Muscle group (e.g. Chest)", text: $newMuscleGroup)
                Button("Add") { createExercise() }
                Button("Cancel", role: .cancel) {
                    newName = ""
                    newMuscleGroup = ""
                }
            }
        }
    }

    private func muscleGroupSection(_ group: String, exercises: [Exercise]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader(title: group.uppercased())
                .padding(.horizontal, 20)
                .padding(.bottom, 8)

            VStack(spacing: 0) {
                ForEach(exercises) { exercise in
                    exerciseRow(exercise)
                    if exercise.id != exercises.last?.id {
                        Rectangle()
                            .fill(Color("marblePrimary").opacity(0.06))
                            .frame(height: 0.5)
                            .padding(.leading, 20)
                    }
                }
            }
            .overlay(
                Rectangle()
                    .frame(height: 0.5)
                    .foregroundStyle(Color("marblePrimary").opacity(0.06)),
                alignment: .top
            )
            .overlay(
                Rectangle()
                    .frame(height: 0.5)
                    .foregroundStyle(Color("marblePrimary").opacity(0.06)),
                alignment: .bottom
            )
            .padding(.bottom, 24)
        }
    }

    private func exerciseRow(_ exercise: Exercise) -> some View {
        // Drop the inline muscle group label — it's redundant because the
        // section header already groups by muscle. The exercise name gets
        // to breathe at a tactile size with more vertical room.
        let isSelected = selectedExercises.contains(where: { $0.id == exercise.id })
        return Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            onToggle(exercise)
        } label: {
            HStack {
                Text(exercise.name)
                    .font(.marbleBody(17))
                    .foregroundStyle(Color("marblePrimary"))
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Color("marblePrimary"))
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            VStack(spacing: 6) {
                Text("No exercises found.")
                    .font(.marbleBody(15))
                    .foregroundStyle(Color("marbleSecondary"))
                if searchText.isEmpty {
                    Text("Tap + to add one.")
                        .font(.marbleMono(11))
                        .tracking(1)
                        .foregroundStyle(Color("marbleTertiary"))
                }
            }
            if !searchText.isEmpty {
                Button {
                    newName = searchText
                    showingCreate = true
                } label: {
                    Text("CREATE \"\(searchText.uppercased())\"")
                        .marbleSecondaryButton(fullWidth: false)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    private func createExercise() {
        let trimmed = newName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let group = newMuscleGroup.trimmingCharacters(in: .whitespaces)
        let exercise = Exercise(name: trimmed, muscleGroup: group.isEmpty ? "General" : group)
        modelContext.insert(exercise)
        onToggle(exercise)
        newName = ""
        newMuscleGroup = ""
    }
}

#Preview {
    ExerciseLibraryView(selectedExercises: []) { _ in }
        .modelContainer(for: Exercise.self, inMemory: true)
}
