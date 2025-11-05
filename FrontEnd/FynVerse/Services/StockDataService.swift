import Foundation

class StockDataService {
    static let shared = StockDataService()
    private init() {}

    private let urlString = "http://192.168.1.9:8000/allstocks" // FastAPI URL

    func fetchStocks() async -> [StockModel] {
        guard let url = URL(string: urlString) else {
            print("❌ Invalid URL:", urlString)
            return []
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let stocks = try JSONDecoder().decode([StockModel].self, from: data)
            return stocks
        } catch {
            // ✅ Ignore "cancelled" error (-999)
            if let urlError = error as? URLError, urlError.code == .cancelled {
                print("⚠️ Request cancelled — safe to ignore.")
                return []
            }

            print("❌ Failed to fetch stocks:", error.localizedDescription)
            return []
        }
    }
}
