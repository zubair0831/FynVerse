
import Foundation

@MainActor
class NewsViewModel: ObservableObject {
    @Published var newsItems: [NewsItem] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var hasError: Bool = false
    
    private let baseURL = "http://192.168.1.9:8000"
    
    func fetchNews(symbol: String) async {
        isLoading = true
        errorMessage = nil
        hasError = false
        
        guard let url = URL(string: "\(baseURL)/stock/\(symbol)/news?limit=20") else {
            await handleError("Invalid URL configuration")
            return
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                await handleError("Invalid response format")
                return
            }
            
            if httpResponse.statusCode != 200 {
                await handleError("Server returned status code: \(httpResponse.statusCode)")
                return
            }
            
            // Print raw JSON for debugging
            if let jsonString = String(data: data, encoding: .utf8) {
                print("Raw JSON Response: \(jsonString.prefix(500))...")
            }
            
            let decoder = JSONDecoder()
            // No special decoding strategy needed since we're using the exact field names
            
            let decodedResponse = try decoder.decode(StocksNewsResponse.self, from: data)
            
            await MainActor.run {
                self.newsItems = decodedResponse.news
                print("Successfully decoded \(self.newsItems.count) news items")
            }
            
        } catch let decodingError as DecodingError {
            print("Decoding error: \(decodingError)")
            await handleError("Failed to parse news data: \(decodingError.localizedDescription)")
        } catch {
            print("General error: \(error)")
            await handleError("Network error: \(error.localizedDescription)")
        }
        
        await MainActor.run {
            self.isLoading = false
        }
    }
    
    private func handleError(_ message: String) async {
        await MainActor.run {
            self.errorMessage = message
            self.hasError = true
            self.isLoading = false
        }
    }
    
    func retryFetch(symbol: String) {
        Task {
            await fetchNews(symbol: symbol)
        }
    }
}
