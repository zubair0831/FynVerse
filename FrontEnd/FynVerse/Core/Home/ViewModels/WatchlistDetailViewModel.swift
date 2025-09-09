//
//  WatchlistDetailViewModel.swift
//  FynVerse
//
//  Created by zubair ahmed on 16/08/25.
//

import Foundation

@MainActor
class WatchlistDetailViewModel: ObservableObject {
    @Published var searchText: String = ""
    @Published var showAll: Bool = false
    @Published var watchlist: UserWatchlist
    
    private let homeVM: HomeViewModel
    
    init(watchlist: UserWatchlist, homeVM: HomeViewModel) {
        self.watchlist = watchlist
        self.homeVM = homeVM
    }
    
    var filteredWatchlistStocks: [StockModel] {
        let stocks = homeVM.allStocks.filter { watchlist.stockSymbols.contains($0.SYMBOL) }
        guard !searchText.isEmpty else { return stocks }
        let lower = searchText.lowercased()
        return stocks.filter {
            $0.SYMBOL.lowercased().contains(lower) ||
            $0.NAME_OF_COMPANY.lowercased().contains(lower)
        }
    }
    
    var displayedStocks: [StockModel] {
        showAll ? filteredWatchlistStocks : Array(filteredWatchlistStocks.prefix(5))
    }
    
    func deleteStock(_ stock: StockModel) async {
        await homeVM.removeStock(stock, fromWatchlist: watchlist)
        if let updated = homeVM.userWatchlists.first(where: { $0.id == watchlist.id }) {
            self.watchlist = updated
        }
    }
}
