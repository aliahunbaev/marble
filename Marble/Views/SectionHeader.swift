import SwiftUI

struct SectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.system(size: 13, weight: .regular, design: .monospaced))
            .foregroundStyle(.secondary)
            .tracking(1)
    }
}

#Preview {
    SectionHeader(title: "QUICK START")
        .padding()
}
