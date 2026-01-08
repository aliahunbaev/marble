import SwiftUI
import SwiftData

struct AddWorkoutView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var exerciseName = ""
    @State private var notes = ""
    @State private var date = Date()
    @State private var sets: [SetData] = [SetData()]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("Date", selection: $date, displayedComponents: [.date, .hourAndMinute])

                    TextField("Exercise name", text: $exerciseName)
                }

                Section("Sets") {
                    ForEach(sets.indices, id: \.self) { index in
                        HStack(spacing: 12) {
                            Text("\(index + 1)")
                                .foregroundStyle(.secondary)
                                .frame(width: 20)

                            TextField("Reps", text: $sets[index].reps)
                                .keyboardType(.numberPad)
                                .textFieldStyle(.roundedBorder)

                            Text("×")
                                .foregroundStyle(.secondary)

                            HStack(spacing: 4) {
                                TextField("Weight", text: $sets[index].weight)
                                    .keyboardType(.decimalPad)
                                    .textFieldStyle(.roundedBorder)
                                Text("lbs")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .onDelete(perform: deleteSets)

                    Button {
                        sets.append(SetData())
                    } label: {
                        Label("Add set", systemImage: "plus.circle.fill")
                    }
                }

                Section {
                    TextField("Notes (optional)", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("Log workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveWorkout()
                    }
                    .disabled(exerciseName.isEmpty || sets.allSatisfy { $0.reps.isEmpty || $0.weight.isEmpty })
                }
            }
        }
    }

    private func deleteSets(at offsets: IndexSet) {
        sets.remove(atOffsets: offsets)
        if sets.isEmpty {
            sets.append(SetData())
        }
    }

    private func saveWorkout() {
        let workout = WorkoutEntry(
            exerciseName: exerciseName,
            date: date,
            notes: notes.isEmpty ? nil : notes
        )

        for setData in sets {
            if let reps = Int(setData.reps), let weight = Double(setData.weight) {
                let set = ExerciseSet(reps: reps, weight: weight)
                set.workout = workout
                workout.sets.append(set)
            }
        }

        modelContext.insert(workout)
        dismiss()
    }
}

struct SetData {
    var reps: String = ""
    var weight: String = ""
}

#Preview {
    AddWorkoutView()
        .modelContainer(for: [WorkoutEntry.self, ExerciseSet.self])
}
