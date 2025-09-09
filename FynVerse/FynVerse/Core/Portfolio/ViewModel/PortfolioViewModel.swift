
import Foundation

@MainActor
class PortfolioViewModel: ObservableObject {
    @Published var portfolioStocks: [DBPortfolioStock] = []
    @Published var totalInvestment: Double = 0
    @Published var portfolioValue: Double = 0
    @Published var totalGainLoss: Double = 0
    @Published var dataInitializedForPortfolio: Bool = false

    private let portfolioService = PortfolioService()
    private let portfolioHistoryService = PortfolioHistoryService()
    private let authViewModel: AuthViewModel
    private let homeViewModel: HomeViewModel

    init(authViewModel: AuthViewModel, homeViewModel: HomeViewModel) {
        self.authViewModel = authViewModel
        self.homeViewModel = homeViewModel
    }

    func fetchPortfolioStocks() async {
        guard let user = authViewModel.user else { return }
        do {
            portfolioStocks = try await portfolioService.fetchPortfolioStocks(for: user.userID)
            let summary = portfolioService.calculatePortfolioSummary(
                portfolioStocks: portfolioStocks,
                allStocks: homeViewModel.allStocks
            )
            totalInvestment = summary.investment
            portfolioValue = summary.value
            totalGainLoss = summary.gainLoss
            
            // Save daily snapshot after fetching portfolio data
            await saveDailyPortfolioSnapshot()
            
        } catch {
            print("❌ Portfolio fetch error:", error.localizedDescription)
        }
    }
    
    // MARK: - Portfolio History Methods
    
    /// Saves the current portfolio state as a daily snapshot
    func saveDailyPortfolioSnapshot() async {
        guard let user = authViewModel.user else { return }
        
        // Only save if we have meaningful data
        guard totalInvestment > 0 || portfolioValue > 0 else { return }
        
        do {
            try await portfolioHistoryService.saveDailyPortfolioSnapshot(
                userID: user.userID,
                totalInvestment: totalInvestment,
                portfolioValue: portfolioValue,
                totalGainLoss: totalGainLoss
            )
        } catch {
            print("❌ Failed to save daily portfolio snapshot:", error.localizedDescription)
        }
    }
    
    /// Fetches portfolio history for analytics
    func fetchPortfolioHistory(days: Int = 365) async -> [PortfolioHistoryModel] {
        guard let user = authViewModel.user else { return [] }
        
        do {
            return try await portfolioHistoryService.fetchPortfolioHistory(
                userID: user.userID,
                days: days
            )
        } catch {
            print("❌ Failed to fetch portfolio history:", error.localizedDescription)
            return []
        }
    }
    
    

    // MARK: - Analytics Helper Methods
    
    /// Returns the portfolio summary for a specific date (useful for analytics)
    func getPortfolioSummary(for stocks: [DBPortfolioStock], with allStocks: [StockModel]) -> (investment: Double, value: Double, gainLoss: Double) {
        return portfolioService.calculatePortfolioSummary(
            portfolioStocks: stocks,
            allStocks: allStocks
        )
    }
    
    /// Groups portfolio stocks by sector
    func getStocksBySector() async -> [String: [DBPortfolioStock]] {
        var sectorGroups: [String: [DBPortfolioStock]] = [:]
        
        for stock in portfolioStocks {
            let sector = await fetchSectorForStock(symbol: stock.stockSymbol) ?? "Unknown"
            
            if sectorGroups[sector] != nil {
                sectorGroups[sector]?.append(stock)
            } else {
                sectorGroups[sector] = [stock]
            }
        }
        
        return sectorGroups
    }
    
    /// Fetches sector information for a stock symbol
    private func fetchSectorForStock(symbol: String) async -> String? {
        let urlString = "http://localhost:8000/stock/\(symbol)/comprehensive"
        guard let url = URL(string: urlString) else { return nil }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let decoder = JSONDecoder()
            let response = try decoder.decode(StockComprehensiveModel.self, from: data)
            return response.basic?.sector
        } catch {
            print("Failed to fetch sector for \(symbol):", error)
            return nil
        }
    }
    
    // MARK: - Computed Properties for Quick Analytics
    
    var portfolioPerformancePercentage: Double {
        guard totalInvestment > 0 else { return 0 }
        return (totalGainLoss / totalInvestment) * 100
    }
    
    var topHolding: DBPortfolioStock? {
        return portfolioStocks.max { stock1, stock2 in
            let value1 = getCurrentValue(for: stock1)
            let value2 = getCurrentValue(for: stock2)
            return value1 < value2
        }
    }
    
    var topGainer: DBPortfolioStock? {
        return portfolioStocks.max { stock1, stock2 in
            let gain1 = getGainLoss(for: stock1)
            let gain2 = getGainLoss(for: stock2)
            return gain1 < gain2
        }
    }
    
    var topLoser: DBPortfolioStock? {
        return portfolioStocks.min { stock1, stock2 in
            let gain1 = getGainLoss(for: stock1)
            let gain2 = getGainLoss(for: stock2)
            return gain1 < gain2
        }
    }
    
    // MARK: - Private Helper Methods
    
    private func getCurrentValue(for stock: DBPortfolioStock) -> Double {
        guard let stockModel = homeViewModel.returnStockModel(symbol: stock.stockSymbol) else { return 0 }
        return stockModel.Last_Price * Double(stock.quantity)
    }
    
    private func getGainLoss(for stock: DBPortfolioStock) -> Double {
        guard let stockModel = homeViewModel.returnStockModel(symbol: stock.stockSymbol) else { return 0 }
        let currentValue = stockModel.Last_Price * Double(stock.quantity)
        let investedValue = stock.avgBuyPrice * Double(stock.quantity)
        return currentValue - investedValue
    }
}
