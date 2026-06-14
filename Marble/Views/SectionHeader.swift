import SwiftUI

struct SectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.custom("ABC Favorit Mono Variable Unlicensed Trial", size: 12).weight(.light))
            .foregroundStyle(Color("marbleSecondary"))
            .tracking(1)
    }
}

/// Shared empty-state text block so every "nothing here yet" surface
/// reads identically. Single typeface (ABC Favorit, never mono) across
/// both lines — headline larger and full-contrast, subline smaller and
/// secondary, so it's legible without shouting. Call sites own their
/// own framing/padding (some are inline within a section, some fill the
/// screen); this just standardises the typography + contrast.
struct MarbleEmptyState: View {
    let headline: String
    var subline: String? = nil

    var body: some View {
        VStack(spacing: 8) {
            Text(headline)
                .font(.marbleBody(22))
                .foregroundStyle(Color("marblePrimary"))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            if let subline {
                Text(subline)
                    .font(.marbleBody(14))
                    .foregroundStyle(Color("marbleSecondary"))
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

#Preview {
    SectionHeader(title: "QUICK START")
        .padding()
}
