import Foundation
import SwiftUI
import FirebaseFirestore

@MainActor
class PortfolioAnalyticsViewModel: ObservableObject {
    @Published var portfolioHistory: [PortfolioHistoryModel] = []
    @Published var chartDataPoints: [ChartDataPoint] = []
    @Published var sectorAllocations: [SectorAllocation] = []
    @Published var portfolioRating: PortfolioAnalysisResponse?
    @Published var isLoadingHistory = false
    @Published var isLoadingSectors = false
    @Published var isLoadingRating = false
    @Published var isFetchingFreshData = false
    @Published var selectedTimeRange: TimeRange = .threeMonths
    @Published var useMLAnalysis = true
    @Published var analysisError: String?
    @Published var lastAnalyticsUpdate: Date?
    @Published var lastSectorUpdate: Date?
    
    private let historyService = PortfolioHistoryService()
    private let ratingService = PortfolioRatingService()
    private let portfolioViewModel: PortfolioViewModel
    private let homeViewModel: HomeViewModel
    private let authViewModel: AuthViewModel
    private let db = Firestore.firestore()
    
    // Cache for comprehensive stock data (symbol: sector)
    private var sectorCache: [String: String] = [:]
    // Full comprehensive data cache (symbol: StockComprehensiveModel)
    private var comprehensiveCache: [String: StockComprehensiveModel] = [:]
    
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
            case .all: return 730
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
            print("✅ Daily snapshot saved")
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
            print("✅ Portfolio history fetched: \(portfolioHistory.count) records")
        } catch {
            print("❌ Failed to fetch portfolio history:", error)
            analysisError = "Failed to load portfolio history"
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
        }.sorted { $0.date < $1.date }
    }
    
    // MARK: - Comprehensive Data Caching (for Sectors)
    
    /// Load cached comprehensive data from Firestore
    private func loadCachedComprehensiveData() async {
        guard let userID = authViewModel.user?.userID else { return }
        
        do {
            let docRef = db.collection("users").document(userID).collection("portfolioData").document("comprehensive")
            let document = try await docRef.getDocument()
            
            guard document.exists, let data = document.data() else {
                print("ℹ️ No cached comprehensive data found")
                return
            }
            
            if let stockDataArray = data["stocks"] as? [[String: Any]],
               let timestamp = data["lastUpdated"] as? Timestamp {
                
                for stockData in stockDataArray {
                    guard let symbol = stockData["symbol"] as? String,
                          let jsonString = stockData["data"] as? String,
                          let jsonData = jsonString.data(using: .utf8) else {
                        continue
                    }
                    
                    do {
                        let comprehensive = try JSONDecoder().decode(StockComprehensiveModel.self, from: jsonData)
                        comprehensiveCache[symbol] = comprehensive
                        
                        // Extract and cache sector
                        if let sector = comprehensive.basic?.sector {
                            sectorCache[symbol] = sector
                        }
                    } catch {
                        print("⚠️ Failed to decode comprehensive data for \(symbol)")
                    }
                }
                
                lastSectorUpdate = timestamp.dateValue()
                print("✅ Loaded \(comprehensiveCache.count) cached comprehensive entries from \(timestamp.dateValue())")
            }
            
        } catch {
            print("❌ Failed to load cached comprehensive data:", error.localizedDescription)
        }
    }
    
    /// Fetch and cache comprehensive data for all portfolio stocks
    private func fetchAndCacheComprehensiveData() async {
        guard let userID = authViewModel.user?.userID else { return }
        
        var updatedStocks: [[String: Any]] = []
        var fetchedCount = 0
        
        print("🔄 Fetching comprehensive data for \(portfolioViewModel.portfolioStocks.count) stocks...")
        
        for stock in portfolioViewModel.portfolioStocks {
            let symbol = stock.stockSymbol
            
            // Fetch comprehensive data
            if let comprehensive = await fetchComprehensiveData(symbol: symbol) {
                comprehensiveCache[symbol] = comprehensive
                fetchedCount += 1
                
                // Extract sector
                if let sector = comprehensive.basic?.sector {
                    sectorCache[symbol] = sector
                }
                
                // Serialize for caching
                if let jsonData = try? JSONEncoder().encode(comprehensive),
                   let jsonString = String(data: jsonData, encoding: .utf8) {
                    updatedStocks.append([
                        "symbol": symbol,
                        "data": jsonString,
                        "lastFetched": Timestamp(date: Date())
                    ])
                }
            }
        }
        
        // Save to Firestore
        do {
            let cacheData: [String: Any] = [
                "stocks": updatedStocks,
                "lastUpdated": Timestamp(date: Date())
            ]
            
            let docRef = db.collection("users").document(userID).collection("portfolioData").document("comprehensive")
            try await docRef.setData(cacheData)
            
            lastSectorUpdate = Date()
            print("✅ Cached comprehensive data for \(fetchedCount) stocks")
            
        } catch {
            print("❌ Failed to cache comprehensive data:", error.localizedDescription)
        }
    }
    
    /// Fetch comprehensive data for a single stock
    private func fetchComprehensiveData(symbol: String) async -> StockComprehensiveModel? {
        let urlString = "http://192.168.1.9:8000/stock/\(symbol)/comprehensive"
        guard let url = URL(string: urlString) else { return nil }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let decoder = JSONDecoder()
            let response = try decoder.decode(StockComprehensiveModel.self, from: data)
            return response
        } catch {
            print("❌ Failed to fetch comprehensive data for \(symbol):", error)
            return nil
        }
    }
    
    // MARK: - ML Portfolio Rating with Caching
    
    func fetchPortfolioRating(useML: Bool? = nil) async {
        guard !portfolioViewModel.portfolioStocks.isEmpty else {
            print("⚠️ No portfolio stocks to analyze")
            analysisError = "No stocks in portfolio"
            return
        }
        
        // 1. Load cached rating first
        await loadCachedPortfolioRating()
        
        // 2. Fetch fresh rating in background
        isFetchingFreshData = true
        isLoadingRating = true
        analysisError = nil
        
        let shouldUseML = useML ?? self.useMLAnalysis
        
        do {
            if shouldUseML {
                print("🤖 Fetching ML-enhanced portfolio analysis...")
                portfolioRating = try await ratingService.analyzePortfolioEnhanced(
                    holdings: portfolioViewModel.portfolioStocks
                )
                print("✅ ML-enhanced portfolio rating fetched")
                
                if let mlInsights = portfolioRating?.mlInsights {
                    print("📊 ML Risk Score: \(mlInsights.riskPrediction.mlRiskScore ?? 0)")
                    print("📊 Confidence: \(mlInsights.riskPrediction.confidence)%")
                    if mlInsights.anomalyDetection.isAnomaly {
                        print("⚠️ Anomaly detected: \(mlInsights.anomalyDetection.warnings)")
                    }
                }
            } else {
                print("📊 Fetching standard portfolio analysis...")
                portfolioRating = try await ratingService.analyzePortfolio(
                    holdings: portfolioViewModel.portfolioStocks
                )
                print("✅ Standard portfolio rating fetched")
            }
            
            lastAnalyticsUpdate = Date()
            
            // 3. Cache the fresh rating
            await cachePortfolioRating()
            
        } catch {
            print("❌ Failed to fetch portfolio rating:", error)
            analysisError = error.localizedDescription
            
            if shouldUseML {
                print("🔄 Attempting fallback to standard analysis...")
                do {
                    portfolioRating = try await ratingService.analyzePortfolio(
                        holdings: portfolioViewModel.portfolioStocks
                    )
                    lastAnalyticsUpdate = Date()
                    await cachePortfolioRating()
                    print("✅ Fallback analysis successful")
                } catch {
                    print("❌ Fallback also failed:", error)
                }
            }
        }
        
        isLoadingRating = false
        isFetchingFreshData = false
    }
    
    /// Load cached portfolio rating from Firestore
    private func loadCachedPortfolioRating() async {
        guard let userID = authViewModel.user?.userID else { return }
        
        do {
            let docRef = db.collection("users").document(userID).collection("portfolioData").document("analytics")
            let document = try await docRef.getDocument()
            
            guard document.exists, let data = document.data() else {
                print("ℹ️ No cached portfolio rating found")
                return
            }
            
            if let ratingJSON = data["portfolioRating"] as? String,
               let timestamp = data["lastUpdated"] as? Timestamp,
               let jsonData = ratingJSON.data(using: .utf8) {
                
                do {
                    let rating = try JSONDecoder().decode(PortfolioAnalysisResponse.self, from: jsonData)
                    self.portfolioRating = rating
                    self.lastAnalyticsUpdate = timestamp.dateValue()
                    print("✅ Loaded cached portfolio rating from \(timestamp.dateValue())")
                } catch {
                    print("⚠️ Failed to decode cached rating:", error)
                }
            }
            
        } catch {
            print("❌ Failed to load cached portfolio rating:", error.localizedDescription)
        }
    }
    
    /// Cache current portfolio rating to Firestore
    private func cachePortfolioRating() async {
        guard let userID = authViewModel.user?.userID,
              let rating = portfolioRating else { return }
        
        do {
            let encoder = JSONEncoder()
            let jsonData = try encoder.encode(rating)
            
            guard let jsonString = String(data: jsonData, encoding: .utf8) else {
                print("❌ Failed to convert rating to JSON string")
                return
            }
            
            let cacheData: [String: Any] = [
                "portfolioRating": jsonString,
                "lastUpdated": Timestamp(date: Date()),
                "useMLAnalysis": useMLAnalysis
            ]
            
            let docRef = db.collection("users").document(userID).collection("portfolioData").document("analytics")
            try await docRef.setData(cacheData)
            
            print("✅ Cached portfolio rating successfully")
            
        } catch {
            print("❌ Failed to cache portfolio rating:", error.localizedDescription)
        }
    }
    
    func toggleMLAnalysis() async {
        useMLAnalysis.toggle()
        await fetchPortfolioRating(useML: useMLAnalysis)
    }
    
    // MARK: - Sector Allocation with Caching
    
    func calculateSectorAllocations() async {
        guard let userID = authViewModel.user?.userID else { return }
        
        // 1. Load cached comprehensive data first (for instant sectors)
        await loadCachedComprehensiveData()
        
        // 2. Calculate with cached data if available
        if !sectorCache.isEmpty {
            calculateSectorsFromCache()
        }
        
        // 3. Fetch fresh comprehensive data in background
        isFetchingFreshData = true
        isLoadingSectors = true
        
        await fetchAndCacheComprehensiveData()
        
        // 4. Recalculate with fresh data
        calculateSectorsFromCache()
        
        isLoadingSectors = false
        isFetchingFreshData = false
    }
    
    /// Calculate sector allocations using cached comprehensive data
    private func calculateSectorsFromCache() {
        var sectorMap: [String: (value: Double, stocks: [SectorStock])] = [:]
        let totalPortfolioValue = portfolioViewModel.portfolioValue
        
        guard totalPortfolioValue > 0 else { return }
        
        for portfolioStock in portfolioViewModel.portfolioStocks {
            guard let stockModel = homeViewModel.returnStockModel(symbol: portfolioStock.stockSymbol) else { continue }
            
            // Get sector from cache (instant!)
            let sector = sectorCache[stockModel.SYMBOL] ?? "Unknown"
            
            let currentPrice = stockModel.Last_Price
            let holdingValue = currentPrice * Double(portfolioStock.quantity)
            
            let sectorStock = SectorStock(
                symbol: stockModel.SYMBOL,
                name: stockModel.NAME_OF_COMPANY,
                value: holdingValue,
                percentage: 0
            )
            
            if var existingSector = sectorMap[sector] {
                existingSector.value += holdingValue
                existingSector.stocks.append(sectorStock)
                sectorMap[sector] = existingSector
            } else {
                sectorMap[sector] = (value: holdingValue, stocks: [sectorStock])
            }
        }
        
        sectorAllocations = sectorMap.map { (sector, data) in
            let percentage = (data.value / totalPortfolioValue) * 100
            
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
        
        print("✅ Sector allocations calculated: \(sectorAllocations.count) sectors")
    }
    
    // MARK: - Helper Methods
    
    func refreshData() async {
        print("🔄 Refreshing all portfolio data...")
        analysisError = nil
        
        async let historyTask: () = fetchPortfolioHistory()
        async let sectorsTask: () = calculateSectorAllocations()
        async let ratingTask: () = fetchPortfolioRating()
        async let snapshotTask: () = saveDailySnapshot()
        
        await historyTask
        await sectorsTask
        await ratingTask
        await snapshotTask
        
        print("✅ All data refreshed")
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
    
    var hasMLPredictions: Bool {
        portfolioRating?.hasMLPredictions ?? false
    }
    
    var mlRiskLevel: String {
        portfolioRating?.mlInsights?.riskPrediction.riskLevel ?? "Unknown"
    }
    
    var hasAnomalies: Bool {
        portfolioRating?.mlInsights?.anomalyDetection.isAnomaly ?? false
    }
    
    var combinedRiskScore: Double {
        portfolioRating?.combinedRiskScore ?? 0
    }
    
    var warningCount: Int {
        portfolioRating?.warningCount ?? 0
    }
    
    var isShowingCachedData: Bool {
        if let lastUpdate = lastAnalyticsUpdate {
            return Date().timeIntervalSince(lastUpdate) > 300 // 5 minutes
        }
        return false
    }
}
