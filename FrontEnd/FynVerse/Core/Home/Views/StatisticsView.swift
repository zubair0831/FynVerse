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



struct CompactStatisticsView: View {
    let nifty50: StockModel?
    @State private var marketData: [MarketIndex] = []
    @State private var isLoading = false
    @State private var lastUpdated: Date = Date()
    @ObservedObject var authvm: AuthViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // MARK: - Compact Header
            HStack {
                Text("Market Overview")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                HStack(spacing: 8) {
                    if isLoading {
                        ProgressView()
                            .scaleEffect(0.7)
                    }
                    
                    Text(lastUpdated, formatter: compactTimeFormatter)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 16)
            
            // MARK: - Compact Horizontal Scroll
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    // Custom NIFTY 50 card if available
                    if let stock = nifty50 {
                        NavigationLink(destination: DetailView(stock: nifty50, DBStock: nil, authViewModel: authvm)) {
                            CompactStatCardView(stat: StatisticsModel(
                                title: stock.SYMBOL,
                                value: stock.Last_Price.asNumberString(),
                                percentChange: stock.Percent_Change
                            ))
                        }
                    }
                    
                    // Live market data cards
                    ForEach(marketData) { index in
                        CompactMarketIndexCardView(marketIndex: index)
                    }
                    
                    // Compact refresh button
                    CompactRefreshButtonView {
                        await fetchMarketData()
                    }
                }
                .padding(.horizontal, 16)
            }
        }
        .frame(maxHeight: 120) // Limit the height to ~10-15% of screen
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

// MARK: - Compact Market Data Service
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
            ("GC=F", "GOLD", "INR"), // Convert to INR
            ("SI=F", "SILVER", "INR"), // Convert to INR
            ("CL=F", "CRUDE OIL", "USD"),
            ("BTC-USD", "BITCOIN", "USD"),
            ("ETH-USD", "ETHEREUM", "USD")
        ]
        
        // Get USD to INR rate
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
               let timestamps = firstResult["timestamp"] as? [Double],
               let indicators = firstResult["indicators"] as? [String: Any],
               let quote = indicators["quote"] as? [[String: Any]],
               let firstQuote = quote.first,
               let closes = firstQuote["close"] as? [Double?] {
                
                let currentPrice = meta["regularMarketPrice"] as? Double ?? 0.0
                
                // Get previous trading day's close price for proper calculation
                var previousClose = meta["previousClose"] as? Double ?? 0.0
                
                // Find the most recent valid close price from historical data
                let validCloses = Array(closes.compactMap({ $0 }).suffix(5))
                if validCloses.count >= 2 {
                    previousClose = validCloses[validCloses.count - 2] // Previous day's close
                }
                
                let change = currentPrice - previousClose
                let percentChange = previousClose != 0 ? (change / previousClose) * 100 : 0.0
                
                // Convert prices for gold and silver to INR
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

// MARK: - Exchange Rate Service
class ExchangeRateService {
    func getUSDToINRRate() async -> Double {
        guard let url = URL(string: "https://query1.finance.yahoo.com/v8/finance/chart/USDINR=X?interval=1d&range=1d") else {
            return 83.0 // Fallback rate
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
        
        return 83.0 // Fallback rate
    }
}

// MARK: - Compact Market Index Card View
struct CompactMarketIndexCardView: View {
    let marketIndex: MarketIndex
    
    private let cardGradient = LinearGradient(
        colors: [Color(red: 0.1, green: 0.4, blue: 0.6), Color(red: 0.2, green: 0.6, blue: 0.8)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    private let lightGreen = Color(red: 0.2, green: 0.9, blue: 0.4)
    private let lightRed = Color(red: 0.9, green: 0.3, blue: 0.3)
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(marketIndex.name)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.8))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            
            Text(formatPrice())
                .font(.subheadline)
                .bold()
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.9)
            
            HStack(spacing: 2) {
                Image(systemName: "triangle.fill")
                    .font(.caption2)
                    .rotationEffect(.degrees(marketIndex.percentChange >= 0 ? 0 : 180))
                
                Text(marketIndex.percentChange.asPercentString())
                    .font(.caption2)
                    .bold()
            }
            .foregroundStyle(marketIndex.percentChange >= 0 ? lightGreen : lightRed)
        }
        .padding(10)
        .frame(width: 120, height: 80, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(cardGradient)
                .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
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
}

// MARK: - Compact Refresh Button
struct CompactRefreshButtonView: View {
    let action: () async -> Void
    @State private var isRefreshing = false
    
    var body: some View {
        Button {
            Task {
                isRefreshing = true
                await action()
                isRefreshing = false
            }
        } label: {
            VStack(spacing: 2) {
                if isRefreshing {
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "arrow.clockwise")
                        .font(.subheadline)
                        .foregroundStyle(.white)
                }
                
                Text("Refresh")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.8))
            }
            .padding(10)
            .frame(width: 70, height: 80)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.gray.opacity(0.4))
                    .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
            )
        }
        .disabled(isRefreshing)
    }
}

// MARK: - Compact Stat Card View
struct CompactStatCardView: View {
    let stat: StatisticsModel
    
    private let lightGreen = Color(red: 0.2, green: 0.8, blue: 0.4)
    private let lightRed = Color(red: 0.9, green: 0.3, blue: 0.3)
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(stat.title)
                .font(.caption2)
                .foregroundColor(.white.opacity(0.9))
                .lineLimit(1)
            
            Text("₹" + stat.value)
                .font(.subheadline)
                .bold()
                .foregroundColor(.white)
                .lineLimit(1)
            
            HStack(spacing: 2) {
                Image(systemName: "triangle.fill")
                    .font(.caption2)
                    .rotationEffect(.degrees(stat.percentChange >= 0 ? 0 : 180))
                Text(stat.percentChange.asPercentString())
                    .font(.caption2)
                    .bold()
            }
            .foregroundColor(stat.percentChange >= 0 ? lightGreen : lightRed)
        }
        .padding(8)
        .frame(width: 110, height: 70, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(LinearGradient(
                    colors: [Color.blue.opacity(0.8), Color.blue],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
        )
    }
}



// MARK: - Compact Date Formatter
private let compactTimeFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "HH:mm"
    return formatter
}()

