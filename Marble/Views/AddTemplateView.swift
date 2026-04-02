import SwiftUI
import SwiftData

struct AddTemplateView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var selectedExercises: [Exercise] = []
    @State private var showingLibrary = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Template name
                    VStack(alignment: .leading, spacing: 8) {
                        SectionHeader(title: "NAME")
                        TextField("e.g. Push, Pull, Legs", text: $name)
                            .font(.system(.body, design: .monospaced))
                            .padding(14)
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(Color(.separator), lineWidth: 1)
                            )
                    }

                    // Selected exercises
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            SectionHeader(title: "EXERCISES")
                            Spacer()
                            Button {
                                showingLibrary = true
                            } label: {
                                Image(systemName: "plus")
                                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                                    .frame(width: 28, height: 28)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 4)
                                            .stroke(Color(.label), lineWidth: 1)
                                    )
                            }
                            .buttonStyle(.plain)
                        }

                        if selectedExercises.isEmpty {
                            Text("Tap + to add exercises")
                                .font(.system(.subheadline, design: .monospaced))
                                .foregroundStyle(.tertiary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 24)
                        } else {
                            VStack(spacing: 0) {
                                ForEach(Array(selectedExercises.enumerated()), id: \.element.id) { index, exercise in
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(exercise.name)
                                                .font(.system(.body, design: .monospaced))
                                            Text(exercise.muscleGroup)
                                                .font(.system(.caption, design: .monospaced))
                                                .foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                        Button {
                                            selectedExercises.remove(at: index)
                                        } label: {
                                            Image(systemName: "xmark")
                                                .font(.system(size: 12, weight: .medium))
                                                .foregroundStyle(.secondary)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                    .padding(14)

                                    if index < selectedExercises.count - 1 {
                                        Divider()
                                    }
                                }
                            }
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(Color(.separator), lineWidth: 1)
                            )
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
            }
            .navigationTitle("New Program")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .font(.system(.body, design: .monospaced))
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .font(.system(.body, design: .monospaced))
                        .fontWeight(.medium)
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .sheet(isPresented: $showingLibrary) {
                ExerciseLibraryView(selectedExercises: selectedExercises) { exercise in
                    toggleExercise(exercise)
                }
            }
        }
    }

    private func toggleExercise(_ exercise: Exercise) {
        if let index = selectedExercises.firstIndex(where: { $0.id == exercise.id }) {
            selectedExercises.remove(at: index)
        } else {
            selectedExercises.append(exercise)
        }
    }

    private func save() {
        let template = WorkoutTemplate(name: name.trimmingCharacters(in: .whitespaces), exercises: selectedExercises)
        modelContext.insert(template)
        dismiss()
    }
}

#Preview {
    AddTemplateView()
        .modelContainer(for: [WorkoutTemplate.self, Exercise.self], inMemory: true)
}
