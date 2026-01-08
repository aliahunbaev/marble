import SwiftUI
import SwiftData
import Charts

struct WeightTrackingView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WeightEntry.date, order: .reverse) private var weightEntries: [WeightEntry]
    @State private var showingAddWeight = false

    private var chartData: [WeightEntry] {
        Array(weightEntries.reversed().suffix(30))
    }

    private var currentWeight: Double? {
        weightEntries.first?.weight
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Current weight display
                if let weight = currentWeight {
                    MarbleHeroNumber(
                        value: String(format: "%.1f", weight),
                        unit: "LBS"
                    )
                    .padding(.vertical, MarbleSpacing.m)
                }

                // Chart
                if !chartData.isEmpty {
                    Chart(chartData) { entry in
                        LineMark(
                            x: .value("Date", entry.date),
                            y: .value("Weight", entry.weight)
                        )
                        .foregroundStyle(.primary)
                        .lineStyle(StrokeStyle(lineWidth: 2))

                        PointMark(
                            x: .value("Date", entry.date),
                            y: .value("Weight", entry.weight)
                        )
                        .foregroundStyle(.primary)
                    }
                    .chartXAxis {
                        AxisMarks(values: .stride(by: .day, count: 7)) { _ in
                            AxisGridLine()
                            AxisValueLabel(format: .dateTime.month().day())
                        }
                    }
                    .chartYAxis {
                        AxisMarks { _ in
                            AxisGridLine()
                            AxisValueLabel()
                        }
                    }
                    .frame(height: 200)
                    .padding()

                    Divider()
                }

                // Weight entries list
                if weightEntries.isEmpty {
                    ContentUnavailableView(
                        "No weight logged",
                        systemImage: "chart.line.uptrend.xyaxis",
                        description: Text("Tap + to log your first weight")
                    )
                } else {
                    List {
                        ForEach(weightEntries) { entry in
                            WeightEntryRow(entry: entry)
                        }
                        .onDelete(perform: deleteEntries)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("WEIGHT")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAddWeight = true
                    } label: {
                        Image(systemName: "plus")
                            .fontWeight(.medium)
                    }
                }
            }
            .sheet(isPresented: $showingAddWeight) {
                AddWeightView()
            }
        }
    }

    private func deleteEntries(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(weightEntries[index])
        }
    }
}

struct WeightEntryRow: View {
    let entry: WeightEntry

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: MarbleSpacing.xxxs) {
                Text("\(entry.weight, specifier: "%.1f") LBS")
                    .font(.marbleDataValue)
                    .foregroundColor(.marblePrimary)

                Text(entry.date.formatted(date: .abbreviated, time: .shortened))
                    .font(.marbleCaption)
                    .foregroundColor(.marbleSecondary)
            }

            Spacer()

            if let notes = entry.notes, !notes.isEmpty {
                Text(notes)
                    .font(.marbleCaption)
                    .foregroundColor(.marbleSecondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, MarbleSpacing.xxxs)
    }
}

#Preview {
    WeightTrackingView()
        .modelContainer(for: [WeightEntry.self])
}
