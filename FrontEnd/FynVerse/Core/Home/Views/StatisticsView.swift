import SwiftUI

// MARK: - Market Index Model
struct MarketIndex: Identifiable, Codable {
    let id = UUID()
    let symbol: String
    let name: String
    let price: Double
    let change: Double
    let percentChange: Double
    let currency: String
    
    enum CodingKeys: String, CodingKey {
        case symbol, name, price, change, percentChange, currency
    }
}

// NOTE: StockModel, StatisticsModel, and AuthViewModel are assumed to exist in the consuming environment.
// For demonstration, we will assume their existence and focus on the UI and data logic provided.

struct CompactStatisticsView: View {
    let nifty50: StockModel?
    @State private var marketData: [MarketIndex] = []
    @State private var isLoading = false
    @State private var lastUpdated: Date = Date()
    @ObservedObject var authvm: AuthViewModel // Assumed to be available
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // MARK: - Header with Time
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.caption)
                        .foregroundStyle(Color.theme.accent)
                    
                    Text("Market Overview")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.theme.accent)
                }
                
                Spacer()
                
                HStack(spacing: 6) {
                    if isLoading {
                        ProgressView()
                            .scaleEffect(0.7)
                            .tint(Color.theme.secondary)
                    }
                    
                    Image(systemName: "clock")
                        .font(.caption2)
                        .foregroundStyle(Color.theme.secondary)
                    
                    Text(lastUpdated, formatter: compactTimeFormatter)
                        .font(.caption2)
                        .foregroundStyle(Color.theme.secondary)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            
            // MARK: - Enhanced Horizontal Scroll
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) { // Reduced spacing slightly
                    // Custom NIFTY 50 card if available
                    if let stock = nifty50 {
                        NavigationLink(destination: DetailView(stock: nifty50, DBStock: nil, authViewModel: authvm)) {
                            EnhancedStatCardView(stat: StatisticsModel(
                                title: stock.SYMBOL,
                                value: stock.Last_Price.asNumberString(),
                                percentChange: stock.Percent_Change
                            ))
                        }
                        .buttonStyle(.plain)
                    }
                    
                    // Live market data cards
                    ForEach(marketData) { index in
                        EnhancedMarketIndexCardView(marketIndex: index)
                    }
                    
                    // Enhanced refresh button
                    EnhancedRefreshButtonView {
                        await fetchMarketData()
                    }
                }
                .padding(.horizontal, 20)
            }
        }
        .frame(maxHeight: 160) // Reduced Max Height for the whole section
        .task {
            await fetchMarketData()
        }
        .refreshable {
            await fetchMarketData()
        }
    }
    
    // MARK: - Fetch Market Data
    private func fetchMarketData() async {
        isLoading = true
        
        let marketDataService = CompactMarketDataService()
        let fetchedData = await marketDataService.fetchMarketIndices()
        
        await MainActor.run {
            self.marketData = fetchedData
            self.lastUpdated = Date()
            self.isLoading = false
        }
    }
}

// MARK: - Compact Market Data Service (No changes needed here)
class CompactMarketDataService {
    private let baseURL = "https://query1.finance.yahoo.com/v8/finance/chart/"
    private let exchangeRates = ExchangeRateService()
    
    func fetchMarketIndices() async -> [MarketIndex] {
        let symbols = [
            ("^NSEI", "NIFTY 50", "INR"),
            ("^BSESN", "SENSEX", "INR"),
            ("^IXIC", "NASDAQ", "USD"),
            ("^GSPC", "S&P 500", "USD"),
            ("^DJI", "DOW JONES", "USD"),
            ("GC=F", "GOLD", "INR"),
            ("SI=F", "SILVER", "INR"),
            ("CL=F", "CRUDE OIL", "USD"),
            ("BTC-USD", "BITCOIN", "USD"),
            ("ETH-USD", "ETHEREUM", "USD")
        ]
        
        let usdToInr = await exchangeRates.getUSDToINRRate()
        
        var marketData: [MarketIndex] = []
        
        await withTaskGroup(of: MarketIndex?.self) { group in
            for (symbol, name, currency) in symbols {
                group.addTask {
                    await self.fetchSingleIndex(symbol: symbol, name: name, currency: currency, usdToInr: usdToInr)
                }
            }
            
            for await result in group {
                if let index = result {
                    marketData.append(index)
                }
            }
        }
        
        return marketData
    }
    
    private func fetchSingleIndex(symbol: String, name: String, currency: String, usdToInr: Double) async -> MarketIndex? {
        guard let url = URL(string: "\(baseURL)\(symbol)?interval=1d&range=5d") else {
            return nil
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let chart = json["chart"] as? [String: Any],
               let result = chart["result"] as? [[String: Any]],
               let firstResult = result.first,
               let meta = firstResult["meta"] as? [String: Any],
               let _ = firstResult["timestamp"] as? [Double],
               let indicators = firstResult["indicators"] as? [String: Any],
               let quote = indicators["quote"] as? [[String: Any]],
               let firstQuote = quote.first,
               let closes = firstQuote["close"] as? [Double?] {
                
                let currentPrice = meta["regularMarketPrice"] as? Double ?? 0.0
                var previousClose = meta["previousClose"] as? Double ?? 0.0
                
                let validCloses = Array(closes.compactMap({ $0 }).suffix(5))
                if validCloses.count >= 2 {
                    previousClose = validCloses[validCloses.count - 2]
                }
                
                let change = currentPrice - previousClose
                let percentChange = previousClose != 0 ? (change / previousClose) * 100 : 0.0
                
                var finalPrice = currentPrice
                var finalChange = change
                if (symbol == "GC=F" || symbol == "SI=F") && currency == "INR" {
                    finalPrice = currentPrice * usdToInr
                    finalChange = change * usdToInr
                }
                
                return MarketIndex(
                    symbol: symbol,
                    name: name,
                    price: finalPrice,
                    change: finalChange,
                    percentChange: percentChange,
                    currency: currency
                )
            }
        } catch {
            print("Error fetching data for \(symbol): \(error)")
        }
        
        return nil
    }
}

// MARK: - Exchange Rate Service (No changes needed here)
class ExchangeRateService {
    func getUSDToINRRate() async -> Double {
        guard let url = URL(string: "https://query1.finance.yahoo.com/v8/finance/chart/USDINR=X?interval=1d&range=1d") else {
            return 83.0
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let chart = json["chart"] as? [String: Any],
               let result = chart["result"] as? [[String: Any]],
               let firstResult = result.first,
               let meta = firstResult["meta"] as? [String: Any],
               let rate = meta["regularMarketPrice"] as? Double {
                return rate
            }
        } catch {
            print("Error fetching exchange rate: \(error)")
        }
        
        return 83.0
    }
}

// MARK: - Enhanced Market Index Card View (Smaller Frame, Adjusted Fonts)
struct EnhancedMarketIndexCardView: View {
    let marketIndex: MarketIndex
    
    // Use vibrant gradient from theme
    private var cardGradient: LinearGradient {
        Color.theme.cardGradient1
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header with icon
            HStack {
                Text(marketIndex.name)
                    .font(.system(size: 12, weight: .semibold)) // Reduced font size
                    .foregroundStyle(.white)
                    .lineLimit(1)
                
                Spacer()
                
                Image(systemName: getIconForIndex())
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.8))
            }
            
            Spacer()
            
            // Price
            Text(formatPrice())
                .font(.system(size: 18, weight: .bold)) // Reduced font size
                .foregroundStyle(.white)
                .lineLimit(1)
            
            // Change indicator - uses the now much brighter positive color
            HStack(spacing: 4) {
                Image(systemName: marketIndex.percentChange >= 0 ? "arrow.up.right" : "arrow.down.right")
                    .font(.caption2)
                    .fontWeight(.bold)
                
                Text(marketIndex.percentChange.asPercentString())
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundStyle(marketIndex.percentChange >= 0 ? Color.theme.success : Color.theme.red)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(.white.opacity(0.75))
            )
        }
        .padding(14) // Reduced padding
        .frame(width: 145, height: 110) // Reduced frame size
        .background(
            RoundedRectangle(cornerRadius: 16) // Slightly smaller radius
                .fill(cardGradient)
                .shadow(color: Color.theme.accent.opacity(0.4), radius: 8, x: 0, y: 4) // Reduced shadow
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(.white.opacity(0.15), lineWidth: 1)
        )
    }
    
    private func formatPrice() -> String {
        let currencySymbol = marketIndex.currency == "INR" ? "₹" : "$"
        
        if marketIndex.price > 10000 {
            return "\(currencySymbol)\(String(format: "%.0f", marketIndex.price))"
        } else if marketIndex.price > 1000 {
            return "\(currencySymbol)\(String(format: "%.1f", marketIndex.price))"
        } else {
            return "\(currencySymbol)\(String(format: "%.2f", marketIndex.price))"
        }
    }
    
    private func getIconForIndex() -> String {
        switch marketIndex.symbol {
        case "^NSEI", "^BSESN": return "chart.bar.fill"
        case "^IXIC", "^GSPC", "^DJI": return "globe.americas.fill"
        case "GC=F": return "circle.fill"
        case "SI=F": return "moon.fill"
        case "CL=F": return "drop.fill"
        case "BTC-USD", "ETH-USD": return "bitcoinsign.circle.fill"
        default: return "chart.line.uptrend.xyaxis"
        }
    }
}

// MARK: - Enhanced Refresh Button (Smaller Frame)
struct EnhancedRefreshButtonView: View {
    let action: () async -> Void
    @State private var isRefreshing = false
    
    var body: some View {
        Button {
            Task {
                isRefreshing = true
                await action()
                try? await Task.sleep(nanoseconds: 500_000_000)
                isRefreshing = false
            }
        } label: {
            VStack(spacing: 8) { // Reduced spacing
                ZStack {
                    Circle()
                        .fill(.white.opacity(0.2)) // Slightly less opaque
                        .frame(width: 40, height: 40) // Reduced size
                    
                    if isRefreshing {
                        ProgressView()
                            .tint(.white)
                            .scaleEffect(0.9)
                    } else {
                        Image(systemName: "arrow.clockwise")
                            .font(.body) // Reduced size
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                    }
                }
                
                Text("Refresh")
                    .font(.caption2) // Reduced font size
                    .fontWeight(.medium)
                    .foregroundStyle(.white)
            }
            .padding(14) // Reduced padding
            .frame(width: 95, height: 110) // Reduced frame size
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.theme.accent.opacity(0.7),
                                Color.theme.accent.opacity(0.5)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: Color.theme.accent.opacity(0.3), radius: 8, x: 0, y: 4)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(.white.opacity(0.2), lineWidth: 1)
            )
        }
        .disabled(isRefreshing)
    }
}

// MARK: - Enhanced Stat Card View (NIFTY 50 - Smaller Frame, Adjusted Fonts)
struct EnhancedStatCardView: View {
    let stat: StatisticsModel
    
    // Special gradient for NIFTY 50 - use the vibrant cardGradient2
    private var cardGradient: LinearGradient {
        Color.theme.cardGradient2
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                ZStack {
                    Circle()
                        .fill(.white.opacity(0.25))
                        .frame(width: 20, height: 20) // Reduced size
                    
                    Image(systemName: "star.fill")
                        .font(.system(size: 8)) // Reduced size
                        .foregroundStyle(.yellow)
                }
                
                Text(stat.title)
                    .font(.system(size: 12, weight: .semibold)) // Reduced font size
                    .foregroundStyle(.white)
                    .lineLimit(1)
                
                Spacer()
                
                Image(systemName: "chart.bar.fill")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.8))
            }
            
            Spacer()
            
            // Price
            Text("₹" + stat.value)
                .font(.system(size: 18, weight: .bold)) // Reduced font size
                .foregroundStyle(.white)
                .lineLimit(1)
            
            // Change indicator - uses the now much brighter positive color
            HStack(spacing: 4) {
                Image(systemName: stat.percentChange >= 0 ? "arrow.up.right" : "arrow.down.right")
                    .font(.caption2)
                    .fontWeight(.bold)
                
                Text(stat.percentChange.asPercentString())
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundStyle(stat.percentChange >= 0 ? Color.theme.success : Color.theme.red)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(.white.opacity(0.25))
            )
        }
        .padding(14) // Reduced padding
        .frame(width: 145, height: 110) // Reduced frame size
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(cardGradient)
                .shadow(color: Color.theme.success.opacity(0.4), radius: 8, x: 0, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(.white.opacity(0.15), lineWidth: 1)
        )
    }
}

// MARK: - Compact Date Formatter (No changes needed here)
private let compactTimeFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "HH:mm"
    return formatter
}()
