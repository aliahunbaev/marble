import SwiftUI

struct TemplateCardView: View {
    let template: WorkoutTemplate

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(template.name)
                .font(.system(size: 16, weight: .medium, design: .monospaced))
                .foregroundStyle(Color(.label))
                .lineLimit(2)

            VStack(alignment: .leading, spacing: 3) {
                ForEach(template.exercises.prefix(5)) { exercise in
                    Text(exercise.name)
                        .font(.system(size: 12, weight: .regular, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                if template.exercises.count > 5 {
                    Text("...")
                        .font(.system(size: 12, weight: .regular, design: .monospaced))
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(14)
        .background(Color(.systemBackground))
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(Color(.separator), lineWidth: 1)
        )
    }
}

#Preview {
    let exercises = [
        Exercise(name: "Bench Press", muscleGroup: "Chest"),
        Exercise(name: "Incline Bench", muscleGroup: "Chest"),
        Exercise(name: "Shoulder Press", muscleGroup: "Shoulders"),
        Exercise(name: "Lateral Raise", muscleGroup: "Shoulders"),
    ]
    let template = WorkoutTemplate(name: "Push", exercises: exercises)

    TemplateCardView(template: template)
        .frame(width: 180)
        .padding()
}
