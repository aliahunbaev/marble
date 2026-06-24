import SwiftUI
import SwiftData

// MARK: - Editing State (shared with ActiveWorkoutView)

struct EditableSet: Identifiable, Codable {
    var id: UUID = UUID()
    var weight: String = ""
    var reps: String = ""
    var isCompleted: Bool = false
}

struct ExerciseEntry: Identifiable {
    var id: UUID = UUID()
    let exercise: Exercise
    var sets: [EditableSet]
}

// MARK: - Template Editor
//
// Shares ActiveWorkoutView's editing stack exactly: BackedScrollView +
// ReorderableList + ExerciseCell, so reorder (drag-anchor + auto-
// scroll), add/replace exercise, +SET, and swipe-to-delete all behave
// identically across the two surfaces.
//
// What's different from ActiveWorkoutView:
//   - No timer / rest timer / mini-bar (templates aren't "live")
//   - SAVE replaces FINISH (no completed-set gate)
//   - Cells render in `structural` mode: set rows show only the set
//     number — no weight/reps fields, no checkmark, no previous ghost.
//
// Templates are structural: they persist `name + exercises + order +
// setCounts`. The actual weights/reps come from previous performance,
// surfaced live in the workout — never frozen into the template.

struct TemplateEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var entries: [ExerciseEntry]
    @State private var showingLibrary = false
    /// When set, the next exercise picked from the library replaces this
    /// entry instead of being appended. Cleared after a successful
    /// replace. Same pattern as ActiveWorkoutView.
    @State private var replacingEntryID: UUID?

    /// Used to assign a sensible displayOrder for fresh templates so
    /// they land at the end of the Train list instead of at index 0
    /// (where they'd collide with every other unset template). Bound
    /// via @Query so the count is always live.
    @Query(sort: \WorkoutTemplate.displayOrder) private var allTemplates: [WorkoutTemplate]

    /// Shared collapse state across all exercise cells. Same pattern
    /// as ActiveWorkoutView — cells compact synchronously when drag
    /// starts so UCV's snapshot is small, animate back on release.
    @StateObject private var reorderState = ExerciseReorderState()

    private let existingTemplate: WorkoutTemplate?

    init(template: WorkoutTemplate? = nil) {
        self.existingTemplate = template
        _name = State(initialValue: template?.name ?? "")
        // Use the order-of-truth helper so reorders done in a previous
        // edit session land in the correct sequence here. The raw
        // `template.exercises` relationship doesn't reliably preserve
        // order across saves — see WorkoutTemplate for the rationale.
        let ordered = template?.orderedExercisesWithSetCounts() ?? []
        _entries = State(initialValue: ordered.map { pair in
            ExerciseEntry(
                exercise: pair.exercise,
                sets: (0..<pair.setCount).map { _ in EditableSet() }
            )
        })
    }

    var body: some View {
        ZStack(alignment: .top) {
            unifiedCanvas

            floatingToolbar
        }
        .background(Color("marbleBackground"))
        .marbleKeyboardDismiss()
        .sheet(isPresented: $showingLibrary, onDismiss: {
            replacingEntryID = nil
        }) {
            let replacingName: String? = {
                guard let id = replacingEntryID,
                      let entry = entries.first(where: { $0.id == id })
                else { return nil }
                return entry.exercise.name
            }()
            ExerciseLibraryView(
                onPick: { picked in
                    if let replaceID = replacingEntryID, let exercise = picked.first {
                        if let idx = entries.firstIndex(where: { $0.id == replaceID }) {
                            let preservedSets = entries[idx].sets
                            entries[idx] = ExerciseEntry(
                                exercise: exercise,
                                sets: preservedSets
                            )
                        }
                    } else {
                        for exercise in picked {
                            let entry = ExerciseEntry(exercise: exercise, sets: [
                                EditableSet(), EditableSet(), EditableSet()
                            ])
                            entries.append(entry)
                        }
                    }
                },
                replacingExerciseName: replacingName
            )
        }
    }

    /// Single canvas — template name + reorderable exercise list +
    /// add-exercise row. Each exercise cell observes `reorderState`
    /// and renders expanded or compact in place. Same architecture
    /// as ActiveWorkoutView's unifiedCanvas; the only difference is
    /// the header is template name (no duration) and cells hide
    /// the checkmark column (templates have no completed concept).
    @ViewBuilder
    private var unifiedCanvas: some View {
        // UIKit-backed scroll view — same as ActiveWorkoutView, so the
        // ReorderableList bridge can anchor the dragged cell at the
        // touch point and auto-scroll. SwiftUI's ScrollView reverts the
        // bridge's contentInset writes within a runloop tick, which is
        // why the template editor's reorder felt different from the
        // workout's. See BackedScrollView.swift.
        BackedScrollView {
            VStack(alignment: .leading, spacing: 0) {
                TextField("Template", text: $name)
                    .font(.marbleBody(32))
                    .foregroundStyle(Color("marblePrimary"))
                    .padding(.horizontal, 20)
                    .padding(.top, 88)
                    .padding(.bottom, 32)

                ReorderableList(
                    items: entries,
                    itemID: { $0.id.uuidString },
                    onReorder: { newOrder in entries = newOrder },
                    onTap: nil,
                    onDragStart: {
                        // Animate the collapse so cells flow into
                        // title-only, matching ActiveWorkoutView.
                        withAnimation(.spring(response: 0.26, dampingFraction: 0.86)) {
                            reorderState.isReordering = true
                        }
                    },
                    onDragEnd: {
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) {
                            reorderState.isReordering = false
                        }
                    },
                    reconfigureKey: AnyHashable(
                        "\(reorderState.isReordering)|" +
                        entries.map { e in
                            "\(e.id):\(e.sets.map { $0.id.uuidString }.joined(separator: ","))"
                        }.joined(separator: ";")
                    )
                ) { entry in
                    ExerciseCell(
                        entry: entry,
                        entries: $entries,
                        reorderState: reorderState,
                        onReplace: { entryID in
                            replacingEntryID = entryID
                            showingLibrary = true
                        },
                        onComplete: nil,
                        showCheckmark: false,
                        structural: true
                    )
                }

                Button {
                    showingLibrary = true
                } label: {
                    HStack(spacing: 6) {
                        Text("+")
                        Text("EXERCISE").tracking(1)
                    }
                    .marbleSecondaryButton()
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 20)
                .padding(.top, 24)
            }
            .padding(.bottom, 140)
        }
        .background(Color("marbleBackground"))
    }

    // MARK: - Floating Toolbar

    private var floatingToolbar: some View {
        normalToolbar
    }

    private var normalToolbar: some View {
        HStack(spacing: 10) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .regular))
                    .marbleGlassCapsule(size: 44)
            }
            .buttonStyle(.plain)

            Spacer()

            // No template-level ⋯ menu — Reorder is triggered via
            // long-press on an exercise name, and there's no Discard
            // for a template (dismiss == undo for an unsaved one,
            // SAVE is what commits).

            // SAVE — glass pill, mirrors FINISH on ActiveWorkoutView so
            // both commits look like the same gesture. Disabled when the
            // template name is empty.
            Button {
                save()
            } label: {
                Text("SAVE")
                    .marbleGlassPill()
            }
            .buttonStyle(.plain)
            .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            .opacity(name.trimmingCharacters(in: .whitespaces).isEmpty ? 0.4 : 1)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }


    // MARK: - Save

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.success)

        let exercises = entries.map(\.exercise)
        // Per-exercise set count, index-aligned with exerciseNames.
        let setCounts = entries.map { $0.sets.count }

        if let existing = existingTemplate {
            existing.name = trimmedName
            // Two-property write:
            //   * `exercises` is the SwiftData relationship — drives
            //     cardinality + delete semantics. Cardinality changes
            //     (add/remove) persist via this property.
            //   * `exerciseNames` is the order-of-truth. Plain stored
            //     `[String]`, so reorders persist reliably (unlike the
            //     relationship, which silently coalesces pure-reorder
            //     writes when the related set is unchanged).
            // Reading: `template.orderedExercises()` resolves names →
            // exercise refs in the saved order.
            existing.exercises = exercises
            existing.exerciseNames = exercises.map(\.name)
            existing.setCounts = setCounts
            try? modelContext.save()
            CloudSyncService.shared.uploadTemplate(existing)
        } else {
            let template = WorkoutTemplate(name: trimmedName, exercises: exercises)
            template.exerciseNames = exercises.map(\.name)
            template.setCounts = setCounts
            // Land at the end of the list so the user's existing order
            // isn't disturbed by a new entry.
            template.displayOrder = allTemplates.count
            modelContext.insert(template)
            try? modelContext.save()
            CloudSyncService.shared.uploadTemplate(template)
        }

        dismiss()
    }
}

// MARK: - Set Row (shared between TemplateEditorView and ActiveWorkoutView)

/// One set row in an exercise table. Sculptural rather than spreadsheet —
/// taller height, larger fields, sculpted depressions for inputs, sharper
/// visual distinction between completed and incomplete states. Each row
/// reads as an object instead of a cell.
///
/// LAST column eliminated: previous workout's value lives as ghost-text
/// placeholder inside each input. Tap checkmark with empty fields to
/// auto-accept the suggested values, or type to override.
///
/// Focus state: when a field is being edited, it gets a hairline ring
/// affordance so you can see exactly where you are.
struct SetRowView: View {
    let setNumber: Int
    @Binding var weight: String
    @Binding var reps: String
    @Binding var isCompleted: Bool
    var previousWeight: String? = nil
    var previousReps: String? = nil
    var showCheckmark: Bool = false
    var onComplete: (() -> Void)? = nil
    /// Fires when a previously-completed set is unchecked — lets the
    /// workout cancel a rest timer this set had auto-started.
    var onUncomplete: (() -> Void)? = nil

    @State private var checkScale: CGFloat = 1.0
    @State private var weightInvalid = false
    @State private var repsInvalid = false
    @State private var completionFlash: Bool = false
    @FocusState private var weightFocused: Bool
    @FocusState private var repsFocused: Bool

    private let fieldHeight: CGFloat = 48
    private let fieldWidth: CGFloat = 100
    private let checkSize: CGFloat = 44

    var body: some View {
        HStack(spacing: 14) {
            Text("\(setNumber)")
                .font(.marbleBody(20))
                .foregroundStyle(Color("marblePrimary").opacity(isCompleted ? 0.95 : 0.5))
                .frame(width: 32, height: fieldHeight, alignment: .center)

            Spacer()

            fieldView(
                text: $weight,
                placeholder: previousWeight,
                keyboard: .decimalPad,
                invalid: weightInvalid,
                focused: $weightFocused
            )

            fieldView(
                text: $reps,
                placeholder: previousReps,
                keyboard: .numberPad,
                invalid: repsInvalid,
                focused: $repsFocused
            )

            if showCheckmark {
                Button {
                    handleComplete()
                } label: {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(isCompleted
                                ? Color.clear
                                : Color("marblePrimary").opacity(0.08))
                        Image(systemName: "checkmark")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundStyle(isCompleted
                                ? Color("marblePrimary")
                                : Color("marblePrimary").opacity(0.2))
                    }
                    .frame(width: checkSize, height: checkSize)
                    .scaleEffect(checkScale)
                }
                .buttonStyle(.plain)
            }
        }
        .scaleEffect(completionFlash ? 1.015 : 1.0)
    }

    private func handleComplete() {
        if isCompleted {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(.easeInOut(duration: 0.15)) {
                isCompleted = false
            }
            onUncomplete?()
            return
        }

        let weightTrimmed = weight.trimmingCharacters(in: .whitespaces)
        let repsTrimmed = reps.trimmingCharacters(in: .whitespaces)
        if weightTrimmed.isEmpty, let suggested = previousWeight {
            weight = suggested
        }
        if repsTrimmed.isEmpty, let suggested = previousReps {
            reps = suggested
        }

        let weightEmpty = weight.trimmingCharacters(in: .whitespaces).isEmpty
        let repsEmpty = reps.trimmingCharacters(in: .whitespaces).isEmpty
        if weightEmpty || repsEmpty {
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
            withAnimation(.easeInOut(duration: 0.2)) {
                weightInvalid = weightEmpty
                repsInvalid = repsEmpty
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                withAnimation(.easeInOut(duration: 0.3)) {
                    weightInvalid = false
                    repsInvalid = false
                }
            }
            return
        }

        weightFocused = false
        repsFocused = false
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        withAnimation(.easeInOut(duration: 0.15)) {
            isCompleted = true
        }
        withAnimation(.spring(response: 0.2, dampingFraction: 0.5)) {
            checkScale = 1.2
        }
        withAnimation(.spring(response: 0.25, dampingFraction: 0.55)) {
            completionFlash = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                checkScale = 1.0
                completionFlash = false
            }
        }
        onComplete?()
    }

    private func fieldView(
        text: Binding<String>,
        placeholder: String?,
        keyboard: UIKeyboardType,
        invalid: Bool,
        focused: FocusState<Bool>.Binding
    ) -> some View {
        let placeholderText = Text(placeholder ?? "")
            .foregroundStyle(Color("marblePrimary").opacity(0.25))

        return TextField(text: text, prompt: placeholderText) { EmptyView() }
            .font(.marbleMono(22))
            .foregroundStyle(Color("marblePrimary"))
            .multilineTextAlignment(.center)
            .keyboardType(keyboard)
            .focused(focused)
            .frame(width: fieldWidth, height: fieldHeight)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(backgroundColor(invalid: invalid))
                    if !isCompleted {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(
                                Color("marblePrimary").opacity(0.12),
                                lineWidth: 1
                            )
                            .blur(radius: 1)
                            .mask(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(
                                        LinearGradient(
                                            colors: [.black, .clear],
                                            startPoint: .top,
                                            endPoint: .center
                                        )
                                    )
                            )
                    }
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(
                        focused.wrappedValue
                            ? Color("marblePrimary").opacity(0.4)
                            : Color.clear,
                        lineWidth: 1
                    )
                    .animation(.easeInOut(duration: 0.15), value: focused.wrappedValue)
            )
    }

    private func backgroundColor(invalid: Bool) -> Color {
        if invalid {
            return Color.red.opacity(0.18)
        }
        if isCompleted {
            return .clear
        }
        return Color("marblePrimary").opacity(0.10)
    }
}

#Preview {
    TemplateEditorView()
        .modelContainer(for: [WorkoutTemplate.self, Exercise.self], inMemory: true)
}
