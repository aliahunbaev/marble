import SwiftUI
import SwiftData

struct TrainView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var templates: [WorkoutTemplate]

    @State private var showingTemplateEditor = false
    @State private var showingEmptyWorkout = false
    @State private var selectedTemplate: WorkoutTemplate?
    @State private var editingTemplate: WorkoutTemplate?
    @State private var workoutTemplate: WorkoutTemplate?

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 32) {
                    quickStartSection
                    programsSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 40)
            }
            .background(Color("marbleBackground"))
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

    // MARK: - Quick Start

    private var quickStartSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "QUICK START")

            Button {
                showingEmptyWorkout = true
            } label: {
                Text("Start Workout")
                    .font(.system(.title3, design: .default))
                    .fontWeight(.medium)
                    .foregroundStyle(Color("marblePrimary"))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(Color("marbleCard"))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Programs

    private var programsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                SectionHeader(title: "PROGRAMS")
                Spacer()
                Button {
                    editingTemplate = nil
                    showingTemplateEditor = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .medium, design: .monospaced))
                        .foregroundStyle(Color("marblePrimary"))
                        .frame(width: 32, height: 32)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color("marblePrimary"), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }

            if templates.isEmpty {
                emptyProgramsPlaceholder
            } else {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(templates) { template in
                        TemplateCardView(template: template)
                            .onTapGesture {
                                selectedTemplate = template
                            }
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
                    }
                }
            }
        }
    }

    private var emptyProgramsPlaceholder: some View {
        VStack(spacing: 8) {
            Text("No programs yet")
                .font(.system(.subheadline, design: .monospaced))
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
