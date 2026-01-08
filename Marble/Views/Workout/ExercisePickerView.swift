import SwiftUI
import SwiftData

struct ExercisePickerView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var showingAddCustomExercise = false

    var onSelectExercise: (Exercise) -> Void

    private var filteredExercises: [(String, [Exercise])] {
        let exercisesByCategory = ExerciseDatabase.shared.fetchExercisesByCategory(
            modelContext: modelContext
        )

        if searchText.isEmpty {
            return exercisesByCategory
        }

        let searchResults = ExerciseDatabase.shared.searchExercises(
            query: searchText,
            modelContext: modelContext
        )

        let grouped = Dictionary(grouping: searchResults) { $0.category }
        return grouped.map { ($0.key, $0.value.sorted { $0.displayName < $1.displayName }) }
            .sorted { $0.0 < $1.0 }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(filteredExercises, id: \.0) { category, exercises in
                    Section(category) {
                        ForEach(exercises) { exercise in
                            Button {
                                onSelectExercise(exercise)
                                dismiss()
                            } label: {
                                ExerciseRow(exercise: exercise)
                            }
                            .foregroundColor(.marblePrimary)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .searchable(text: $searchText, prompt: "Search exercises")
            .navigationTitle("Add Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAddCustomExercise = true
                    } label: {
                        Image(systemName: "plus")
                            .fontWeight(.medium)
                    }
                }
            }
            .sheet(isPresented: $showingAddCustomExercise) {
                AddCustomExerciseView { exercise in
                    onSelectExercise(exercise)
                    dismiss()
                }
            }
        }
    }
}

struct ExerciseRow: View {
    let exercise: Exercise

    var body: some View {
        VStack(alignment: .leading, spacing: MarbleSpacing.xxxs) {
            Text(exercise.name)
                .font(.marbleBody)
                .foregroundColor(.marblePrimary)

            HStack(spacing: MarbleSpacing.xxxs) {
                Text(exercise.equipment.uppercased())
                    .font(.marbleDataLabel)
                    .foregroundColor(.marbleSecondary)

                if !exercise.muscleGroups.isEmpty {
                    Text("•")
                        .foregroundColor(.marbleSecondary)
                        .font(.marbleCaption)

                    Text(exercise.muscleGroups.prefix(2).joined(separator: ", "))
                        .font(.marbleCaption)
                        .foregroundColor(.marbleSecondary)
                }
            }
        }
        .padding(.vertical, MarbleSpacing.xxxs)
    }
}

struct AddCustomExerciseView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var selectedEquipment = "Barbell"
    @State private var selectedCategory = "Chest"

    var onSave: (Exercise) -> Void

    let equipmentOptions = ["Barbell", "Dumbbell", "Machine", "Cable", "Bodyweight", "Other"]
    let categoryOptions = ["Chest", "Back", "Shoulders", "Arms", "Legs", "Core", "Cardio"]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Exercise name", text: $name)
                }

                Section("Equipment") {
                    Picker("Equipment", selection: $selectedEquipment) {
                        ForEach(equipmentOptions, id: \.self) { equipment in
                            Text(equipment).tag(equipment)
                        }
                    }
                    .pickerStyle(.menu)
                }

                Section("Category") {
                    Picker("Category", selection: $selectedCategory) {
                        ForEach(categoryOptions, id: \.self) { category in
                            Text(category).tag(category)
                        }
                    }
                    .pickerStyle(.menu)
                }

                Section {
                    Text("Display name:")
                        .font(.marbleCaption)
                        .foregroundColor(.marbleSecondary)

                    Text("\(name.isEmpty ? "Exercise Name" : name) (\(selectedEquipment))")
                        .font(.marbleBody)
                        .foregroundColor(.marblePrimary)
                }
            }
            .navigationTitle("Custom Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let exercise = ExerciseDatabase.shared.createCustomExercise(
                            name: name,
                            equipment: selectedEquipment,
                            category: selectedCategory,
                            muscleGroups: [],
                            modelContext: modelContext
                        )
                        onSave(exercise)
                        dismiss()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }
}

#Preview {
    ExercisePickerView { _ in }
        .modelContainer(for: [Exercise.self])
}
