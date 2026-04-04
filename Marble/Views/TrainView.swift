import SwiftUI
import SwiftData

struct TrainView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var templates: [WorkoutTemplate]
    @Query(sort: \Workout.date, order: .reverse) private var workouts: [Workout]

    @State private var showingTemplateEditor = false
    @State private var showingEmptyWorkout = false
    @State private var selectedTemplate: WorkoutTemplate?
    @State private var editingTemplate: WorkoutTemplate?
    @State private var workoutTemplate: WorkoutTemplate?

    // Daily quotes
    private let quotes: [(text: String, author: String)] = [
        ("Man cannot remake himself without suffering, for he is both the marble and the sculptor.", "Alexis Carrel"),
        ("It is a shame for a man to grow old without seeing the beauty and strength of which his body is capable.", "Socrates"),
        ("The fight is won or lost far away from witnesses — behind the lines, in the gym, and out there on the road, long before I dance under those lights.", "Muhammad Ali"),
        ("I have never changed my clothes. I have always worn a uniform because what I did was change my own body instead; that is much more hardcore than changing an outfit.", "Rick Owens"),
        ("Pain, I came to feel, might well prove to be the sole proof of the persistence of consciousness within the flesh, the sole physical expression of consciousness.", "Yukio Mishima"),
        ("What is happiness? The feeling that power is growing, that resistance is overcome.", "Nietzsche"),
        ("Working out is modern couture. No outfit is going to make you look or feel as good as having a fit body.", "Rick Owens"),
        ("I don't count my sit-ups. I only start counting when it starts hurting, because they're the only ones that count.", "Muhammad Ali"),
        ("The world breaks everyone, and afterward, many are strong at the broken places.", "Hemingway"),
        ("Courage is grace under pressure.", "Hemingway"),
        ("Muscles have gradually become something akin to classical Greek. To revive the dead language, the discipline of the steel was required.", "Mishima"),
        ("My humanity is a constant self-overcoming.", "Nietzsche"),
        ("You have passed through life without an opponent — no one can ever know what you are capable of, not even you.", "Seneca"),
        ("The purpose of life is to be defeated by greater and greater things.", "Rilke"),
        ("Let everything happen to you: beauty and terror. Just keep going. No feeling is final.", "Rilke"),
        ("Do not pray for an easy life, pray for the strength to endure a difficult one.", "Bruce Lee"),
    ]

    private var dailyQuote: (text: String, author: String) {
        let day = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 0
        return quotes[day % quotes.count]
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Background with subtle warm radial gradient
                Color("marbleBackground")
                    .ignoresSafeArea()

                RadialGradient(
                    colors: [
                        Color("marbleTertiary").opacity(0.5),
                        Color("marbleBackground")
                    ],
                    center: .top,
                    startRadius: 0,
                    endRadius: 600
                )
                .ignoresSafeArea()

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
            }
            .navigationBarTitleDisplayMode(.inline)
            .fullScreenCover(isPresented: $showingTemplateEditor) {
                TemplateEditorView(template: editingTemplate)
            }
            .sheet(item: $selectedTemplate) { template in
                TemplateDetailSheet(template: template) {
                    selectedTemplate = nil
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        workoutTemplate = template
                    }
                }
            }
            .fullScreenCover(isPresented: $showingEmptyWorkout) {
                ActiveWorkoutView()
            }
            .fullScreenCover(item: $workoutTemplate) { template in
                ActiveWorkoutView(template: template)
            }
        }
    }

    // MARK: - Hero (Quote + Start)

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE · MMMM d"
        return formatter.string(from: Date()).uppercased()
    }

    private var heroSection: some View {
        VStack(spacing: 0) {
            // Date
            Text(formattedDate)
                .font(.custom("ABC Favorit Mono Variable Unlicensed Trial", size: 11).weight(.light))
                .foregroundStyle(Color("marbleSecondary"))
                .tracking(1.5)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 12)

            // Quote — vertically centered in fixed zone
            VStack {
                Spacer()
                Text(dailyQuote.text)
                    .font(.custom("ABC Favorit Variable Unlicensed Trial", size: 22).weight(.light))
                    .foregroundStyle(Color("marblePrimary"))
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Spacer()
            }
            .frame(height: 200)

            // Start workout
            Button {
                showingEmptyWorkout = true
            } label: {
                Text("Start Workout")
                    .font(.custom("ABC Favorit Variable Unlicensed Trial", size: 16).weight(.light))
                    .foregroundStyle(Color("marbleBackground"))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color("marblePrimary"))
                    .clipShape(Capsule())
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
                Button {
                    editingTemplate = nil
                    showingTemplateEditor = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 13, weight: .light))
                        .foregroundStyle(Color("marbleSecondary"))
                        .frame(width: 30, height: 30)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Color("marblePrimary").opacity(0.12), lineWidth: 0.5)
                        )
                }
                .buttonStyle(.plain)
            }

            if templates.isEmpty {
                emptyProgramsPlaceholder
            } else {
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
                                editingTemplate = template
                                showingTemplateEditor = true
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                            Button {
                                let copy = WorkoutTemplate(
                                    name: template.name + " Copy",
                                    exercises: template.exercises
                                )
                                modelContext.insert(copy)
                            } label: {
                                Label("Duplicate", systemImage: "doc.on.doc")
                            }
                            Button(role: .destructive) {
                                modelContext.delete(template)
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
        }
    }

    private func templateRow(_ template: WorkoutTemplate) -> some View {
        ZStack(alignment: .trailing) {
            // Handwritten watermark — ghost layer, right-aligned
            VStack(alignment: .trailing, spacing: 1) {
                ForEach(template.exercises) { exercise in
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
                        .font(.custom("ABC Favorit Variable Unlicensed Trial", size: 24).weight(.light))
                        .foregroundStyle(Color("marblePrimary"))

                    Text(templateMetadata(template))
                        .font(.custom("ABC Favorit Mono Variable Unlicensed Trial", size: 10).weight(.light))
                        .foregroundStyle(Color("marbleSecondary"))
                        .tracking(0.5)
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

        let days = Calendar.current.dateComponents([.day], from: last.date, to: Date()).day ?? 0
        if days == 0 {
            return "\(count) · TODAY"
        } else if days == 1 {
            return "\(count) · YESTERDAY"
        } else if days < 7 {
            return "\(count) · \(days) DAYS AGO"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d"
            return "\(count) · \(formatter.string(from: last.date).uppercased())"
        }
    }

    private var emptyProgramsPlaceholder: some View {
        VStack(spacing: 8) {
            Text("No programs yet")
                .font(.custom("ABC Favorit Mono Variable Unlicensed Trial", size: 13).weight(.light))
                .foregroundStyle(Color("marbleSecondary"))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}

#Preview {
    TrainView()
        .modelContainer(for: [WorkoutTemplate.self, Workout.self], inMemory: true)
}
