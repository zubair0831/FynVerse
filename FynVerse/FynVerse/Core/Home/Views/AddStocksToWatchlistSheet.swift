import SwiftUI

struct AddStockToWatchlistSheet: View {
    @EnvironmentObject var vm: HomeViewModel
    @Environment(\.dismiss) var dismiss
    
    let watchlist: UserWatchlist
    @State private var searchText: String = ""
    
    var filteredStocks: [StockModel] {
        guard !searchText.isEmpty else { return vm.allStocks }
        let lower = searchText.lowercased()
        return vm.allStocks.filter {
            $0.SYMBOL.lowercased().contains(lower) ||
            $0.NAME_OF_COMPANY.lowercased().contains(lower)
        }
    }

    var body: some View {
        NavigationStack {
            VStack {
                SearchBarView(searchText: $searchText)
                    .padding(.horizontal)
                    .padding(.top)
                
                if filteredStocks.isEmpty {
                    Spacer()
                    Text("No matching stocks found")
                        .foregroundColor(.secondary)
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(filteredStocks) { stock in
                                Button {
                                    Task {
                                        await vm.addStock(stock, toWatchlist: watchlist)
                                        dismiss()
                                    }
                                } label: {
                                    StockRowView(stock: stock, portfolioStock: nil)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical)
                    }
                }
            }
            .navigationTitle("Add to \(watchlist.name)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
            .task {
                if vm.allStocks.isEmpty {
                    await vm.fetchStocks()
                }
            }
        }
    }
}
