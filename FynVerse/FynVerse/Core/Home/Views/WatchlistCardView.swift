import SwiftUI

struct WatchlistCardView: View {
    @EnvironmentObject var vm: HomeViewModel
    let watchlist: UserWatchlist
    @ObservedObject var authvm: AuthViewModel
    @State private var showAddStockSheet: Bool = false
    @State private var isExpanded: Bool = false // Track See More / See Less
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            
            // Header
            HStack {
                Text(watchlist.name)
                    .font(.headline)
                    .bold()
                    .foregroundStyle(Color.theme.accent)
                
                Spacer()
                
                Button {
                    showAddStockSheet = true
                } label: {
                    Image(systemName: "plus.magnifyingglass")
                        .font(.caption)
                        .padding(6)
                        .background(Capsule().fill(Color.theme.accent.opacity(0.1)))
                        .foregroundStyle(Color.theme.accent)
                }
                
                Button(role: .destructive) {
                    Task {
                        await vm.deleteWatchlist(watchlist)
                    }
                } label: {
                    Image(systemName: "trash.fill")
                        .font(.caption)
                        .padding(6)
                        .background(Capsule().fill(Color.theme.red.opacity(0.1)))
                        .foregroundStyle(Color.theme.red)
                }
            }
            
            // Body
            if watchlist.stockSymbols.isEmpty {
                Text("No stocks in this watchlist yet.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                VStack(spacing: 8) {
                    let symbolsToShow = isExpanded
                        ? watchlist.stockSymbols
                        : Array(watchlist.stockSymbols.prefix(5))
                    
                    ForEach(symbolsToShow, id: \.self) { symbol in
                        if let stock = vm.returnStockModel(symbol: symbol) {
                            NavigationLink {
                                DetailView(stock: stock, DBStock: nil, authViewModel: authvm)
                            } label: {
                                StockRowView(stock: stock, portfolioStock: nil)
                            }
                            .buttonStyle(.plain)
                        } else {
                            Text("\(symbol) - Data not available")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                    
                    // See More / See Less
                    if watchlist.stockSymbols.count > 5 {
                        Button {
                            withAnimation {
                                isExpanded.toggle()
                            }
                        } label: {
                            Text(isExpanded ? "See Less" : "See More")
                                .font(.caption)
                                .foregroundColor(.blue)
                                .padding(.top, 4)
                        }
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.theme.cardBackground)
                .shadow(color: .black.opacity(0.05), radius: 3, x: 0, y: 2)
        )
        .padding(.horizontal)
        .sheet(isPresented: $showAddStockSheet) {
            AddStockToWatchlistSheet(watchlist: watchlist)
        }
    }
}
