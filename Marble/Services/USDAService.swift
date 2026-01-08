import Foundation

struct USDAFood: Codable, Identifiable {
    let fdcId: Int
    let description: String
    let foodNutrients: [FoodNutrient]?
    let brandOwner: String?
    let brandName: String?
    let score: Double?
    let dataType: String?
    let foodPortions: [FoodPortion]?

    var id: Int { fdcId }

    struct FoodNutrient: Codable {
        let nutrientId: Int?
        let nutrientName: String?
        let value: Double?
    }

    struct FoodPortion: Codable, Identifiable, Hashable {
        let id: Int
        let portionDescription: String?
        let gramWeight: Double?
        let modifier: String?

        var displayText: String {
            guard let desc = portionDescription else { return "serving" }
            if let mod = modifier, !mod.isEmpty {
                return "\(desc) (\(mod))"
            }
            return desc
        }

        var displayTextWithGrams: String {
            guard let grams = gramWeight else { return displayText }
            return "\(displayText) (\(Int(grams))g)"
        }
    }

    var calories: Double {
        foodNutrients?.first { $0.nutrientId == 1008 }?.value ?? 0
    }

    var protein: Double {
        foodNutrients?.first { $0.nutrientId == 1003 }?.value ?? 0
    }

    var carbs: Double {
        foodNutrients?.first { $0.nutrientId == 1005 }?.value ?? 0
    }

    var fat: Double {
        foodNutrients?.first { $0.nutrientId == 1004 }?.value ?? 0
    }

    var displayName: String {
        let brand = brandOwner ?? brandName
        if let brand = brand, !brand.isEmpty, !brand.lowercased().contains("unknown") {
            return "\(brand) - \(description)"
        }
        return description
    }

    var dataTypeDisplayPriority: Int {
        switch dataType {
        case "Branded": return 0
        case "Foundation": return 1
        case "SR Legacy": return 2
        default: return 3
        }
    }
}

struct USDASearchResponse: Codable {
    let foods: [USDAFood]
}

@MainActor
class USDAService: ObservableObject {
    @Published var searchResults: [USDAFood] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let apiKey = "ANLTBWGqj5JZPKdCofou51K65scXlaslamcVfN86"
    private let baseURL = "https://api.nal.usda.gov/fdc/v1"

    func searchFoods(query: String) async {
        guard !query.isEmpty else {
            searchResults = []
            return
        }

        isLoading = true
        errorMessage = nil

        // Include Branded foods for better coverage, sort by relevance, limit results
        let urlString = "\(baseURL)/foods/search?query=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")&api_key=\(apiKey)&dataType=Branded,SR Legacy,Foundation&pageSize=50&sortBy=score&sortOrder=desc"

        guard let url = URL(string: urlString) else {
            errorMessage = "Invalid URL"
            isLoading = false
            return
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(USDASearchResponse.self, from: data)

            // Filter out foods with incomplete nutrition data
            let filtered = response.foods.filter { food in
                food.calories > 0 || food.protein > 0 || food.carbs > 0 || food.fat > 0
            }

            // Secondary sort: prioritize branded foods, then by data completeness
            searchResults = filtered.sorted { a, b in
                // First by data type priority (Branded > Foundation > SR Legacy)
                if a.dataTypeDisplayPriority != b.dataTypeDisplayPriority {
                    return a.dataTypeDisplayPriority < b.dataTypeDisplayPriority
                }
                // Then by nutrition data completeness
                let aComplete = (a.calories > 0 ? 1 : 0) + (a.protein > 0 ? 1 : 0) +
                              (a.carbs > 0 ? 1 : 0) + (a.fat > 0 ? 1 : 0)
                let bComplete = (b.calories > 0 ? 1 : 0) + (b.protein > 0 ? 1 : 0) +
                              (b.carbs > 0 ? 1 : 0) + (b.fat > 0 ? 1 : 0)
                return aComplete > bComplete
            }
        } catch {
            errorMessage = "Search failed: \(error.localizedDescription)"
            searchResults = []
        }

        isLoading = false
    }
}
