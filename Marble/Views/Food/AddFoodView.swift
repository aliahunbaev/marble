import SwiftUI
import SwiftData

struct AddFoodView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @StateObject private var usdaService = USDAService()
    @State private var searchText = ""
    @State private var selectedFood: USDAFood?
    @State private var servingSize: String = "100"
    @State private var selectedServing: ServingOption?
    @State private var availableServings: [ServingOption] = []
    @State private var showManualEntry = false
    @State private var manualGrams: String = "100"

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if let food = selectedFood {
                    // Food details and confirmation
                    ScrollView {
                        VStack(alignment: .leading, spacing: 24) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(food.displayName)
                                    .font(.system(size: 24, weight: .light))

                                if selectedServing == nil || availableServings.isEmpty {
                                    Text("Per 100g")
                                        .font(.system(size: 13))
                                        .foregroundStyle(.secondary)
                                }
                            }

                            Divider()

                            VStack(spacing: 16) {
                                let servingGrams = selectedServing?.gramWeight ?? (Double(manualGrams) ?? 100)
                                let multiplier = servingGrams / 100.0

                                NutrientRow(label: "Calories", value: "\(Int(food.calories * multiplier))")
                                NutrientRow(label: "Protein", value: "\(Int(food.protein * multiplier))g")
                                NutrientRow(label: "Carbs", value: "\(Int(food.carbs * multiplier))g")
                                NutrientRow(label: "Fat", value: "\(Int(food.fat * multiplier))g")
                            }

                            Divider()

                            VStack(alignment: .leading, spacing: 12) {
                                Text("Serving size")
                                    .font(.system(size: 13))
                                    .foregroundStyle(.secondary)

                                if !availableServings.isEmpty {
                                    Picker("Serving", selection: $selectedServing) {
                                        ForEach(availableServings) { serving in
                                            Text(serving.displayText).tag(Optional(serving))
                                        }
                                    }
                                    .pickerStyle(.menu)
                                    .font(.system(size: 17))
                                }

                                Button {
                                    showManualEntry.toggle()
                                } label: {
                                    Text(showManualEntry ? "Hide manual entry" : "Enter custom amount")
                                        .font(.system(size: 13))
                                        .foregroundStyle(.blue)
                                }

                                if showManualEntry {
                                    HStack {
                                        TextField("100", text: $manualGrams)
                                            .keyboardType(.decimalPad)
                                            .textFieldStyle(.roundedBorder)
                                            .font(.system(size: 17))
                                        Text("g")
                                            .font(.system(size: 17))
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }

                            Button {
                                addFood(food: food)
                            } label: {
                                Text("Add to log")
                                    .font(.system(size: 17, weight: .medium))
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.primary)
                                    .foregroundStyle(Color(uiColor: .systemBackground))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding()
                    }
                } else {
                    // Search interface
                    if usdaService.searchResults.isEmpty && !searchText.isEmpty && !usdaService.isLoading {
                        ContentUnavailableView(
                            "No results",
                            systemImage: "magnifyingglass",
                            description: Text("Try a different search term")
                        )
                    } else if usdaService.searchResults.isEmpty {
                        ContentUnavailableView(
                            "Search for food",
                            systemImage: "fork.knife",
                            description: Text("Use the USDA database to find nutrition info")
                        )
                    } else {
                        List(usdaService.searchResults) { food in
                            Button {
                                selectedFood = food
                                loadServingOptions(for: food)
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(food.displayName)
                                        .font(.system(size: 16, weight: .regular))
                                        .foregroundStyle(.primary)

                                    HStack {
                                        Text("Per 100g")
                                            .font(.system(size: 11))
                                            .foregroundStyle(.tertiary)
                                        Spacer()
                                        Text("\(Int(food.calories)) cal · P: \(Int(food.protein))g · C: \(Int(food.carbs))g · F: \(Int(food.fat))g")
                                    }
                                    .font(.system(size: 13))
                                    .foregroundStyle(.secondary)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                        .listStyle(.plain)
                    }
                }
            }
            .navigationTitle(selectedFood == nil ? "Add food" : "Food details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                if selectedFood != nil {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            selectedFood = nil
                        } label: {
                            Text("Back")
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search foods")
            .onChange(of: searchText) { _, newValue in
                Task {
                    await usdaService.searchFoods(query: newValue)
                }
            }
        }
    }

    private func loadServingOptions(for food: USDAFood) {
        var options: [ServingOption] = []

        // Add food-specific portions from API
        if let portions = food.foodPortions, !portions.isEmpty {
            let validPortions = portions.filter {
                $0.gramWeight != nil && $0.gramWeight! > 0
            }
            options.append(contentsOf: validPortions.map { .portion($0) })
        }

        // Add 100g as standard option
        options.append(.grams(100))

        availableServings = options
        selectedServing = options.first
    }

    private func addFood(food: USDAFood) {
        let servingGrams = selectedServing?.gramWeight ?? (Double(manualGrams) ?? 100)
        let multiplier = servingGrams / 100.0

        let portionDesc: String?
        if case .portion(let p) = selectedServing {
            portionDesc = p.displayText
        } else {
            portionDesc = nil
        }

        let entry = FoodEntry(
            name: food.displayName,
            servingSize: servingGrams,
            servingUnit: "g",
            portionDescription: portionDesc,
            calories: food.calories * multiplier,
            protein: food.protein * multiplier,
            carbs: food.carbs * multiplier,
            fat: food.fat * multiplier,
            fdcId: String(food.fdcId)
        )

        modelContext.insert(entry)
        dismiss()
    }
}

struct NutrientRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 15))
            Spacer()
            Text(value)
                .font(.system(size: 15, weight: .medium))
        }
    }
}

#Preview {
    AddFoodView()
        .modelContainer(for: [FoodEntry.self])
}
