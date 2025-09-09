import Foundation

@MainActor
class HomeViewModel: ObservableObject {
    @Published var allStocks: [StockModel] = []
    @Published var topGainerStocks: [StockModel] = []
    @Published var topLooserStocks: [StockModel] = []
    @Published var searchText: String = "" { didSet { filterStocks() } }
    @Published var filteredStocks: [StockModel] = []
    @Published var userWatchlists: [UserWatchlist] = []

    // Market Cap filtered stocks
    @Published var largeCapStocks: [StockModel] = []
    @Published var midCapStocks: [StockModel] = []
    @Published var smallCapStocks: [StockModel] = []
    
    @Published var authViewModel: AuthViewModel
    @Published var selectedTab = 0
    
    @Published var dataInitializedForHome: Bool = false
    @Published var dataInitializedForWatchlists: Bool = false
    
    private let manager = StockDataService.shared
    private let watchlistService = WatchlistService()
    
    init(authViewModel: AuthViewModel) {
        self.authViewModel = authViewModel
    }
    
    // MARK: - Stocks
    func fetchStocks() async {
        let cached = StockCacheService.loadStocksFromCache()
        if !cached.isEmpty {
            allStocks = cached.sorted { $0.MarketCap > $1.MarketCap }
            applyFilters()
            print("✅ Showing cached stocks...")
        }
        
        let fetched = await manager.fetchStocks()
        if !fetched.isEmpty {
            allStocks = fetched.sorted { $0.MarketCap > $1.MarketCap }
            StockCacheService.saveStocksToCache(fetched)
            print("✅ Stocks fetched from API.")
        }
        
        applyFilters()
    }

    // MARK: - Watchlists
    func fetchUserWatchlists() async {
        guard let user = authViewModel.user else { return }
        do {
            userWatchlists = try await watchlistService.fetchUserWatchlists(userID: user.userID)
        } catch {
            print("❌ Watchlist fetch error:", error.localizedDescription)
        }
    }
    
    func addWatchlist(name: String) async {
        guard let user = authViewModel.user else { return }
        do {
            let newWL = try await watchlistService.addWatchlist(userID: user.userID, name: name)
            userWatchlists.append(newWL)
        } catch {
            print("❌ Add watchlist error:", error.localizedDescription)
        }
    }
    
    func addStock(_ stock: StockModel, toWatchlist watchlist: UserWatchlist) async {
        guard let user = authViewModel.user else { return }
        var updated = watchlist
        if !updated.stockSymbols.contains(stock.SYMBOL) {
            updated.stockSymbols.append(stock.SYMBOL)
            do {
                try watchlistService.updateWatchlist(userID: user.userID, watchlist: updated)
                if let idx = userWatchlists.firstIndex(where: { $0.id == updated.id }) {
                    userWatchlists[idx] = updated
                }
            } catch {
                print("❌ Add stock error:", error.localizedDescription)
            }
        }
    }
    
    func removeStock(_ stock: StockModel, fromWatchlist watchlist: UserWatchlist) async {
        guard let user = authViewModel.user else { return }
        var updated = watchlist
        updated.stockSymbols.removeAll { $0 == stock.SYMBOL }
        do {
            try watchlistService.updateWatchlist(userID: user.userID, watchlist: updated)
            if let idx = userWatchlists.firstIndex(where: { $0.id == updated.id }) {
                userWatchlists[idx] = updated
            }
        } catch {
            print("❌ Remove stock error:", error.localizedDescription)
        }
    }
    
    func deleteWatchlist(_ watchlist: UserWatchlist) async {
        guard let user = authViewModel.user, let id = watchlist.id else { return }
        do {
            try await watchlistService.deleteWatchlist(userID: user.userID, watchlistID: id)
            userWatchlists.removeAll { $0.id == id }
        } catch {
            print("❌ Delete watchlist error:", error.localizedDescription)
        }
    }
    
    // MARK: - Filters
    func filterStocks() {
        let lower = searchText.lowercased()
        filteredStocks = searchText.isEmpty
            ? allStocks
            : allStocks.filter { $0.SYMBOL.lowercased().contains(lower) || $0.NAME_OF_COMPANY.lowercased().contains(lower) }
    }
    
    func filterGainerStocks() {
        topGainerStocks = allStocks.filter { $0.Percent_Change > 0 }
            .sorted { $0.Percent_Change > $1.Percent_Change }
    }
    
    func filterLooserStocks() {
        topLooserStocks = allStocks.filter { $0.Percent_Change < 0 }
            .sorted { $0.Percent_Change < $1.Percent_Change }
    }
    
    // MARK: - Market Cap Filters
    func filterByMarketCap() {
        let sortedStocks = allStocks.sorted { $0.MarketCap > $1.MarketCap }
        largeCapStocks = Array(sortedStocks.prefix(100))
        midCapStocks = Array(sortedStocks.dropFirst(100).prefix(250))
        smallCapStocks = Array(sortedStocks.dropFirst(350))
    }
    
    private func applyFilters() {
        filterStocks()
        filterGainerStocks()
        filterLooserStocks()
        filterByMarketCap()
    }
    
    /// Find the `StockModel` for a given symbol
        func returnStockModel(symbol: String) -> StockModel? {
            return allStocks.first { $0.SYMBOL == symbol }
        }
}
