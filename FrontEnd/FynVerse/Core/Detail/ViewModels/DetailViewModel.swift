import SwiftUI

@MainActor
class DetailViewModel: ObservableObject {
    let stock: StockModel?
    let DBStock: DBPortfolioStock?
    let authViewModel: AuthViewModel
    
    @Published var selectedTab = 0
    @Published var showMoreOverview = false
    @Published var showMoreDetails = false
    @Published var showBuySheet = false
    @Published var showSellSheet = false
    
    @Published var isLoading = false

    @Published var stockComprehensive: StockComprehensiveModel?

    init(stock: StockModel?, DBStock: DBPortfolioStock?, authViewModel: AuthViewModel) {
        self.stock = stock
        self.DBStock = DBStock
        self.authViewModel = authViewModel
    }

    // MARK: - API Calls
    
    func fetchStockDetails() async {
        guard let stock = stock else { return }
        
        self.isLoading = true
        let urlString = "http://192.168.1.9:8000/stock/\(stock.SYMBOL)/comprehensive"
        guard let url = URL(string: urlString) else {
            print("Invalid URL")
            self.isLoading = false
            return
        }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            if let httpResp = response as? HTTPURLResponse {
                print("HTTP Status Code:", httpResp.statusCode)
            }
            
            let decoder = JSONDecoder()
            let reesponse = try decoder.decode(StockComprehensiveModel.self, from: data)
            self.stockComprehensive = reesponse
        } catch {
            print("Failed to fetch stock details:", error)
        }
        self.isLoading = false
    }
    
    // MARK: - Computed Tuples

    var overviewTuples: [(String, String)] {
        guard let s = stockComprehensive,
              let basic = s.basic else {
            return []
        }

        return [
            ("Company", basic.name ?? "N/A"),
            ("Sector", basic.sector ?? "N/A"),
            ("Industry", basic.industry ?? "N/A"),
            ("Country", basic.country ?? "N/A"),
            ("Exchange", basic.exchange ?? "N/A"),
            ("Currency", basic.currency ?? "N/A"),
            ("Employees", basic.employees != nil ? "\(basic.employees!)" : "N/A"),
            ("Website", basic.website ?? "N/A")
        ]
    }

    var additionalTuples: [(String, String)] {
        guard let s = stockComprehensive else { return [] }

        var tuples: [(String, String)] = []

        // Price
        if let price = s.price {
            tuples.append(("Current Price", formatNumber(price.current, decimals: 2)))
            tuples.append(("Previous Close", formatNumber(price.previousClose, decimals: 2)))
            tuples.append(("Open", formatNumber(price.open, decimals: 2)))
            tuples.append(("Day Low", formatNumber(price.dayLow, decimals: 2)))
            tuples.append(("Day High", formatNumber(price.dayHigh, decimals: 2)))
            tuples.append(("52 Week Low", formatNumber(price.week52Low, decimals: 2)))
            tuples.append(("52 Week High", formatNumber(price.week52High, decimals: 2)))
            tuples.append(("Market Cap", formatMarketCap(price.marketCap)))
        }

        // Valuation
        if let valuation = s.valuation {
            tuples.append(("PE Ratio", formatNumber(valuation.pe, decimals: 1)))
            tuples.append(("Forward PE", formatNumber(valuation.forwardPE, decimals: 1)))
            tuples.append(("Price to Book", formatNumber(valuation.priceToBook, decimals: 2)))
            tuples.append(("Price to Sales", formatNumber(valuation.priceToSales, decimals: 2)))
        }

        // Financials
        if let financial = s.financial {
            tuples.append(("Dividend Yield", formatPercentage(financial.dividendYield)))
            tuples.append(("Profit Margin", formatPercentage(financial.profitMargin)))
            tuples.append(("Operating Margin", formatPercentage(financial.operatingMargin)))
        }

        // Balance Sheet
        if let balanceSheet = s.balanceSheet {
            tuples.append(("Total Cash", formatLargeNumber(balanceSheet.totalCash)))
            tuples.append(("Total Debt", formatLargeNumber(balanceSheet.totalDebt)))
            tuples.append(("Debt to Equity", formatNumber(balanceSheet.debtToEquity, decimals: 2)))
            tuples.append(("Book Value", formatNumber(balanceSheet.bookValue, decimals: 2)))
        }

        // Shareholding Pattern
        if let shareholding = s.shareholding {
            tuples.append(("Shares Outstanding", formatShares(shareholding.sharesOutstanding)))
            tuples.append(("Float Shares", formatShares(shareholding.floatShares)))
            tuples.append(("Promoter Holding", shareholding.promoterHoldingPercent ?? "N/A"))
            tuples.append(("FII Holding", shareholding.fiiHoldingPercent ?? "N/A"))
            tuples.append(("Public Holding", shareholding.publicHoldingPercent ?? "N/A"))
            tuples.append(("Institutional Holding", shareholding.heldPercentInstitutions ?? "N/A"))
        }

        return tuples
    }

    // MARK: - Formatters
    
    private func formatMarketCap(_ value: Double?) -> String {
        guard let value = value else { return "N/A" }
        
        let crore: Double = 10_000_000
        let thousandCrore: Double = 1_000_000_000
        let lakhCrore: Double = 10_000_000_000_000
        
        if value >= lakhCrore {
            return String(format: "%.2f Lakh Cr", value / lakhCrore)
        } else if value >= thousandCrore {
            return String(format: "%.2f Th Cr", value / thousandCrore)
        } else if value >= crore {
            return String(format: "%.2f Cr", value / crore)
        } else {
            return String(format: "%.2f", value)
        }
    }

    private func formatNumber(_ value: Double?, decimals: Int = 2) -> String {
        guard let value = value else { return "N/A" }
        return String(format: "%.\(decimals)f", value)
    }

    private func formatPercentage(_ value: Double?) -> String {
        guard let value = value else { return "N/A" }
        return String(format: "%.2f%%", value * 100) // assuming backend sends decimal like 0.15
    }

    private func formatLargeNumber(_ value: Double?) -> String {
        guard let value = value else { return "N/A" }
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: value)) ?? "N/A"
    }

    private func formatInt(from value: String?) -> String {
        guard let value = value, let intValue = Int(value) else { return "N/A" }
        return NumberFormatter.localizedString(from: NSNumber(value: intValue), number: .decimal)
    }
    
    private func formatShares(_ shares: String?) -> String {
        guard let shares = shares, shares != "N/A", let sharesValue = Double(shares) else { return "N/A" }
        
        let crore: Double = 10_000_000
        if sharesValue >= crore {
            return String(format: "%.2f Cr", sharesValue / crore)
        } else if sharesValue >= 1_000_000 {
            return String(format: "%.2f M", sharesValue / 1_000_000)
        } else if sharesValue >= 1_000 {
            return String(format: "%.2f K", sharesValue / 1_000)
        } else {
            return String(format: "%.0f", sharesValue)
        }
    }
    
    private func extractPercentageFromString(_ string: String?) -> Double {
        guard let string = string, string != "N/A" else { return 0 }
        let cleanedString = string.replacingOccurrences(of: "%", with: "")
        return Double(cleanedString) ?? 0
    }
}
