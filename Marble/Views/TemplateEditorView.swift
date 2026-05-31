import SwiftUI
import SwiftData

// MARK: - Editing State

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

struct TemplateEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var entries: [ExerciseEntry]
    @State private var showingLibrary = false
    @State private var draggingEntryID: UUID?
    @State private var lastSwapOffset: CGFloat = 0

    private let existingTemplate: WorkoutTemplate?

    init(template: WorkoutTemplate? = nil) {
        self.existingTemplate = template
        _name = State(initialValue: template?.name ?? "")
        _entries = State(initialValue: template?.exercises.map { exercise in
            ExerciseEntry(exercise: exercise, sets: [
                EditableSet(), EditableSet(), EditableSet()
            ])
        } ?? [])
    }

    var body: some View {
        ZStack(alignment: .top) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    TextField("Template", text: $name)
                        .font(.marbleBody(32))
                        .foregroundStyle(Color("marblePrimary"))
                        .padding(.horizontal, 20)
                        .padding(.top, 64) // breathing room under floating buttons
                        .padding(.bottom, 40)

                    if draggingEntryID != nil {
                        ForEach(entries) { entry in
                            reorderRow(entry: entry)
                        }
                    } else {
                        ForEach($entries) { $entry in
                            ExerciseSetTable(
                                entry: $entry,
                                onRemove: {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        entries.removeAll { $0.id == entry.id }
                                    }
                                },
                                showPrevious: false,
                                dragHandle: true,
                                onDragChanged: { translation in
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        handleDrag(entryID: entry.id, translation: translation)
                                    }
                                },
                                onDragEnded: {
                                    withAnimation(.easeInOut(duration: 0.25)) {
                                        draggingEntryID = nil
                                    }
                                    lastSwapOffset = 0
                                }
                            )
                            exerciseDivider
                        }
                    }

                    addExerciseButton
                        .padding(.top, entries.isEmpty ? 0 : 4)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 40)
                }
            }

            // Floating glass toolbar (matches ActiveWorkoutView)
            floatingToolbar
        }
        .background(Color("marbleBackground"))
        .scrollDismissesKeyboard(.interactively)
        .sheet(isPresented: $showingLibrary) {
            let selectedExercises = entries.map(\.exercise)
            ExerciseLibraryView(selectedExercises: selectedExercises) { exercise in
                toggleExercise(exercise)
            }
        }
    }

    // MARK: - Floating Toolbar (matches ActiveWorkoutView)

    private var floatingToolbar: some View {
        HStack {
            // Close — glass circle, mirrors FloatingRestTimerButton idle state
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .regular))
                    .marbleGlassCapsule(size: 44)
            }
            .buttonStyle(.plain)

            Spacer()

            // SAVE — tinted glass capsule, mirrors the FINISH button
            Button {
                save()
            } label: {
                Text("SAVE")
                    .marbleGlassPrimaryCapsule()
            }
            .buttonStyle(.plain)
            .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            .opacity(name.trimmingCharacters(in: .whitespaces).isEmpty ? 0.3 : 1)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    private var exerciseDivider: some View {
        Rectangle()
            .fill(Color("marblePrimary").opacity(0.06))
            .frame(height: 0.5)
            .padding(.horizontal, 20)
            .padding(.vertical, 20)
    }

    private var addExerciseButton: some View {
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
    }

    private func reorderRow(entry: ExerciseEntry) -> some View {
        HStack {
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 12, weight: .light))
                .foregroundStyle(Color("marbleTertiary"))
                .padding(.trailing, 6)

            Text(entry.exercise.name)
                .font(.marbleBody(16))
                .foregroundStyle(Color("marblePrimary"))

            Spacer()

            Text("\(entry.sets.count) sets")
                .font(.marbleMono(11))
                .foregroundStyle(Color("marbleSecondary"))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(draggingEntryID == entry.id ? Color("marblePrimary").opacity(0.06) : Color.clear)
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    handleDrag(entryID: entry.id, translation: value.translation.height)
                }
                .onEnded { _ in
                    withAnimation(.easeInOut(duration: 0.25)) {
                        draggingEntryID = nil
                    }
                    lastSwapOffset = 0
                }
        )
    }

    private func handleDrag(entryID: UUID, translation: CGFloat) {
        if draggingEntryID == nil {
            draggingEntryID = entryID
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }

        guard let currentIndex = entries.firstIndex(where: { $0.id == entryID }) else { return }
        let delta = translation - lastSwapOffset
        let threshold: CGFloat = 50

        if delta > threshold, currentIndex < entries.count - 1 {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(.easeInOut(duration: 0.2)) {
                entries.move(fromOffsets: IndexSet(integer: currentIndex), toOffset: currentIndex + 2)
            }
            lastSwapOffset = translation
        } else if delta < -threshold, currentIndex > 0 {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(.easeInOut(duration: 0.2)) {
                entries.move(fromOffsets: IndexSet(integer: currentIndex), toOffset: currentIndex - 1)
            }
            lastSwapOffset = translation
        }
    }

    private func toggleExercise(_ exercise: Exercise) {
        if let index = entries.firstIndex(where: { $0.exercise.id == exercise.id }) {
            entries.remove(at: index)
        } else {
            let entry = ExerciseEntry(exercise: exercise, sets: [
                EditableSet(), EditableSet(), EditableSet()
            ])
            entries.append(entry)
        }
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.success)

        let exercises = entries.map(\.exercise)

        if let existing = existingTemplate {
            existing.name = trimmedName
            existing.exercises = exercises
            try? modelContext.save()
            CloudSyncService.shared.uploadTemplate(existing)
        } else {
            let template = WorkoutTemplate(name: trimmedName, exercises: exercises)
            modelContext.insert(template)
            try? modelContext.save()
            CloudSyncService.shared.uploadTemplate(template)
        }

        dismiss()
    }
}

// MARK: - Exercise Set Table (Reusable)

// MARK: - Reorder Gesture (invisible long-press + drag)

/// Attaches a long-press-then-drag reorder gesture to a view, but only when
/// `enabled` is true. Lets the template editor support reorder without a
/// visible drag handle icon — the user just presses-and-holds the exercise
/// name area, then drags.
struct ReorderGestureModifier: ViewModifier {
    let enabled: Bool
    let onChanged: ((CGFloat) -> Void)?
    let onEnded: (() -> Void)?

    func body(content: Content) -> some View {
        if enabled {
            content
                .contentShape(Rectangle())
                .gesture(
                    LongPressGesture(minimumDuration: 0.3)
                        .sequenced(before: DragGesture(minimumDistance: 0))
                        .onChanged { value in
                            if case .second(true, let drag?) = value {
                                onChanged?(drag.translation.height)
                            }
                        }
                        .onEnded { _ in
                            onEnded?()
                        }
                )
        } else {
            content
        }
    }
}

struct ExerciseSetTable: View {
    @Environment(\.modelContext) private var modelContext
    @Binding var entry: ExerciseEntry
    var onRemove: (() -> Void)? = nil
    var showPrevious: Bool = true
    var isWorkoutMode: Bool = false
    var onSetCompleted: (() -> Void)? = nil
    var onStartRestTimer: (() -> Void)? = nil
    var onReplaceExercise: (() -> Void)? = nil
    var dragHandle: Bool = false
    var onDragChanged: ((CGFloat) -> Void)? = nil
    var onDragEnded: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Exercise name header — the name itself is the menu trigger.
            // Standalone ⋯ button removed (cleaner row); "Start rest timer"
            // item dropped (useless — the floating timer button is one tap
            // away, and per-set rest customization would be a real feature
            // beyond just opening the modal).
            HStack {
                if onRemove != nil {
                    Menu {
                        if isWorkoutMode {
                            Button {
                                onReplaceExercise?()
                            } label: {
                                Label("Replace exercise", systemImage: "arrow.triangle.2.circlepath")
                            }
                        }
                        Button(role: .destructive) {
                            onRemove?()
                        } label: {
                            Label("Remove", systemImage: "trash")
                        }
                    } label: {
                        Text(entry.exercise.name)
                            .font(.marbleBody(22))
                            .foregroundStyle(Color("marblePrimary"))
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                } else {
                    Text(entry.exercise.name)
                        .font(.marbleBody(22))
                        .foregroundStyle(Color("marblePrimary"))
                }

                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 14)
            // Invisible reorder gesture — long-press the exercise name area
            // to enter reorder mode, then drag to move. No visible handle.
            // Long-press is distinct from the Menu's tap trigger, so both
            // gestures coexist on the same name.
            .modifier(ReorderGestureModifier(
                enabled: dragHandle,
                onChanged: onDragChanged,
                onEnded: onDragEnded
            ))

            // Column headers
            columnHeaders
                .padding(.horizontal, 20)
                .padding(.bottom, 8)

            // Set rows
            ForEach($entry.sets) { $set in
                let index = entry.sets.firstIndex(where: { $0.id == set.id }) ?? 0
                let prev: (weight: String?, reps: String?) = showPrevious
                    ? PreviousPerformance.previousComponents(
                        for: entry.exercise,
                        setIndex: index,
                        context: modelContext
                    )
                    : (nil, nil)
                SwipeToDeleteRow {
                    SetRowView(
                        setNumber: index + 1,
                        weight: $set.weight,
                        reps: $set.reps,
                        isCompleted: $set.isCompleted,
                        previousWeight: prev.weight,
                        previousReps: prev.reps,
                        showCheckmark: isWorkoutMode,
                        onComplete: onSetCompleted
                    )
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    // No row background tint for completed sets. State is
                    // already conveyed by: bright checkmark, opaque set
                    // number, clean (no-tint) fields. The green wash was
                    // extra signal that read as "highlighted spreadsheet
                    // row" — completed sets now read as settled and clean.
                } onDelete: {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    withAnimation(.easeInOut(duration: 0.2)) {
                        entry.sets.removeAll { $0.id == set.id }
                    }
                }
            }

            // + SET button
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                entry.sets.append(EditableSet())
            } label: {
                HStack(spacing: 6) {
                    Text("+")
                    Text("SET").tracking(1)
                }
                .marbleSecondaryButton()
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 20)
            .padding(.top, 8)
        }
    }

    private var columnHeaders: some View {
        // LAST column dropped — previous values live as ghost-text inside
        // the LBS and REPS fields. Header widths track SetRowView field
        // sizes (32 set num / flexible spacer / 100 / 100 / 44 check).
        HStack(spacing: 14) {
            Text("SET")
                .frame(width: 32, alignment: .center)
            Spacer()
            Text("LBS")
                .frame(width: 100, alignment: .center)
            Text("REPS")
                .frame(width: 100, alignment: .center)
            if isWorkoutMode {
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .light))
                    .frame(width: 44, alignment: .center)
            }
        }
        .font(.marbleMono(11))
        .tracking(1.5)
        .foregroundStyle(Color("marbleSecondary"))
    }
}

// MARK: - Set Row

/// One set row in an exercise table. Sculptural rather than spreadsheet —
/// taller height, larger fields, sculpted depressions for inputs, sharper
/// visual distinction between completed and incomplete states. Each row
/// reads as an object instead of a cell.
///
/// LAST column eliminated: previous workout's value now lives as ghost-
/// text placeholder inside each input. Tap checkmark with empty fields
/// to auto-accept the suggested values, or type to override.
///
/// Focus state: when a field is being edited, it gets a hairline ring
/// affordance so you can see exactly where you are.
struct SetRowView: View {
    let setNumber: Int
    @Binding var weight: String
    @Binding var reps: String
    @Binding var isCompleted: Bool
    /// Previous workout's weight for this set index, as a string. Shown
    /// as ghost placeholder in the LBS field when the user hasn't typed
    /// anything yet. Auto-fills on checkmark if the field is empty.
    var previousWeight: String? = nil
    /// Previous workout's reps for this set index, as a string. Same
    /// ghost-placeholder + auto-fill behavior as previousWeight.
    var previousReps: String? = nil
    var showCheckmark: Bool = false
    var onComplete: (() -> Void)? = nil

    @State private var checkScale: CGFloat = 1.0
    @State private var weightInvalid = false
    @State private var repsInvalid = false
    /// Brief scale flash on completion — felt micro-settle.
    @State private var completionFlash: Bool = false
    /// Shimmer sweep position. -1.5 = off-screen left, 1.5 = off-screen
    /// right. Animated on completion to sweep a soft light gradient
    /// across the row, like polished marble briefly catching light.
    @State private var shimmerProgress: CGFloat = -1.5
    @FocusState private var weightFocused: Bool
    @FocusState private var repsFocused: Bool

    private let fieldHeight: CGFloat = 52
    private let fieldWidth: CGFloat = 100
    private let checkSize: CGFloat = 44

    var body: some View {
        HStack(spacing: 14) {
            // Set number — larger, body type for tactile weight
            Text("\(setNumber)")
                .font(.marbleBody(20))
                .foregroundStyle(Color("marblePrimary").opacity(isCompleted ? 0.95 : 0.5))
                .frame(width: 32, height: fieldHeight, alignment: .center)

            Spacer()

            // Weight — previous value lives inside as ghost placeholder
            fieldView(
                text: $weight,
                placeholder: previousWeight,
                keyboard: .decimalPad,
                invalid: weightInvalid,
                focused: $weightFocused
            )

            // Reps — same ghost-placeholder treatment
            fieldView(
                text: $reps,
                placeholder: previousReps,
                keyboard: .numberPad,
                invalid: repsInvalid,
                focused: $repsFocused
            )

            // Checkmark — bigger tap target, sharper contrast between states
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
        // Shimmer sweep — soft gradient passes across the row on
        // completion. Polished marble catching light. Restrained
        // (low opacity) and brief (~0.6s total) so it stays editorial,
        // not gamified.
        .overlay(
            GeometryReader { geo in
                LinearGradient(
                    colors: [
                        .clear,
                        Color("marblePrimary").opacity(0.18),
                        .clear
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: geo.size.width * 0.5)
                .offset(x: shimmerProgress * geo.size.width)
                .allowsHitTesting(false)
            }
            .mask(Rectangle())
            .allowsHitTesting(false)
        )
    }

    private func handleComplete() {
        if isCompleted {
            // Toggle off — always allowed
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(.easeInOut(duration: 0.15)) {
                isCompleted = false
            }
            return
        }

        // Auto-fill from ghost placeholders before validating. If the user
        // tapped checkmark with empty fields but there's a previous value
        // suggested in the placeholder, accept it as the value.
        let weightTrimmed = weight.trimmingCharacters(in: .whitespaces)
        let repsTrimmed = reps.trimmingCharacters(in: .whitespaces)
        if weightTrimmed.isEmpty, let suggested = previousWeight {
            weight = suggested
        }
        if repsTrimmed.isEmpty, let suggested = previousReps {
            reps = suggested
        }

        // Re-validate after auto-fill
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

        // Complete — dismiss keyboard so the next set is reachable
        weightFocused = false
        repsFocused = false
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        withAnimation(.easeInOut(duration: 0.15)) {
            isCompleted = true
        }
        withAnimation(.spring(response: 0.2, dampingFraction: 0.5)) {
            checkScale = 1.2
        }
        // Brief row "settle" flash — momentary scale up that springs back.
        withAnimation(.spring(response: 0.25, dampingFraction: 0.55)) {
            completionFlash = true
        }
        // Shimmer sweep — start position already off-screen left.
        // Animate to off-screen right over 0.6s. Polished marble feel.
        shimmerProgress = -1.5
        withAnimation(.easeOut(duration: 0.6)) {
            shimmerProgress = 1.5
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                checkScale = 1.0
                completionFlash = false
            }
        }
        onComplete?()
    }

    /// Field — sculpted depression aesthetic. Inner shadow at the top edge
    /// suggests the field is carved into the row (Noguchi, not floating
    /// rectangles). Ghost-text placeholder shows the previous workout's
    /// value when the field is empty. Hairline focus ring when editing.
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
                    // Inner shadow at the top edge — Noguchi-style depth.
                    // The depression reads as carved-into rather than
                    // filled-on-top. Only shown for incomplete (active)
                    // fields; completed fields are clean.
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
                // Focus ring — visible only while editing this field
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
            // Completed: clean, no fill. The row's overall completed tint
            // (applied at the ExerciseSetTable level) carries the state.
            return .clear
        }
        // Incomplete: visible depression tint.
        return Color("marblePrimary").opacity(0.10)
    }
}

// MARK: - Swipe to Delete

struct SwipeToDeleteRow<Content: View>: View {
    let content: () -> Content
    let onDelete: () -> Void

    @State private var offset: CGFloat = 0
    @State private var isSwiped = false

    private let deleteThreshold: CGFloat = -80
    private let fullSwipeThreshold: CGFloat = -180

    init(@ViewBuilder content: @escaping () -> Content, onDelete: @escaping () -> Void) {
        self.content = content
        self.onDelete = onDelete
    }

    var body: some View {
        ZStack(alignment: .trailing) {
            HStack {
                Spacer()
                Text("Delete")
                    .font(.marbleMono(12))
                    .foregroundStyle(Color("marbleBackground"))
                    .padding(.trailing, 20)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.red)
            .cornerRadius(4)
            .padding(.horizontal, 4)
            .opacity(offset < 0 ? 1 : 0)

            content()
                .background(Color("marbleBackground"))
                .offset(x: offset)
                .gesture(
                    DragGesture(minimumDistance: 20)
                        .onChanged { value in
                            let translation = value.translation.width
                            if translation < 0 {
                                offset = translation
                            } else if isSwiped {
                                offset = deleteThreshold + translation
                                if offset > 0 { offset = 0 }
                            }
                        }
                        .onEnded { value in
                            withAnimation(.easeOut(duration: 0.2)) {
                                if offset < fullSwipeThreshold {
                                    offset = -500
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                        onDelete()
                                    }
                                } else if offset < deleteThreshold {
                                    offset = deleteThreshold
                                    isSwiped = true
                                } else {
                                    offset = 0
                                    isSwiped = false
                                }
                            }
                        }
                )
                .onTapGesture {
                    if isSwiped {
                        withAnimation(.easeOut(duration: 0.2)) {
                            offset = 0
                            isSwiped = false
                        }
                    }
                }
        }
    }
}


#Preview {
    TemplateEditorView()
        .modelContainer(for: [WorkoutTemplate.self, Exercise.self], inMemory: true)
}
