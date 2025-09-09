import Foundation

class StockDataService {
    static let shared = StockDataService()
    private init() {}

    private let urlString = "http://localhost:8000/allstocks" //  FastAPI URL

    func fetchStocks() async -> [StockModel] {
        guard let url = URL(string: urlString) else {
            print("Invalid URL:", urlString)
            return []
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let stocks = try JSONDecoder().decode([StockModel].self, from: data)
            return stocks
        } catch {
            print("❌ Failed to fetch stocks:", error)
            return []
        }
    }
}
