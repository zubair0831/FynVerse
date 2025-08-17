import SwiftUI

struct WatchlistDetailView: View {
    @StateObject private var vm: WatchlistDetailViewModel
    @ObservedObject var authvm: AuthViewModel
    
    init(watchlist: UserWatchlist, homeVM: HomeViewModel, authvm: AuthViewModel) {
        _vm = StateObject(wrappedValue: WatchlistDetailViewModel(watchlist: watchlist, homeVM: homeVM))
        self.authvm = authvm
    }

    var body: some View {
        ZStack {
            Color.theme.background.ignoresSafeArea()
            VStack {
                if let nifty = vm.filteredWatchlistStocks.first(where: { $0.SYMBOL == "NIFTY 50" }) {
                    StatisticsView(nifty50: nifty, authvm: authvm)
                }
                
                SearchBarView(searchText: $vm.searchText)
                    .padding(.horizontal)
                
                Divider()
                
                if vm.filteredWatchlistStocks.isEmpty {
                    Text("No stocks found in this watchlist or matching your search.")
                        .foregroundColor(.secondary)
                        .padding()
                } else {
                    List {
                        ForEach(vm.displayedStocks) { stock in
                            NavigationLink(
                                destination: DetailView(stock: stock, DBStock: nil, authViewModel: authvm)
                            ) {
                                StockRowView(stock: stock, portfolioStock: nil)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    Task { await vm.deleteStock(stock) }
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                        
                        if vm.filteredWatchlistStocks.count > 5 {
                            Button {
                                withAnimation(.easeInOut) { vm.showAll.toggle() }
                            } label: {
                                Text(vm.showAll ? "See Less" : "See More")
                                    .font(.callout.bold())
                                    .foregroundColor(.blue)
                                    .frame(maxWidth: .infinity)
                            }
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                        }
                    }
                    .listStyle(.plain)
                }
            }
        }
        .navigationTitle(vm.watchlist.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}
