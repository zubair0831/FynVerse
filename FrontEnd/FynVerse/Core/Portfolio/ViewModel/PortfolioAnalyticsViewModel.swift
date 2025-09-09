import Foundation
import SwiftUI

@MainActor
class PortfolioAnalyticsViewModel: ObservableObject {
    @Published var portfolioHistory: [PortfolioHistoryModel] = []
    @Published var chartDataPoints: [ChartDataPoint] = []
    @Published var sectorAllocations: [SectorAllocation] = []
    @Published var isLoadingHistory = false
    @Published var isLoadingSectors = false
    @Published var selectedTimeRange: TimeRange = .threeMonths
    
    private let historyService = PortfolioHistoryService()
    private let portfolioViewModel: PortfolioViewModel
    private let homeViewModel: HomeViewModel
    private let authViewModel: AuthViewModel
    
    enum TimeRange: String, CaseIterable {
        case oneMonth = "1M"
        case threeMonths = "3M"
        case sixMonths = "6M"
        case oneYear = "1Y"
        case all = "All"
        
        var days: Int {
            switch self {
            case .oneMonth: return 30
            case .threeMonths: return 90
            case .sixMonths: return 180
            case .oneYear: return 365
            case .all: return 730 // 2 years max
            }
        }
    }
    
    init(portfolioViewModel: PortfolioViewModel, homeViewModel: HomeViewModel, authViewModel: AuthViewModel) {
        self.portfolioViewModel = portfolioViewModel
        self.homeViewModel = homeViewModel
        self.authViewModel = authViewModel
    }
    
    // MARK: - Portfolio History Methods
    
    func saveDailySnapshot() async {
        guard let userID = authViewModel.user?.userID else { return }
        
        do {
            try await historyService.saveDailyPortfolioSnapshot(
                userID: userID,
                totalInvestment: portfolioViewModel.totalInvestment,
                portfolioValue: portfolioViewModel.portfolioValue,
                totalGainLoss: portfolioViewModel.totalGainLoss
            )
        } catch {
            print("❌ Failed to save daily snapshot:", error)
        }
    }
    
    func fetchPortfolioHistory() async {
        guard let userID = authViewModel.user?.userID else { return }
        
        isLoadingHistory = true
        
        do {
            portfolioHistory = try await historyService.fetchPortfolioHistory(
                userID: userID,
                days: selectedTimeRange.days
            )
            updateChartDataPoints()
        } catch {
            print("❌ Failed to fetch portfolio history:", error)
        }
        
        isLoadingHistory = false
    }
    
    private func updateChartDataPoints() {
        chartDataPoints = portfolioHistory.compactMap { history in
            guard let date = history.dateAsDate else { return nil }
            return ChartDataPoint(
                date: date,
                investmentValue: history.totalInvestment,
                currentValue: history.portfolioValue,
                gainLoss: history.totalGainLoss
            )
        }
    }
    
    // MARK: - Sector Allocation Methods
    
    func calculateSectorAllocations() async {
        isLoadingSectors = true
        
        var sectorMap: [String: (value: Double, stocks: [SectorStock])] = [:]
        let totalPortfolioValue = portfolioViewModel.portfolioValue
        
        // Group stocks by sector
        for portfolioStock in portfolioViewModel.portfolioStocks {
            guard let stockModel = homeViewModel.returnStockModel(symbol: portfolioStock.stockSymbol) else { continue }
            
            // Fetch sector from API if not available in stockModel
            let sector = await fetchSectorForStock(symbol: stockModel.SYMBOL) ?? "Unknown"
            
            let currentPrice = stockModel.Last_Price
            let holdingValue = currentPrice * Double(portfolioStock.quantity)
            let percentage = (holdingValue / totalPortfolioValue) * 100
            
            let sectorStock = SectorStock(
                symbol: stockModel.SYMBOL,
                name: stockModel.NAME_OF_COMPANY,
                value: holdingValue,
                percentage: 0 // Will be calculated later within sector
            )
            
            if var existingSector = sectorMap[sector] {
                existingSector.value += holdingValue
                existingSector.stocks.append(sectorStock)
                sectorMap[sector] = existingSector
            } else {
                sectorMap[sector] = (value: holdingValue, stocks: [sectorStock])
            }
        }
        
        // Convert to SectorAllocation array
        sectorAllocations = sectorMap.map { (sector, data) in
            let percentage = (data.value / totalPortfolioValue) * 100
            
            // Calculate percentage within sector for each stock
            let updatedStocks = data.stocks.map { stock in
                SectorStock(
                    symbol: stock.symbol,
                    name: stock.name,
                    value: stock.value,
                    percentage: (stock.value / data.value) * 100
                )
            }
            
            return SectorAllocation(
                sector: sector,
                value: data.value,
                percentage: percentage,
                stockCount: data.stocks.count,
                stocks: updatedStocks
            )
        }.sorted { $0.value > $1.value }
        
        isLoadingSectors = false
    }
    
    private func fetchSectorForStock(symbol: String) async -> String? {
        // Use the same API endpoint as DetailViewModel
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
    
    // MARK: - Helper Methods
    
    func refreshData() async {
        await fetchPortfolioHistory()
        await calculateSectorAllocations()
        await saveDailySnapshot()
    }
    
    func changeTimeRange(_ newRange: TimeRange) async {
        selectedTimeRange = newRange
        await fetchPortfolioHistory()
    }
    
    // MARK: - Computed Properties
    
    var latestGainLossPercentage: Double {
        guard let latest = chartDataPoints.last,
              latest.investmentValue > 0 else { return 0 }
        return (latest.gainLoss / latest.investmentValue) * 100
    }
    
    var periodGainLoss: Double {
        guard let first = chartDataPoints.first,
              let last = chartDataPoints.last else { return 0 }
        return last.currentValue - first.currentValue
    }
    
    var periodGainLossPercentage: Double {
        guard let first = chartDataPoints.first,
              first.investmentValue > 0 else { return 0 }
        return (periodGainLoss / first.investmentValue) * 100
    }
}
