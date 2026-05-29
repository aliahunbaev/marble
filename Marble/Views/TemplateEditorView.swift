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
        VStack(spacing: 0) {
            editorToolbar
            Rectangle()
                .fill(Color("marblePrimary").opacity(0.06))
                .frame(height: 0.5)

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    TextField("Template", text: $name)
                        .font(.custom("ABC Favorit Variable Unlicensed Trial", size: 26).weight(.light))
                        .foregroundStyle(Color("marblePrimary"))
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                        .padding(.bottom, 24)

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
                            if entry.id != entries.last?.id {
                                exerciseDivider
                            }
                        }
                    }

                    addExerciseButton
                        .padding(.top, entries.isEmpty ? 0 : 24)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 40)
                }
            }
        }
        .background(Color("marbleBackground"))
        .sheet(isPresented: $showingLibrary) {
            let selectedExercises = entries.map(\.exercise)
            ExerciseLibraryView(selectedExercises: selectedExercises) { exercise in
                toggleExercise(exercise)
            }
        }
    }

    private var editorToolbar: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color("marblePrimary"))
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.plain)

            Spacer()

            Button {
                save()
            } label: {
                Text("SAVE")
                    .font(.custom("ABC Favorit Mono Variable Unlicensed Trial", size: 12).weight(.light))
                    .tracking(1)
                    .foregroundStyle(Color("marblePrimary"))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color("marblePrimary").opacity(0.12), lineWidth: 0.5)
                    )
            }
            .buttonStyle(.plain)
            .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            .opacity(name.trimmingCharacters(in: .whitespaces).isEmpty ? 0.3 : 1)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
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
                    .font(.custom("ABC Favorit Mono Variable Unlicensed Trial", size: 14).weight(.light))
                Text("EXERCISE")
                    .font(.custom("ABC Favorit Mono Variable Unlicensed Trial", size: 12).weight(.light))
                    .tracking(1)
            }
            .foregroundStyle(Color("marbleSecondary"))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color("marblePrimary").opacity(0.12), lineWidth: 0.5))
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
                .font(.custom("ABC Favorit Variable Unlicensed Trial", size: 16).weight(.light))
                .foregroundStyle(Color("marblePrimary"))

            Spacer()

            Text("\(entry.sets.count) sets")
                .font(.custom("ABC Favorit Mono Variable Unlicensed Trial", size: 11).weight(.light))
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

struct ExerciseSetTable: View {
    @Environment(\.modelContext) private var modelContext
    @Binding var entry: ExerciseEntry
    var onRemove: (() -> Void)? = nil
    var showPrevious: Bool = true
    var isWorkoutMode: Bool = false
    var onSetCompleted: (() -> Void)? = nil
    var dragHandle: Bool = false
    var onDragChanged: ((CGFloat) -> Void)? = nil
    var onDragEnded: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Exercise name header
            HStack {
                if dragHandle {
                    Image(systemName: "line.3.horizontal")
                        .font(.system(size: 12, weight: .light))
                        .foregroundStyle(Color("marbleTertiary"))
                        .padding(.trailing, 6)
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    onDragChanged?(value.translation.height)
                                }
                                .onEnded { _ in
                                    onDragEnded?()
                                }
                        )
                }

                Text(entry.exercise.name)
                    .font(.custom("ABC Favorit Variable Unlicensed Trial", size: 18).weight(.light))
                    .foregroundStyle(Color("marblePrimary"))

                Spacer()

                if let onRemove {
                    Button {
                        onRemove()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Color("marbleSecondary"))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 12)

            // Column headers
            columnHeaders
                .padding(.horizontal, 20)
                .padding(.bottom, 8)

            // Set rows
            ForEach($entry.sets) { $set in
                let index = entry.sets.firstIndex(where: { $0.id == set.id }) ?? 0
                let prevText: String? = showPrevious
                    ? PreviousPerformance.formattedPrevious(for: entry.exercise, setIndex: index, context: modelContext)
                    : nil
                SwipeToDeleteRow {
                    SetRowView(
                        setNumber: index + 1,
                        weight: $set.weight,
                        reps: $set.reps,
                        isCompleted: $set.isCompleted,
                        previousText: prevText,
                        showCheckmark: isWorkoutMode,
                        onComplete: onSetCompleted
                    )
                    .padding(.horizontal, 20)
                    .padding(.vertical, 6)
                    .background(
                        set.isCompleted && isWorkoutMode
                            ? Color("marbleCompletedRow")
                            : Color.clear
                    )
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
                HStack(spacing: 4) {
                    Text("+")
                        .font(.custom("ABC Favorit Mono Variable Unlicensed Trial", size: 12).weight(.light))
                    Text("SET")
                        .font(.custom("ABC Favorit Mono Variable Unlicensed Trial", size: 10).weight(.light))
                        .tracking(1)
                }
                .foregroundStyle(Color("marbleSecondary"))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color("marblePrimary").opacity(0.12), lineWidth: 0.5)
                )
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 20)
            .padding(.top, 8)
        }
    }

    private var columnHeaders: some View {
        HStack(spacing: 12) {
            Text("SET")
                .frame(width: 28, alignment: .center)
            if showPrevious {
                Text("PREVIOUS")
                    .frame(maxWidth: .infinity)
            } else {
                Spacer()
            }
            Text("LBS")
                .frame(width: 72, alignment: .center)
            Text("REPS")
                .frame(width: 72, alignment: .center)
            if isWorkoutMode {
                Spacer().frame(width: 32)
            }
        }
        .font(.custom("ABC Favorit Mono Variable Unlicensed Trial", size: 10).weight(.light))
        .tracking(0.5)
        .foregroundStyle(Color("marbleSecondary"))
    }
}

// MARK: - Set Row

struct SetRowView: View {
    let setNumber: Int
    @Binding var weight: String
    @Binding var reps: String
    @Binding var isCompleted: Bool
    var previousText: String? = nil
    var showCheckmark: Bool = false
    var onComplete: (() -> Void)? = nil

    @State private var checkScale: CGFloat = 1.0

    var body: some View {
        HStack(spacing: 12) {
            // Set number
            Text("\(setNumber)")
                .font(.marbleMono(14, weight: isCompleted ? .medium : .light))
                .foregroundStyle(Color("marblePrimary").opacity(isCompleted ? 1.0 : 0.55))
                .frame(width: 28, height: 36, alignment: .center)

            // Previous
            if showCheckmark || previousText != nil {
                Text(previousText ?? "—")
                    .font(.marbleMono(15))
                    .foregroundStyle(Color("marbleSecondary"))
                    .frame(height: 36)
                    .frame(maxWidth: .infinity)
            } else {
                Spacer()
            }

            // Weight
            fieldView(text: $weight, keyboard: .decimalPad)

            // Reps
            fieldView(text: $reps, keyboard: .numberPad)

            // Checkmark button
            if showCheckmark {
                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    let wasCompleted = isCompleted
                    withAnimation(.easeInOut(duration: 0.15)) {
                        isCompleted.toggle()
                    }
                    if !wasCompleted {
                        withAnimation(.spring(response: 0.2, dampingFraction: 0.5)) {
                            checkScale = 1.3
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                            withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                                checkScale = 1.0
                            }
                        }
                        onComplete?()
                    }
                } label: {
                    Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 22, weight: .light))
                        .foregroundStyle(isCompleted ? Color("marblePrimary") : Color("marblePrimary").opacity(0.25))
                        .scaleEffect(checkScale)
                }
                .buttonStyle(.plain)
                .frame(width: 32)
            }
        }
    }

    /// Bordered field — present but quiet. Replaces the prior underline.
    private func fieldView(text: Binding<String>, keyboard: UIKeyboardType) -> some View {
        TextField("", text: text)
            .font(.marbleMono(17, weight: text.wrappedValue.isEmpty ? .light : .regular))
            .foregroundStyle(Color("marblePrimary"))
            .multilineTextAlignment(.center)
            .keyboardType(keyboard)
            .frame(width: 72, height: 36)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isCompleted
                        ? Color.clear
                        : Color("marblePrimary").opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(
                        isCompleted
                            ? Color.clear
                            : Color("marblePrimary").opacity(0.18),
                        lineWidth: 0.5
                    )
            )
            .animation(nil, value: text.wrappedValue)
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
                    .font(.custom("ABC Favorit Mono Variable Unlicensed Trial", size: 12).weight(.light))
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
