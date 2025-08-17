import SwiftUI

struct SeeMoreButton: View {
    let resultantStocks: [StockModel]
    let title: String
    @ObservedObject var authvm:AuthViewModel

    var body: some View {
        NavigationLink {
            SeeMoreView(resultantStocks: resultantStocks, title: title, vm: authvm)
        } label: {
            HStack(spacing: 4) {
                Text("See All")
                Image(systemName: "chevron.right")
            }
            .font(.subheadline)
        }
        .buttonStyle(.plain) // Make sure it doesn't have a default style
    }
}
