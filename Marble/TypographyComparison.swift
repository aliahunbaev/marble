import SwiftUI

// Colors defined in MarbleDesignSystem.swift

struct TypographyComparison: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 48) {
                Text("TYPOGRAPHY COMPARISON")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .tracking(2)
                    .foregroundColor(.marbleSecondary)
                    .padding(.top, 32)

                // Option A: Pure Sans Serif
                OptionSection(
                    title: "OPTION A: PURE SANS SERIF",
                    subtitle: "Apple-like • Invisible • Safe",
                    content: {
                        PureSansExample()
                    }
                )

                Divider()
                    .padding(.horizontal, 24)

                // Option B: Sans + Mono (RECOMMENDED)
                OptionSection(
                    title: "OPTION B: SANS + MONO",
                    subtitle: "Technical Precision • Discipline • RECOMMENDED",
                    content: {
                        SansMonoExample()
                    }
                )

                Divider()
                    .padding(.horizontal, 24)

                // Option C: Sans + Serif
                OptionSection(
                    title: "OPTION C: SANS + SERIF",
                    subtitle: "Classical • Editorial • Sculptural",
                    content: {
                        SansSerifExample()
                    }
                )

                Spacer(minLength: 48)
            }
            .frame(maxWidth: .infinity)
            .background(Color.marbleBackground)
        }
        .background(Color.marbleBackground)
    }
}

struct OptionSection<Content: View>: View {
    let title: String
    let subtitle: String
    let content: Content

    init(title: String, subtitle: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 4) {
                Text(title)
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .tracking(1.5)
                    .foregroundColor(.marblePrimary)

                Text(subtitle)
                    .font(.system(size: 10, weight: .regular))
                    .foregroundColor(.marbleSecondary)
            }

            VStack(spacing: 32) {
                content
            }
            .padding(.horizontal, 24)
        }
    }
}

// OPTION A: Pure Sans Serif (Apple-like)
struct PureSansExample: View {
    var body: some View {
        VStack(spacing: 32) {
            // Weight Display
            VStack(spacing: 8) {
                Text("185.5")
                    .font(.system(size: 72, weight: .semibold, design: .default))
                    .foregroundColor(.marblePrimary)
                Text("LBS")
                    .font(.system(size: 14, weight: .semibold, design: .default))
                    .tracking(2)
                    .foregroundColor(.marbleSecondary)
            }

            // Macro Summary
            VStack(spacing: 16) {
                Text("2347")
                    .font(.system(size: 72, weight: .semibold, design: .default))
                    .foregroundColor(.marblePrimary)

                HStack(spacing: 32) {
                    ComparisonMacroLabel(title: "P", value: "185G", design: .default)
                    ComparisonMacroLabel(title: "C", value: "220G", design: .default)
                    ComparisonMacroLabel(title: "F", value: "65G", design: .default)
                }
            }

            // Workout Set Example
            VStack(alignment: .leading, spacing: 8) {
                Text("Bench Press")
                    .font(.system(size: 16, weight: .medium, design: .default))
                    .foregroundColor(.marblePrimary)

                HStack(spacing: 8) {
                    Text("3 × 185 LBS")
                        .font(.system(size: 14, weight: .regular, design: .default))
                        .foregroundColor(.marbleSecondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// OPTION B: Sans + Mono (RECOMMENDED)
struct SansMonoExample: View {
    var body: some View {
        VStack(spacing: 32) {
            // Weight Display
            VStack(spacing: 8) {
                Text("185.5")
                    .font(.system(size: 72, weight: .semibold, design: .default))
                    .foregroundColor(.marblePrimary)
                Text("LBS")
                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                    .tracking(2)
                    .foregroundColor(.marbleSecondary)
            }

            // Macro Summary
            VStack(spacing: 16) {
                Text("2347")
                    .font(.system(size: 72, weight: .semibold, design: .default))
                    .foregroundColor(.marblePrimary)

                HStack(spacing: 32) {
                    ComparisonMacroLabel(title: "P", value: "185G", design: .monospaced)
                    ComparisonMacroLabel(title: "C", value: "220G", design: .monospaced)
                    ComparisonMacroLabel(title: "F", value: "65G", design: .monospaced)
                }
            }

            // Workout Set Example
            VStack(alignment: .leading, spacing: 8) {
                Text("Bench Press")
                    .font(.system(size: 16, weight: .medium, design: .default))
                    .foregroundColor(.marblePrimary)

                HStack(spacing: 8) {
                    Text("3 × 185 LBS")
                        .font(.system(size: 14, weight: .regular, design: .monospaced))
                        .foregroundColor(.marbleSecondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// OPTION C: Sans + Serif
struct SansSerifExample: View {
    var body: some View {
        VStack(spacing: 32) {
            // Weight Display
            VStack(spacing: 8) {
                Text("185.5")
                    .font(.system(size: 72, weight: .regular, design: .serif))
                    .foregroundColor(.marblePrimary)
                Text("LBS")
                    .font(.system(size: 14, weight: .semibold, design: .default))
                    .tracking(2)
                    .foregroundColor(.marbleSecondary)
            }

            // Macro Summary
            VStack(spacing: 16) {
                Text("2347")
                    .font(.system(size: 72, weight: .regular, design: .serif))
                    .foregroundColor(.marblePrimary)

                HStack(spacing: 32) {
                    ComparisonMacroLabel(title: "P", value: "185G", design: .default)
                    ComparisonMacroLabel(title: "C", value: "220G", design: .default)
                    ComparisonMacroLabel(title: "F", value: "65G", design: .default)
                }
            }

            // Workout Set Example
            VStack(alignment: .leading, spacing: 8) {
                Text("Bench Press")
                    .font(.system(size: 16, weight: .medium, design: .default))
                    .foregroundColor(.marblePrimary)

                HStack(spacing: 8) {
                    Text("3 × 185 LBS")
                        .font(.system(size: 14, weight: .regular, design: .default))
                        .foregroundColor(.marbleSecondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// Reusable Macro Label for comparison
struct ComparisonMacroLabel: View {
    let title: String
    let value: String
    let design: Font.Design

    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.system(size: 11, weight: .medium, design: design))
                .foregroundColor(.marbleSecondary)
            Text(value)
                .font(.system(size: 20, weight: .regular, design: design))
                .foregroundColor(.marblePrimary)
        }
    }
}

#Preview {
    TypographyComparison()
}
