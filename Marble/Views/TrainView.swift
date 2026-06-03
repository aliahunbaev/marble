import SwiftUI
import SwiftData

/// Target for the template editor cover — either creating fresh or
/// editing a specific template. Modeling both cases as one Identifiable
/// state lets us drive the cover via `fullScreenCover(item:)` instead
/// of the bool+optional pair that captured stale state.
enum TemplateEditorTarget: Identifiable {
    case create
    case edit(WorkoutTemplate)

    var id: String {
        switch self {
        case .create: return "__create__"
        case .edit(let t): return "edit-\(t.cloudID)"
        }
    }
}

struct TrainView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(WorkoutSession.self) private var workoutSession
    @Query(sort: \WorkoutTemplate.displayOrder) private var templates: [WorkoutTemplate]
    @Query(sort: \Workout.date, order: .reverse) private var workouts: [Workout]

    @State private var selectedTemplate: WorkoutTemplate?
    /// Long-press a template row to enter reorder mode — rows collapse
    /// to plain titles with native drag handles. Tap DONE in the
    /// section header to exit.
    @State private var isReorderingTemplates = false
    /// Drives the template editor cover. Using item-based presentation
    /// (rather than two pieces of state — bool + optional template) so
    /// the cover always reads the *current* target at construction
    /// time. The previous pattern captured a stale `editingTemplate`
    /// during the open transition, which made edit-save look like a
    /// no-op (the editor was operating on whatever template had been
    /// set the time before).
    @State private var editorTarget: TemplateEditorTarget?

    // Daily quotes — terse, classical, on-thesis
    private let quotes: [String] = [
        "It is a shame for a man to grow old without seeing the beauty and strength of which his body is capable.",
        "Man cannot remake himself without suffering, for he is both the marble and the sculptor.",
        "The world breaks everyone, and afterward, many are strong at the broken places.",
        "Courage is grace under pressure.",
        "Muscles have gradually become something akin to classical Greek. To revive the dead language, the discipline of the steel was required.",
        "My humanity is a constant self-overcoming.",
        "You have passed through life without an opponent — no one can ever know what you are capable of, not even you.",
        "The purpose of life is to be defeated by greater and greater things.",
        "Do not pray for an easy life, pray for the strength to endure a difficult one.",
        "The impediment to action advances action. What stands in the way becomes the way.",
        "Difficulties strengthen the mind, as labor does the body.",
        "Character is destiny.",
        "No man is free who is not master of himself.",
        "Become who you are.",
        "You have power over your mind — not outside events. Realize this, and you will find strength.",
        "Perfect purity is possible if you turn your life into a line of poetry written with a splash of blood.",
    ]

    private var dailyQuote: String {
        let day = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 0
        return quotes[day % quotes.count]
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Hero zone — quote + start button
                    heroSection
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                        .padding(.bottom, 40)

                    // Divider
                    Rectangle()
                        .fill(Color("marblePrimary").opacity(0.06))
                        .frame(height: 0.5)
                        .padding(.horizontal, 20)

                    // Programs list
                    programsSection
                        .padding(.horizontal, 20)
                        .padding(.top, 24)
                        .padding(.bottom, 40)
                }
            }
            .marbleAtmosphereBackground()
            .navigationBarTitleDisplayMode(.inline)
            .fullScreenCover(item: $editorTarget) { target in
                switch target {
                case .create:
                    TemplateEditorView(template: nil)
                case .edit(let template):
                    TemplateEditorView(template: template)
                }
            }
            .sheet(item: $selectedTemplate) { template in
                TemplateDetailSheet(template: template) {
                    selectedTemplate = nil
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        workoutSession.start(template: template)
                    }
                }
            }
        }
    }

    // MARK: - Hero (Quote + Start)

    private var formattedDate: String {
        Date().marbleFullDate()
    }

    private var heroSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Date
            Text(formattedDate)
                .font(.marbleMono(11))
                .tracking(1)
                .foregroundStyle(Color("marbleSecondary"))
                .padding(.top, 12)

            // Quote — intrinsic sizing with deliberate breathing room
            Text(dailyQuote)
                .font(.marbleBody(22))
                .foregroundStyle(Color("marblePrimary"))
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 56)
                .padding(.bottom, 56)

            // Start workout — tinted glass primary capsule. Same archetype
            // as FINISH and SAVE so the commit language is consistent across
            // every "go" moment in the app.
            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                workoutSession.start()
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
                    .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 2)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Programs

    // MARK: - Programs List

    private var programsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                SectionHeader(title: "PROGRAMS")
                Spacer()
                if isReorderingTemplates {
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                            isReorderingTemplates = false
                        }
                    } label: {
                        Text("DONE")
                            .font(.marbleMono(11, weight: .medium))
                            .tracking(1.5)
                            .foregroundStyle(Color("marblePrimary"))
                            .padding(.horizontal, 12)
                            .frame(height: 32)
                    }
                    .buttonStyle(.plain)
                } else {
                    Button {
                        editorTarget = .create
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 14, weight: .regular))
                            .marbleGlassCapsule(size: 32)
                    }
                    .buttonStyle(.plain)
                }
            }

            if templates.isEmpty {
                emptyProgramsPlaceholder
            } else if isReorderingTemplates {
                reorderingTemplatesList
            } else {
                normalTemplatesList
            }
        }
    }

    private var normalTemplatesList: some View {
        VStack(spacing: 0) {
            ForEach(Array(templates.enumerated()), id: \.element.id) { index, template in
                Button {
                    selectedTemplate = template
                } label: {
                    templateRow(template)
                }
                .buttonStyle(.plain)
                .contextMenu {
                    Button {
                        editorTarget = .edit(template)
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    if templates.count >= 2 {
                        Button {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                                isReorderingTemplates = true
                            }
                        } label: {
                            Label("Reorder programs", systemImage: "arrow.up.arrow.down")
                        }
                    }
                    Button {
                        let copy = WorkoutTemplate(
                            name: template.name + " Copy",
                            exercises: template.orderedExercises()
                        )
                        copy.displayOrder = templates.count
                        modelContext.insert(copy)
                        try? modelContext.save()
                        CloudSyncService.shared.uploadTemplate(copy)
                    } label: {
                        Label("Duplicate", systemImage: "doc.on.doc")
                    }
                    Button(role: .destructive) {
                        let cloudID = template.cloudID
                        modelContext.delete(template)
                        try? modelContext.save()
                        Task { await CloudSyncService.shared.deleteTemplate(cloudID: cloudID) }
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }

                if index < templates.count - 1 {
                    Rectangle()
                        .fill(Color("marblePrimary").opacity(0.06))
                        .frame(height: 0.5)
                }
            }
        }
    }

    /// Compact reorder list — collapses each program to its title so
    /// the drag handles read clearly. Native edit-mode for native
    /// drag-to-reorder. Persists displayOrder + cloud syncs on each move.
    private var reorderingTemplatesList: some View {
        List {
            ForEach(templates) { template in
                Text(template.name)
                    .font(.marbleBody(20))
                    .foregroundStyle(Color("marblePrimary"))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
                    .listRowInsets(EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8))
                    .listRowSeparator(.visible, edges: .bottom)
                    .listRowSeparatorTint(Color("marblePrimary").opacity(0.08))
                    .listRowBackground(Color.clear)
            }
            .onMove(perform: moveTemplates)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .environment(\.editMode, .constant(.active))
        .frame(height: CGFloat(templates.count) * 56 + 12)
        .scrollDisabled(true)
    }

    private func moveTemplates(from source: IndexSet, to destination: Int) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        var reordered = templates
        reordered.move(fromOffsets: source, toOffset: destination)
        for (index, template) in reordered.enumerated() {
            if template.displayOrder != index {
                template.displayOrder = index
            }
        }
        try? modelContext.save()
        for template in reordered {
            CloudSyncService.shared.uploadTemplate(template)
        }
    }

    private func templateRow(_ template: WorkoutTemplate) -> some View {
        ZStack(alignment: .trailing) {
            // Handwritten watermark — ghost layer, right-aligned
            VStack(alignment: .trailing, spacing: 1) {
                ForEach(template.orderedExercises()) { exercise in
                    Text(exercise.name)
                        .font(.custom("Nothing You Could Do", size: 15))
                        .foregroundStyle(Color("marblePrimary").opacity(0.12))
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: 170, alignment: .trailing)

            // Content
            HStack(alignment: .center, spacing: 0) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(template.name)
                        .font(.marbleBody(24))
                        .foregroundStyle(Color("marblePrimary"))

                    Text(templateMetadata(template))
                        .font(.marbleMono(10))
                        .tracking(1)
                        .foregroundStyle(Color("marbleSecondary"))
                }
                Spacer(minLength: 20)
            }
        }
        .padding(.vertical, 24)
        .contentShape(Rectangle())
    }

    private func templateMetadata(_ template: WorkoutTemplate) -> String {
        let lastWorkout = workouts.first(where: { $0.name == template.name })
        let count = "\(template.exercises.count) EXERCISES"
        guard let last = lastWorkout else { return count }
        return "\(count) · \(last.date.marbleRelative())"
    }

    /// Empty state — match the editorial tone the rest of the app uses for
    /// absence ("Begin." on YOU, "No data yet" on lift detail). Two-line
    /// poetic prompt that invites first-template creation without nagging.
    private var emptyProgramsPlaceholder: some View {
        VStack(spacing: 6) {
            Text("No programs yet.")
                .font(.marbleBody(15))
                .foregroundStyle(Color("marbleSecondary"))
            Text("Tap + to compose one.")
                .font(.marbleMono(11))
                .tracking(1)
                .foregroundStyle(Color("marbleTertiary"))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}

#Preview {
    TrainView()
        .modelContainer(for: [WorkoutTemplate.self, Workout.self], inMemory: true)
}
