import SwiftUI

struct SectionHeader: View {
    let title: String

    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(Color.theme.accent)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)

            Divider()
        }
    }
}
