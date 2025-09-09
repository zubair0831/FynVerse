import Foundation

class HistoricDataService {
    static let shared = HistoricDataService()
    private init() {}

    func fetchHistoricalPrices(symbol: String, interval: String = "1d", range: String = "1mo") async -> [HistoricPriceModel] {
        let urlString = "https://query1.finance.yahoo.com/v8/finance/chart/\(symbol)?interval=\(interval)&range=\(range)"
        
        guard let url = URL(string: urlString) else {
            print("❌ Invalid URL")
            return []
        }

        var request = URLRequest(url: url)
        request.setValue("text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8", forHTTPHeaderField: "Accept")
        request.setValue("en-US,en;q=0.5", forHTTPHeaderField: "Accept-Language")
        request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
        request.setValue("https://finance.yahoo.com", forHTTPHeaderField: "Referer")

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let decoded = try JSONDecoder().decode(HistoricalChartResponse.self, from: data)

            guard let result = decoded.chart.result.first,
                  let timestamps = result.timestamp,
                  let quote = result.indicators.quote.first else {
                print("❌ Missing data in response")
                return []
            }

            var historicalData: [HistoricPriceModel] = []

            for i in 0..<timestamps.count {
                if i < quote.open.count,
                   let o = quote.open[i],
                   let h = quote.high[i],
                   let l = quote.low[i],
                   let c = quote.close[i],
                   let v = quote.volume[i] {
                    let date = Date(timeIntervalSince1970: TimeInterval(timestamps[i]))
                    let item = HistoricPriceModel(date: date, open: o, high: h, low: l, close: c, volume: v)
                    historicalData.append(item)
                }
            }

            return historicalData

        } catch {
            print("❌ Error fetching historical data: \(error)")
            return []
        }
    }
}
