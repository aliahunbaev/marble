import SwiftUI
import SwiftData

// MARK: - Editing State (shared with ActiveWorkoutView)

struct EditableSet: Identifiable {
    let id = UUID()
    var weight: String = ""
    var reps: String = ""
    var isCompleted: Bool = false
}

struct ExerciseEntry: Identifiable {
    let id = UUID()
    let exercise: Exercise
    var sets: [EditableSet]
}

// MARK: - Template Editor
//
// Mirrors ActiveWorkoutView's architecture so the two surfaces feel
// like the same canvas. Same native List structure, same flat row
// layout (no Sections — exercise headers scroll naturally), same
// `.swipeActions` per-set delete, same menu-driven reorder pattern,
// same floating glass toolbar.
//
// What's different from ActiveWorkoutView:
//   - No timer / rest timer / mini-bar (templates aren't "live")
//   - SAVE replaces FINISH (no completed-set gate)
//   - Workout-level menu only has Reorder (no Discard — dismiss == undo)
//
// Template data model only persists `name + exercises`. The set rows
// shown in the editor are demonstrational — values aren't saved.

struct TemplateEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var entries: [ExerciseEntry]
    @State private var showingLibrary = false
    @State private var isReordering: Bool = false
    /// When set, the next exercise picked from the library replaces this
    /// entry instead of being appended. Cleared after a successful
    /// replace. Same pattern as ActiveWorkoutView.
    @State private var replacingEntryID: UUID?

    /// Used to assign a sensible displayOrder for fresh templates so
    /// they land at the end of the Train list instead of at index 0
    /// (where they'd collide with every other unset template). Bound
    /// via @Query so the count is always live.
    @Query(sort: \WorkoutTemplate.displayOrder) private var allTemplates: [WorkoutTemplate]

    private let existingTemplate: WorkoutTemplate?

    init(template: WorkoutTemplate? = nil) {
        self.existingTemplate = template
        _name = State(initialValue: template?.name ?? "")
        // Use the order-of-truth helper so reorders done in a previous
        // edit session land in the correct sequence here. The raw
        // `template.exercises` relationship doesn't reliably preserve
        // order across saves — see WorkoutTemplate for the rationale.
        let ordered = template?.orderedExercises() ?? []
        _entries = State(initialValue: ordered.map { exercise in
            ExerciseEntry(exercise: exercise, sets: [
                EditableSet(), EditableSet(), EditableSet()
            ])
        })
    }

    var body: some View {
        ZStack(alignment: .top) {
            if isReordering {
                reorderingCanvas
            } else {
                expandedCanvas
            }

            floatingToolbar
        }
        .background(Color("marbleBackground"))
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

    // MARK: - List Rows

    /// Template name field as the first list row. Extra top padding
    /// gives breathing room below the floating toolbar.
    private var templateHeaderRow: some View {
        // Top padding clears the floating toolbar (8pt offset + 44pt
        // button = 52pt bottom edge) with 36pt of breathing room
        // beneath. A title pressed against the toolbar reads as
        // crowded; this restores the editorial generosity.
        TextField("Template", text: $name)
            .font(.marbleBody(32))
            .foregroundStyle(Color("marblePrimary"))
            .padding(.horizontal, 20)
            .padding(.top, 88)
            .padding(.bottom, 32)
            .listRowInsets(EdgeInsets())
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
    }

    private var exerciseDividerRow: some View {
        Rectangle()
            .fill(Color("marblePrimary").opacity(0.06))
            .frame(height: 0.5)
            .listRowInsets(EdgeInsets(top: 20, leading: 20, bottom: 20, trailing: 20))
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
    }

    @ViewBuilder
    private var expandedExercisesContent: some View {
        ForEach(Array($entries.enumerated()), id: \.element.id) { index, $entry in
            if index > 0 {
                exerciseDividerRow
            }
            exerciseHeaderRow(entry: $entry)
            ForEach($entry.sets) { $set in
                setRowItem(entry: $entry, set: $set)
            }
            addSetRow(entry: $entry)
        }
    }

    /// Normal mode — full List with expanded exercises, swipe-to-
    /// delete on sets, +SET buttons, the whole template-editing UX.
    @ViewBuilder
    private var expandedCanvas: some View {
        List {
            templateHeaderRow
            expandedExercisesContent
            addExerciseRow
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .environment(\.defaultMinListRowHeight, 0)
        .background(Color("marbleBackground"))
    }

    /// Reorder mode — exercises collapse to title rows in a
    /// `ReorderableList` (UICollectionView bridge). Same iOS-native
    /// long-press → lift → drag → reflow → snap UX as Train templates
    /// and Track metrics. Exit via DONE in the toolbar.
    @ViewBuilder
    private var reorderingCanvas: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text(name.isEmpty ? "Template" : name)
                    .font(.marbleBody(32))
                    .foregroundStyle(Color("marblePrimary"))
                    .padding(.horizontal, 20)
                    .padding(.top, 88)
                    .padding(.bottom, 24)

                ReorderableList(
                    items: entries,
                    itemID: { $0.id.uuidString },
                    onReorder: { newOrder in entries = newOrder },
                    onTap: nil
                ) { entry in
                    Text(entry.exercise.name)
                        .font(.marbleBody(22))
                        .foregroundStyle(Color("marblePrimary"))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 18)
                        .background(
                            VStack {
                                Spacer()
                                Rectangle()
                                    .fill(Color("marblePrimary").opacity(0.08))
                                    .frame(height: 0.5)
                            }
                        )
                }
            }
            .padding(.bottom, 140)
        }
        .background(Color("marbleBackground"))
    }

    /// Exercise header — name + ⋯ menu (Replace / Remove). Same ID-
    /// capture pattern as ActiveWorkoutView to avoid the Binding-into-
    /// closure footgun (binding becomes invalid the moment the entries
    /// array mutates → crash).
    @ViewBuilder
    private func exerciseHeaderRow(entry: Binding<ExerciseEntry>) -> some View {
        let entryID = entry.wrappedValue.id
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(entry.wrappedValue.exercise.name)
                    .font(.marbleBody(22))
                    .foregroundStyle(Color("marblePrimary"))
                    // Long-press the name to enter reorder mode
                    // directly — no dedicated "Reorder" menu button.
                    .gesture(
                        LongPressGesture(minimumDuration: 0.4)
                            .onEnded { _ in
                                guard entries.count >= 2 else { return }
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                                    isReordering = true
                                }
                            }
                    )

                Spacer()

                Menu {
                    Button {
                        DispatchQueue.main.async {
                            replacingEntryID = entryID
                            showingLibrary = true
                        }
                    } label: {
                        Label("Replace exercise", systemImage: "arrow.triangle.2.circlepath")
                    }
                    Button(role: .destructive) {
                        DispatchQueue.main.async {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                entries.removeAll { $0.id == entryID }
                            }
                        }
                    } label: {
                        Label("Remove", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 13, weight: .medium))
                        .marbleGlassCapsule(size: 32)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 14)

            // Column headers — widths track SetRowView field sizes. No
            // checkmark column here since templates don't have a
            // "completed" concept.
            HStack(spacing: 14) {
                Text("SET").frame(width: 32, alignment: .center)
                Spacer()
                Text("LBS").frame(width: 100, alignment: .center)
                Text("REPS").frame(width: 100, alignment: .center)
            }
            .font(.marbleMono(11))
            .tracking(1.5)
            .foregroundStyle(Color("marbleSecondary"))
            .padding(.horizontal, 20)
            .padding(.bottom, 8)
        }
        .listRowInsets(EdgeInsets())
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
    }

    @ViewBuilder
    private func setRowItem(
        entry: Binding<ExerciseEntry>,
        set: Binding<EditableSet>
    ) -> some View {
        let index = entry.wrappedValue.sets.firstIndex(where: { $0.id == set.wrappedValue.id }) ?? 0
        // Ghost-text the previous workout's values per set, same lookup
        // as ActiveWorkoutView. Templates don't *store* prescribed
        // numbers — the editor is structural (exercises + set count +
        // order). The ghost is purely informational: "here's what you
        // last lifted on this exercise" so the user can shape the
        // template knowing where they're starting from.
        let prev = PreviousPerformance.previousComponents(
            for: entry.wrappedValue.exercise,
            setIndex: index,
            context: modelContext
        )

        SetRowView(
            setNumber: index + 1,
            weight: set.weight,
            reps: set.reps,
            isCompleted: set.isCompleted,
            previousWeight: prev.weight,
            previousReps: prev.reps,
            showCheckmark: false,
            onComplete: nil
        )
        .listRowInsets(EdgeInsets(top: 10, leading: 20, bottom: 10, trailing: 20))
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    entry.wrappedValue.sets.removeAll { $0.id == set.wrappedValue.id }
                }
            } label: {
                Text("Delete")
            }
        }
    }

    /// + SET row at the end of each exercise's set list.
    private func addSetRow(entry: Binding<ExerciseEntry>) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(.spring(response: 0.4, dampingFraction: 0.82)) {
                entry.wrappedValue.sets.append(EditableSet())
            }
        } label: {
            HStack(spacing: 6) {
                Text("+")
                Text("SET").tracking(1)
            }
            .marbleSecondaryButton()
        }
        .buttonStyle(.plain)
        .listRowInsets(EdgeInsets(top: 12, leading: 20, bottom: 8, trailing: 20))
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
    }

    private var addExerciseRow: some View {
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
        .listRowInsets(EdgeInsets(top: 24, leading: 20, bottom: 120, trailing: 20))
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
    }

    // MARK: - Floating Toolbar

    @ViewBuilder
    private var floatingToolbar: some View {
        if isReordering {
            reorderingToolbar
        } else {
            normalToolbar
        }
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

    private var reorderingToolbar: some View {
        HStack {
            Spacer()
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                    isReordering = false
                }
            } label: {
                Text("DONE")
                    .marbleGlassPill()
            }
            .buttonStyle(.plain)
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
            try? modelContext.save()
            CloudSyncService.shared.uploadTemplate(existing)
        } else {
            let template = WorkoutTemplate(name: trimmedName, exercises: exercises)
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

    @State private var checkScale: CGFloat = 1.0
    @State private var weightInvalid = false
    @State private var repsInvalid = false
    @State private var completionFlash: Bool = false
    @FocusState private var weightFocused: Bool
    @FocusState private var repsFocused: Bool

    private let fieldHeight: CGFloat = 52
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
