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
                    .font(.custom("ABC Favorit Variable Unlicensed Trial", size: 26))
                    .fontWeight(.light)
                    .foregroundStyle(Color("marblePrimary"))
                    .padding(.top, 24)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 20)

                // Exercise list
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(Array(template.exercises.enumerated()), id: \.element.id) { index, exercise in
                            HStack {
                                Text(exercise.name)
                                    .font(.custom("ABC Favorit Variable Unlicensed Trial", size: 14))
                                    .fontWeight(.light)
                                    .foregroundStyle(Color("marblePrimary"))
                                Spacer()
                                Text(exercise.muscleGroup)
                                    .font(.custom("ABC Favorit Mono Variable Unlicensed Trial", size: 11))
                                    .fontWeight(.light)
                                    .foregroundStyle(Color("marbleSecondary"))
                            }
                            .padding(.horizontal, 24)
                            .padding(.vertical, 14)

                            if index < template.exercises.count - 1 {
                                Rectangle()
                                    .fill(Color("marblePrimary").opacity(0.06))
                                    .frame(height: 0.5)
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
                        .font(.custom("ABC Favorit Variable Unlicensed Trial", size: 16))
                        .fontWeight(.light)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color("marblePrimary"))
                        .foregroundStyle(Color("marbleBackground"))
                        .clipShape(Capsule())
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
                    .font(.system(size: 11, weight: .light))
                    .foregroundStyle(Color("marbleSecondary"))
                    .frame(width: 30, height: 30)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color("marblePrimary").opacity(0.12), lineWidth: 0.5)
                    )
            }
            .buttonStyle(.plain)
            .padding(.top, 16)
            .padding(.trailing, 16)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.hidden)
        .presentationCornerRadius(12)
        .presentationBackground(Color("marbleBackground"))
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
