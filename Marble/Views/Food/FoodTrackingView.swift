import SwiftUI
import SwiftData

struct FoodTrackingView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \FoodEntry.date, order: .reverse) private var allFoodEntries: [FoodEntry]
    @State private var showingAddFood = false

    private var todayEntries: [FoodEntry] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return allFoodEntries.filter { calendar.isDate($0.date, inSameDayAs: today) }
    }

    private var totalCalories: Double {
        todayEntries.reduce(0) { $0 + $1.calories }
    }

    private var totalProtein: Double {
        todayEntries.reduce(0) { $0 + $1.protein }
    }

    private var totalCarbs: Double {
        todayEntries.reduce(0) { $0 + $1.carbs }
    }

    private var totalFat: Double {
        todayEntries.reduce(0) { $0 + $1.fat }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Macro summary
                VStack(spacing: MarbleSpacing.xs) {
                    MarbleHeroNumber(
                        value: "\(Int(totalCalories))",
                        unit: "CAL"
                    )

                    HStack(spacing: MarbleSpacing.m) {
                        MarbleMacroIndicator(letter: "P", grams: Int(totalProtein))
                        MarbleMacroIndicator(letter: "C", grams: Int(totalCarbs))
                        MarbleMacroIndicator(letter: "F", grams: Int(totalFat))
                    }
                }
                .padding(.vertical, MarbleSpacing.m)
                .frame(maxWidth: .infinity)
                .background(Color.marbleBackground)

                Divider()

                // Food entries list
                if todayEntries.isEmpty {
                    ContentUnavailableView(
                        "No food logged",
                        systemImage: "fork.knife",
                        description: Text("Tap + to add your first meal")
                    )
                } else {
                    List {
                        ForEach(todayEntries) { entry in
                            FoodEntryRow(entry: entry)
                        }
                        .onDelete(perform: deleteEntries)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("FUEL")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAddFood = true
                    } label: {
                        Image(systemName: "plus")
                            .fontWeight(.medium)
                    }
                }
            }
            .sheet(isPresented: $showingAddFood) {
                AddFoodView()
            }
        }
    }

    private func deleteEntries(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(todayEntries[index])
        }
    }
}


struct FoodEntryRow: View {
    let entry: FoodEntry

    var body: some View {
        VStack(alignment: .leading, spacing: MarbleSpacing.xxxs) {
            Text(entry.name)
                .font(.marbleBody)
                .foregroundColor(.marblePrimary)

            if let portion = entry.portionDescription {
                Text("\(portion) (\(Int(entry.servingSize))G)")
                    .font(.marbleCaption)
                    .foregroundColor(.marbleSecondary)
            }

            HStack(spacing: MarbleSpacing.xs) {
                if entry.portionDescription == nil {
                    Text("\(Int(entry.servingSize))G")
                        .font(.marbleDataValue)
                }
                Text("\(Int(entry.calories)) CAL")
                Text("P: \(Int(entry.protein))G")
                Text("C: \(Int(entry.carbs))G")
                Text("F: \(Int(entry.fat))G")
            }
            .font(.marbleDataValue)
            .foregroundColor(.marbleSecondary)
        }
        .padding(.vertical, MarbleSpacing.xxxs)
    }
}

#Preview {
    FoodTrackingView()
        .modelContainer(for: [FoodEntry.self])
}
