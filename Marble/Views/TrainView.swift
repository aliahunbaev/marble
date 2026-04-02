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
            .background(Color(.systemBackground))
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
                    .font(.system(.title3, design: .monospaced))
                    .fontWeight(.medium)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(Color(.systemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color(.label), lineWidth: 1.5)
                    )
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
                        .frame(width: 32, height: 32)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Color(.label), lineWidth: 1)
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
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}

#Preview {
    TrainView()
        .modelContainer(for: [WorkoutTemplate.self, Workout.self], inMemory: true)
}
