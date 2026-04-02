import SwiftUI

struct TemplateCardView: View {
    let template: WorkoutTemplate

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(template.name)
                .font(.system(size: 16, weight: .medium, design: .default))
                .foregroundStyle(Color("marblePrimary"))
                .lineLimit(2)

            VStack(alignment: .leading, spacing: 3) {
                ForEach(template.exercises.prefix(5)) { exercise in
                    Text(exercise.name)
                        .font(.system(size: 12, weight: .regular, design: .default))
                        .foregroundStyle(Color("marbleSecondary"))
                        .lineLimit(1)
                }
                if template.exercises.count > 5 {
                    Text("...")
                        .font(.system(size: 12, weight: .regular, design: .default))
                        .foregroundStyle(Color("marbleTertiary"))
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(14)
        .background(Color("marbleCard"))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
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
