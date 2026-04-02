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
                            .font(.system(.body, design: .default))
                            .foregroundStyle(Color("marblePrimary"))
                            .padding(14)
                            .background(Color("marbleFieldBackground"))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
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
                                    .foregroundStyle(Color("marblePrimary"))
                                    .frame(width: 28, height: 28)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color("marblePrimary"), lineWidth: 1)
                                    )
                            }
                            .buttonStyle(.plain)
                        }

                        if selectedExercises.isEmpty {
                            Text("Tap + to add exercises")
                                .font(.system(.subheadline, design: .monospaced))
                                .foregroundStyle(Color("marbleSecondary"))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 24)
                        } else {
                            VStack(spacing: 0) {
                                ForEach(Array(selectedExercises.enumerated()), id: \.element.id) { index, exercise in
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(exercise.name)
                                                .font(.system(.body, design: .default))
                                                .foregroundStyle(Color("marblePrimary"))
                                            Text(exercise.muscleGroup)
                                                .font(.system(.caption, design: .monospaced))
                                                .foregroundStyle(Color("marbleSecondary"))
                                        }
                                        Spacer()
                                        Button {
                                            selectedExercises.remove(at: index)
                                        } label: {
                                            Image(systemName: "xmark")
                                                .font(.system(size: 12, weight: .medium))
                                                .foregroundStyle(Color("marbleSecondary"))
                                        }
                                        .buttonStyle(.plain)
                                    }
                                    .padding(14)

                                    if index < selectedExercises.count - 1 {
                                        Rectangle()
                                            .fill(Color("marbleTertiary"))
                                            .frame(height: 1)
                                    }
                                }
                            }
                            .background(Color("marbleCard"))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
            }
            .background(Color("marbleBackground"))
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
