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

#Preview {
    SectionHeader(title: "QUICK START")
        .padding()
}
