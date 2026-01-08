import Foundation

enum ServingOption: Identifiable, Hashable {
    case portion(USDAFood.FoodPortion)
    case grams(Double)

    var id: String {
        switch self {
        case .portion(let p): return "portion_\(p.id)"
        case .grams(let g): return "grams_\(Int(g))"
        }
    }

    var displayText: String {
        switch self {
        case .portion(let p): return p.displayTextWithGrams
        case .grams(let g): return "\(Int(g))g"
        }
    }

    var gramWeight: Double {
        switch self {
        case .portion(let p): return p.gramWeight ?? 100
        case .grams(let g): return g
        }
    }
}
