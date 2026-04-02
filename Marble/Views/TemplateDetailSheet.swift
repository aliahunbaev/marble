import SwiftUI

struct TemplateDetailSheet: View {
    let template: WorkoutTemplate
    let onStartWorkout: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 0) {
                // Template name
                Text(template.name)
                    .font(.system(size: 28, weight: .medium, design: .monospaced))
                    .padding(.top, 24)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 20)

                // Exercise list
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(Array(template.exercises.enumerated()), id: \.element.id) { index, exercise in
                            HStack {
                                Text(exercise.name)
                                    .font(.system(.body, design: .monospaced))
                                Spacer()
                                Text(exercise.muscleGroup)
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal, 24)
                            .padding(.vertical, 14)

                            if index < template.exercises.count - 1 {
                                Divider()
                                    .padding(.leading, 24)
                            }
                        }
                    }
                }

                // Start Workout button
                Button {
                    onStartWorkout()
                } label: {
                    Text("Start Workout")
                        .font(.system(.title3, design: .monospaced))
                        .fontWeight(.medium)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color(.label))
                        .foregroundStyle(Color(.systemBackground))
                        .cornerRadius(4)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
                .padding(.top, 12)
            }

            // Close button
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 28, height: 28)
                    .background(Color(.tertiarySystemFill))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .padding(.top, 16)
            .padding(.trailing, 16)
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.hidden)
        .presentationCornerRadius(12)
        .presentationBackground(.regularMaterial)
    }
}

#Preview {
    Text("Background")
        .sheet(isPresented: .constant(true)) {
            TemplateDetailSheet(
                template: WorkoutTemplate(
                    name: "Push",
                    exercises: [
                        Exercise(name: "Bench Press", muscleGroup: "Chest"),
                        Exercise(name: "Incline Bench Press", muscleGroup: "Chest"),
                        Exercise(name: "Overhead Press", muscleGroup: "Shoulders"),
                        Exercise(name: "Lateral Raise", muscleGroup: "Shoulders"),
                        Exercise(name: "Tricep Pushdown", muscleGroup: "Arms"),
                    ]
                ),
                onStartWorkout: {}
            )
        }
}
