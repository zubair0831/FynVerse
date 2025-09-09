import Foundation

// MARK: - Portfolio Daily History Model
struct PortfolioHistoryModel: Codable, Identifiable {
    let id: String
    let date: String // Format: "yyyy-MM-dd"
    let totalInvestment: Double
    let portfolioValue: Double
    let totalGainLoss: Double
    let userID: String
    
    init(date: Date, totalInvestment: Double, portfolioValue: Double, totalGainLoss: Double, userID: String) {
        self.id = UUID().uuidString
        self.date = Self.dateFormatter.string(from: date)
        self.totalInvestment = totalInvestment
        self.portfolioValue = portfolioValue
        self.totalGainLoss = totalGainLoss
        self.userID = userID
    }
    
    static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
    
    var dateAsDate: Date? {
        return Self.dateFormatter.date(from: date)
    }
}

// MARK: - Sector Allocation Model
struct SectorAllocation: Identifiable {
    let id = UUID()
    let sector: String
    let value: Double
    let percentage: Double
    let stockCount: Int
    let stocks: [SectorStock]
}

struct SectorStock {
    let symbol: String
    let name: String
    let value: Double
    let percentage: Double // percentage within the sector
}

// MARK: - Chart Data Models
struct ChartDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let investmentValue: Double
    let currentValue: Double
    let gainLoss: Double
    
    var gainLossPercentage: Double {
        guard investmentValue > 0 else { return 0 }
        return (gainLoss / investmentValue) * 100
    }
}
