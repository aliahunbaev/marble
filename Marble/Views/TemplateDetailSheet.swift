import SwiftUI

struct TemplateDetailSheet: View {
    let template: WorkoutTemplate
    let onStartWorkout: () -> Void
    /// Edit / Duplicate / Delete callbacks bubble back to TrainView,
    /// which owns the editor cover state + the model context delete
    /// path. All three optional so the preview / tests can omit them.
    var onEdit: (() -> Void)? = nil
    var onDuplicate: (() -> Void)? = nil
    var onDelete: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var showingDeleteConfirmation = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 0) {
                // Template name
                Text(template.name)
                    .font(.marbleBody(26))
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

            // Top-right chrome: ⋯ menu (Edit / Duplicate / Delete) +
            // close X. Lives on the sheet now rather than the row's
            // long-press context menu so the row can own long-press
            // for drag-reorder.
            HStack(spacing: 8) {
                if onEdit != nil || onDuplicate != nil || onDelete != nil {
                    Menu {
                        if let onEdit {
                            Button { onEdit() } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                        }
                        if let onDuplicate {
                            Button { onDuplicate() } label: {
                                Label("Duplicate", systemImage: "doc.on.doc")
                            }
                        }
                        if onDelete != nil {
                            Button(role: .destructive) {
                                showingDeleteConfirmation = true
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 13, weight: .medium))
                            .marbleGlassCapsule(size: 32)
                    }
                    .buttonStyle(.plain)
                }

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .regular))
                        .marbleGlassCapsule(size: 32)
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 16)
            .padding(.trailing, 16)
        }
        .marbleDialog(
            "Delete this program?",
            message: "This cannot be undone.",
            isPresented: $showingDeleteConfirmation,
            buttons: [
                .destructive("Delete") { onDelete?() },
                .cancel(),
            ]
        )
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
