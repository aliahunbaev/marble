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

                // Exercise list — names only. Muscle group was redundant
                // (the template name already says it); set count is flat
                // (templates default to 3). Names breathe instead.
                ScrollView {
                    VStack(spacing: 0) {
                        let orderedExercises = template.orderedExercises()
                        ForEach(Array(orderedExercises.enumerated()), id: \.element.id) { index, exercise in
                            HStack {
                                Text(exercise.name)
                                    .font(.marbleBody(15))
                                    .foregroundStyle(Color("marblePrimary"))
                                Spacer()
                            }
                            .padding(.horizontal, 24)
                            .padding(.vertical, 16)

                            if index < orderedExercises.count - 1 {
                                Rectangle()
                                    .fill(Color("marblePrimary").opacity(0.06))
                                    .frame(height: 0.5)
                                    .padding(.leading, 24)
                            }
                        }
                    }
                }

                // Start Workout — tinted glass primary, same archetype as
                // FINISH and SAVE so every "go" moment shares language.
                Button {
                    onStartWorkout()
                } label: {
                    Text("Start Workout")
                        .font(.marbleBody(16))
                        .foregroundStyle(Color("marbleBackground"))
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background {
                            if #available(iOS 26.0, *) {
                                Capsule()
                                    .fill(Color.clear)
                                    .glassEffect(.regular.tint(Color("marblePrimary")), in: Capsule())
                            } else {
                                ZStack {
                                    Capsule().fill(.ultraThinMaterial)
                                    Capsule().fill(Color("marblePrimary"))
                                }
                            }
                        }
                        .contentShape(Capsule())
                        .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 2)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
                .padding(.top, 12)
            }

            // Close — glass capsule, same as template editor X
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .regular))
                    .marbleGlassCapsule(size: 32)
            }
            .buttonStyle(.plain)
            .padding(.top, 16)
            .padding(.trailing, 16)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.hidden)
        .presentationCornerRadius(28)
        // On iOS 26+, leaving the presentation background to the system
        // gives us proper Liquid Glass automatically (the sheet itself
        // becomes a Liquid Glass surface). On older iOS we explicitly use
        // .ultraThinMaterial as the closest available equivalent.
        .modifier(SheetGlassBackgroundModifier())
    }
}

/// On iOS 17-25, applies .ultraThinMaterial as the sheet presentation
/// background. On iOS 26+, intentionally does nothing — the system gives
/// sheets Liquid Glass by default, and overriding it with a custom view
/// for .presentationBackground prevents the proper glass treatment.
private struct SheetGlassBackgroundModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
        } else {
            content.presentationBackground(.ultraThinMaterial)
        }
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
