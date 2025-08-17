import SwiftUI

struct SeeMoreView: View {
    let resultantStocks: [StockModel]
    let title: String // This is the new property for reusability
    @ObservedObject var vm:AuthViewModel
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(resultantStocks) { stock in
                    // NavigationLink is now part of the content, which is correct
                    NavigationLink(destination: DetailView(stock: stock, DBStock: nil, authViewModel: vm)) {
                        StockRowView(stock: stock, portfolioStock: nil)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .navigationTitle(title) // Use the new title property
    }
}

