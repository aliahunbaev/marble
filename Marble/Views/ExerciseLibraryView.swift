import SwiftUI
import SwiftData

/// Library picker for adding (or replacing) exercises into a workout.
///
/// Two modes, distinguished by `replacingExerciseName`:
///   - **Add mode** (default): multi-select. Tapping a row highlights it
///     as part of this pick session. Tapping Add commits all highlighted
///     exercises to the workout. The same exercise can be added repeatedly
///     across separate pick sessions — the library shows no awareness of
///     what's already in the workout.
///   - **Replace mode**: single-select. Tapping a row commits immediately
///     and dismisses. The nav title reads "Replace [exercise name]" for
///     explicit context.
struct ExerciseLibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Exercise.name) private var allExercises: [Exercise]

    @State private var searchText = ""
    @State private var showingCreate = false
    @State private var newName = ""
    @State private var newMuscleGroup = ""
    @State private var newEquipment = ""
    /// Active filters. `nil` means "all" (the default, unfiltered view).
    @State private var muscleFilter: String? = nil
    @State private var equipmentFilter: String? = nil
    /// Non-nil while the "?" guide popup is presented for an exercise.
    @State private var guideExercise: Exercise? = nil

    /// Canonical equipment ordering for the filter menu. Only values
    /// actually present in the library are shown (see `equipmentOptions`).
    private let equipmentOrder = ["Barbell", "Dumbbell", "Machine", "Cable", "Bodyweight"]
    /// Local selection state for add mode — set of exercise IDs the
    /// user has tapped in this pick session. Cleared on dismiss.
    @State private var selectedIDs: Set<PersistentIdentifier> = []

    /// Commits the picked exercises back to the caller.
    /// - In add mode, fires when the user taps Add with the current
    ///   selection (may be 0..N exercises).
    /// - In replace mode, fires with exactly one exercise the moment
    ///   the user taps any row.
    let onPick: ([Exercise]) -> Void

    /// When non-nil, the picker is in replace mode (see type comment).
    var replacingExerciseName: String? = nil

    private var isReplaceMode: Bool { replacingExerciseName != nil }

    private var filteredExercises: [Exercise] {
        allExercises.filter { exercise in
            if let group = muscleFilter, exercise.muscleGroup != group { return false }
            if let equipment = equipmentFilter, exercise.equipment != equipment { return false }
            if !searchText.isEmpty {
                return exercise.name.localizedCaseInsensitiveContains(searchText) ||
                    exercise.muscleGroup.localizedCaseInsensitiveContains(searchText)
            }
            return true
        }
    }

    /// Muscle-group options for the filter, derived from the live
    /// library so custom groups appear too.
    private var muscleGroupOptions: [String] {
        Array(Set(allExercises.map(\.muscleGroup)))
            .filter { !$0.isEmpty }
            .sorted()
    }

    /// Equipment options for the filter, in canonical order and limited
    /// to values present in the library (empty/custom values are
    /// excluded — they live only under "All equipment").
    private var equipmentOptions: [String] {
        let present = Set(allExercises.map(\.equipment))
        return equipmentOrder.filter { present.contains($0) }
    }

    private var groupedExercises: [(String, [Exercise])] {
        let grouped = Dictionary(grouping: filteredExercises) { $0.muscleGroup }
        return grouped.sorted { $0.key < $1.key }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Search bar
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(Color("marbleSecondary"))
                            .font(.system(size: 14))
                        TextField("Search exercises", text: $searchText)
                            .font(.marbleBody(14))
                            .autocorrectionDisabled()
                    }
                    .padding(12)
                    .background(Color("marbleFieldBackground"))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 12)

                    // Filter row — muscle group + equipment. Each opens a
                    // single-select menu; "All …" resets that axis.
                    filterRow
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)

                    if filteredExercises.isEmpty {
                        emptyState
                    } else {
                        ForEach(groupedExercises, id: \.0) { group, exercises in
                            muscleGroupSection(group, exercises: exercises)
                        }
                    }
                }
                .padding(.bottom, 40)
            }
            .background(Color("marbleBackground"))
            .navigationTitle(navTitle)
            .navigationBarTitleDisplayMode(.inline)
            .marbleKeyboardDismiss()
            .sheet(item: $guideExercise) { exercise in
                ExerciseGuideView(exercise: exercise)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Color("marblePrimary"))
                    }
                }
                // Add button only appears in add mode. Replace mode
                // commits immediately on row tap; no batch confirmation.
                if !isReplaceMode {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(addButtonLabel) {
                            commitAddSelection()
                        }
                        .font(.marbleMono(14, weight: .medium))
                        .disabled(selectedIDs.isEmpty)
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingCreate = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 14, weight: .medium))
                    }
                }
            }
            .marbleInputDialog(
                "New exercise",
                isPresented: $showingCreate,
                fields: [
                    MarbleDialogField(
                        placeholder: "Exercise name",
                        text: $newName,
                        autocapitalization: .words,
                        isRequired: true
                    ),
                    MarbleDialogField(
                        placeholder: "Muscle group (e.g. Chest)",
                        text: $newMuscleGroup,
                        autocapitalization: .words
                    ),
                ],
                selector: MarbleDialogSelector(
                    label: "Equipment",
                    options: equipmentOrder,
                    selection: $newEquipment
                ),
                confirmLabel: "Add",
                onConfirm: { createExercise() },
                onCancel: {
                    newName = ""
                    newMuscleGroup = ""
                    newEquipment = ""
                }
            )
        }
    }

    /// The two filter controls. Each is a `Menu` wrapping a `Picker`,
    /// which renders a single-select checklist with the active choice
    /// ticked. Selection type is `String?` so the "All …" row maps to
    /// `nil` (unfiltered).
    private var filterRow: some View {
        HStack(spacing: 8) {
            Menu {
                Picker("Muscle group", selection: $muscleFilter) {
                    Text("All muscle groups").tag(String?.none)
                    ForEach(muscleGroupOptions, id: \.self) { group in
                        Text(group).tag(String?.some(group))
                    }
                }
            } label: {
                filterChip(label: muscleFilter ?? "All muscle groups",
                           isActive: muscleFilter != nil)
            }

            Menu {
                Picker("Equipment", selection: $equipmentFilter) {
                    Text("All equipment").tag(String?.none)
                    ForEach(equipmentOptions, id: \.self) { equipment in
                        Text(equipment).tag(String?.some(equipment))
                    }
                }
            } label: {
                filterChip(label: equipmentFilter ?? "All equipment",
                           isActive: equipmentFilter != nil)
            }
        }
    }

    private func filterChip(label: String, isActive: Bool) -> some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.marbleMono(12, weight: .medium))
                .foregroundStyle(Color("marblePrimary"))
                .lineLimit(1)
            Spacer(minLength: 0)
            Image(systemName: "chevron.down")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(Color("marbleSecondary"))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(isActive
            ? Color("marblePrimary").opacity(0.08)
            : Color("marbleFieldBackground"))
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(Color("marblePrimary").opacity(isActive ? 0.25 : 0), lineWidth: 1)
        )
    }

    /// "Exercises" / "Replace [name]" — context-aware title.
    private var navTitle: String {
        if let name = replacingExerciseName {
            return "Replace \(name)"
        }
        return "Exercises"
    }

    /// "Add" / "Add 3" — show count when more than one is selected.
    private var addButtonLabel: String {
        selectedIDs.count > 1 ? "Add \(selectedIDs.count)" : "Add"
    }

    private func muscleGroupSection(_ group: String, exercises: [Exercise]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader(title: group.uppercased())
                .padding(.horizontal, 20)
                .padding(.bottom, 8)

            VStack(spacing: 0) {
                ForEach(exercises) { exercise in
                    exerciseRow(exercise)
                    if exercise.id != exercises.last?.id {
                        Rectangle()
                            .fill(Color("marblePrimary").opacity(0.06))
                            .frame(height: 0.5)
                            .padding(.leading, 20)
                    }
                }
            }
            .overlay(
                Rectangle()
                    .frame(height: 0.5)
                    .foregroundStyle(Color("marblePrimary").opacity(0.06)),
                alignment: .top
            )
            .overlay(
                Rectangle()
                    .frame(height: 0.5)
                    .foregroundStyle(Color("marblePrimary").opacity(0.06)),
                alignment: .bottom
            )
            .padding(.bottom, 24)
        }
    }

    private func exerciseRow(_ exercise: Exercise) -> some View {
        // Highlight only reflects the user's in-session selection (add
        // mode), never what's already in the workout. The picker is
        // intentionally unaware of workout state — you can add the same
        // exercise multiple times across separate pick sessions.
        let isPicked = selectedIDs.contains(exercise.persistentModelID)
        // The "?" is a sibling button (not nested in the row's tap
        // target) so opening the guide never toggles selection.
        return HStack(spacing: 0) {
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                handleRowTap(exercise)
            } label: {
                HStack {
                    Text(exercise.name)
                        .font(.marbleBody(17))
                        .foregroundStyle(Color("marblePrimary"))
                    Spacer(minLength: 8)
                    if isPicked && !isReplaceMode {
                        Image(systemName: "checkmark")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(Color("marblePrimary"))
                    }
                }
                .padding(.leading, 20)
                .padding(.vertical, 18)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                guideExercise = exercise
            } label: {
                // Use the app's own typeface (ABC Favorit), not an SF
                // Symbol — a system-font "?" clashes with the custom font
                // used for the exercise name right beside it.
                Text("?")
                    .font(.marbleBody(17))
                    .foregroundStyle(Color("marblePrimary"))
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.leading, 8)
            .padding(.trailing, 16)
        }
        .background(
            // Warm-bone wash when picked. Matches the completed-set
            // tint vocabulary so "selected" reads consistently.
            isPicked && !isReplaceMode
                ? Color("marblePrimary").opacity(0.06)
                : Color.clear
        )
    }

    /// Tap behavior depends on mode:
    /// - Replace: commit immediately with this single exercise + dismiss.
    /// - Add: toggle selection state.
    private func handleRowTap(_ exercise: Exercise) {
        if isReplaceMode {
            onPick([exercise])
            dismiss()
        } else {
            let id = exercise.persistentModelID
            if selectedIDs.contains(id) {
                selectedIDs.remove(id)
            } else {
                selectedIDs.insert(id)
            }
        }
    }

    /// Commit the in-session add selection — fires onPick with the
    /// chosen exercises in stable order, then dismisses.
    private func commitAddSelection() {
        let picked = allExercises.filter { selectedIDs.contains($0.persistentModelID) }
        guard !picked.isEmpty else { return }
        onPick(picked)
        dismiss()
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            MarbleEmptyState(
                headline: "No exercises found.",
                subline: searchText.isEmpty ? "Tap + to add one." : nil
            )
            if !searchText.isEmpty {
                Button {
                    newName = searchText
                    showingCreate = true
                } label: {
                    Text("CREATE \"\(searchText.uppercased())\"")
                        .marbleSecondaryButton(fullWidth: false)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    private func createExercise() {
        let trimmed = newName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let group = newMuscleGroup.trimmingCharacters(in: .whitespaces)
        let exercise = Exercise(
            name: trimmed,
            muscleGroup: group.isEmpty ? "General" : group,
            equipment: newEquipment
        )
        modelContext.insert(exercise)
        // Newly-created exercises auto-select in add mode so the user
        // doesn't have to find and tap them in the list afterward.
        if !isReplaceMode {
            selectedIDs.insert(exercise.persistentModelID)
        } else {
            // Replace mode: pick it immediately
            onPick([exercise])
            dismiss()
        }
        newName = ""
        newMuscleGroup = ""
        newEquipment = ""
    }
}

#Preview {
    ExerciseLibraryView(onPick: { _ in })
        .modelContainer(for: Exercise.self, inMemory: true)
}
