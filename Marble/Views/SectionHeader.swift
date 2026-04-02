import SwiftUI

struct SectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.system(size: 11, weight: .medium, design: .monospaced))
            .foregroundStyle(Color("marbleSecondary"))
            .tracking(1.5)
    }
}

#Preview {
    SectionHeader(title: "QUICK START")
        .padding()
}
