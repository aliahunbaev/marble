import SwiftUI

// MARK: - MARBLE Design System
// Typography: Sans + Mono (Option B)
// Colors: Off-white/Soft-black for disciplined beauty

// MARK: - Colors

extension Color {
    /// Off-white background (warm, not stark) - #F8F8F8
    static let marbleBackground = Color(hex: "F8F8F8")

    /// Soft black text (not pure black, easier on eyes) - #1A1A1A
    static let marblePrimary = Color(hex: "1A1A1A")

    /// Mid gray for secondary text - #8E8E8E
    static let marbleSecondary = Color(hex: "8E8E8E")

    private init(hex: String) {
        let scanner = Scanner(string: hex)
        var rgbValue: UInt64 = 0
        scanner.scanHexInt64(&rgbValue)

        let r = Double((rgbValue & 0xFF0000) >> 16) / 255.0
        let g = Double((rgbValue & 0x00FF00) >> 8) / 255.0
        let b = Double((rgbValue & 0x0000FF)) / 255.0

        self.init(red: r, green: g, blue: b)
    }
}

// MARK: - Typography System

extension Font {
    /// Hero numbers: SF Pro Semibold 72pt
    /// Used for: weight on scale, daily calorie total
    static let marbleHero = Font.system(size: 72, weight: .semibold, design: .default)

    /// Data labels (units, measurements): SF Mono Medium 14pt
    /// Used for: LBS, CAL, macro units (G), set notation
    static let marbleDataLabel = Font.system(size: 14, weight: .medium, design: .monospaced)

    /// Data values: SF Mono Regular 16pt
    /// Used for: macro values, set details
    static let marbleDataValue = Font.system(size: 16, weight: .regular, design: .monospaced)

    /// Macro title (P/C/F): SF Mono Medium 11pt
    /// Used for: macro letter indicators
    static let marbleDataTitle = Font.system(size: 11, weight: .medium, design: .monospaced)

    /// Macro number: SF Mono Regular 20pt
    /// Used for: macro gram values in summary
    static let marbleDataNumber = Font.system(size: 20, weight: .regular, design: .monospaced)

    /// Body text: SF Pro Regular 16pt
    /// Used for: list items, exercise names, general UI
    static let marbleBody = Font.system(size: 16, weight: .regular, design: .default)

    /// Caption: SF Pro Regular 13pt
    /// Used for: timestamps, notes, secondary info
    static let marbleCaption = Font.system(size: 13, weight: .regular, design: .default)
}

// MARK: - Spacing System (8pt grid)

enum MarbleSpacing {
    static let xxxs: CGFloat = 4
    static let xxs: CGFloat = 8
    static let xs: CGFloat = 16
    static let s: CGFloat = 24
    static let m: CGFloat = 32
    static let l: CGFloat = 40
    static let xl: CGFloat = 48
    static let xxl: CGFloat = 56
    static let xxxl: CGFloat = 64
}

// MARK: - Reusable Components

/// Hero number display with unit label
/// Example: "185.5" with "LBS" below
struct MarbleHeroNumber: View {
    let value: String
    let unit: String

    var body: some View {
        VStack(spacing: MarbleSpacing.xxs) {
            Text(value)
                .font(.marbleHero)
                .foregroundColor(.marblePrimary)
            Text(unit)
                .font(.marbleDataLabel)
                .tracking(2)
                .textCase(.uppercase)
                .foregroundColor(.marbleSecondary)
        }
    }
}

/// Macro indicator (letter + value)
/// Example: "P" with "185G" below
struct MarbleMacroIndicator: View {
    let letter: String
    let grams: Int

    var body: some View {
        VStack(spacing: MarbleSpacing.xxxs) {
            Text(letter)
                .font(.marbleDataTitle)
                .foregroundColor(.marbleSecondary)
            Text("\(grams)G")
                .font(.marbleDataNumber)
                .foregroundColor(.marblePrimary)
        }
    }
}

/// Data label (monospace for measurements)
/// Example: "3 × 185 LBS"
struct MarbleDataLabel: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.marbleDataValue)
            .foregroundColor(.marbleSecondary)
    }
}
