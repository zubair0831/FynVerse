import Foundation
import FirebaseFirestore
import FirebaseAuth

@MainActor
class CompleteSearchBarViewModel: ObservableObject {
    @Published var localSearchText: String = ""
    @Published var recentStocks: [StockModel] = []
    @Published var hasLoadedOnce: Bool = false
    
    private let homeVM: HomeViewModel
    
    init(homeVM: HomeViewModel) {
        self.homeVM = homeVM
    }
    
    var filteredStocks: [StockModel] {
        homeVM.allStocks.filter { stock in
            localSearchText.isEmpty ||
            stock.SYMBOL.localizedCaseInsensitiveContains(localSearchText) ||
            stock.NAME_OF_COMPANY.localizedCaseInsensitiveContains(localSearchText)
        }
    }
    
    func onAppear() {
        if !hasLoadedOnce {
            loadRecentSearches()
            hasLoadedOnce = true
        }
    }
    
    func saveRecentSearch(stock: StockModel) {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        let db = Firestore.firestore()
        let recentRef = db.collection("users").document(userId).collection("recentSearches")

        let stockData: [String: Any] = [
            "symbol": stock.SYMBOL,
            "name": stock.NAME_OF_COMPANY,
            "lastPrice": stock.Last_Price,
            "previousClose": stock.Previous_Close,
            "open": stock.Open,
            "high": stock.High,
            "low": stock.Low,
            "volume": stock.Volume,
            "marketCap": stock.MarketCap,
            "YahooSymbol": stock.YahooSymbol,
            "percentChange": stock.Percent_Change,
            "P_L": stock.P_L,
            "SERIES": stock.SERIES,
            "FACE_VALUE": stock.FACE_VALUE,
            "timestamp": FieldValue.serverTimestamp()
        ]

        recentRef.document(stock.SYMBOL).setData(stockData) { [weak self] error in
            if let error = error {
                print("❌ Error saving search: \(error.localizedDescription)")
                return
            }

            Task { @MainActor in
                self?.pruneOldSearches()
                self?.loadRecentSearches()
            }
        }
    }

    private func pruneOldSearches() {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        let db = Firestore.firestore()
        let recentRef = db.collection("users").document(userId).collection("recentSearches")

        recentRef.order(by: "timestamp", descending: true).getDocuments { snapshot, _ in
            guard let docs = snapshot?.documents else { return }
            if docs.count > 10 {
                for doc in docs.dropFirst(10) {
                    recentRef.document(doc.documentID).delete()
                }
            }
            Task { @MainActor in
                self.loadRecentSearches()
            }
        }
    }
    
    private func loadRecentSearches() {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        let db = Firestore.firestore()

        db.collection("users")
            .document(userId)
            .collection("recentSearches")
            .order(by: "timestamp", descending: true)
            .limit(to: 10)
            .getDocuments { [weak self] snapshot, error in
                if let error = error {
                    print("❌ Error loading recent searches: \(error)")
                    return
                }
                
                let stocks: [StockModel] = snapshot?.documents.compactMap { doc in
                    let data = doc.data()

                    guard
                        let symbol = data["symbol"] as? String,
                        let name = data["name"] as? String,
                        let lastPrice = data["lastPrice"] as? Double,
                        let previousClose = data["previousClose"] as? Double,
                        let open = data["open"] as? Double,
                        let high = data["high"] as? Double,
                        let low = data["low"] as? Double,
                        let volume = data["volume"] as? Int,
                        let marketCap = data["marketCap"] as? Double,
                        let yahooSymbol = data["YahooSymbol"] as? String,
                        let percentChange = data["percentChange"] as? Double,
                        let p_l = data["P_L"] as? Double,
                        let series = data["SERIES"] as? String,
                        let faceValue = data["FACE_VALUE"] as? Int
                    else {
                        return nil
                    }

                    return StockModel(
                        SYMBOL: symbol,
                        NAME_OF_COMPANY: name,
                        SERIES: series,
                        FACE_VALUE: faceValue,
                        YahooSymbol: yahooSymbol,
                        Open: open,
                        High: high,
                        Low: low,
                        Last_Price: lastPrice,
                        Previous_Close: previousClose,
                        Volume: volume,
                        MarketCap: marketCap,
                        P_L: p_l,
                        Percent_Change: percentChange
                    )
                } ?? []
                
                Task { @MainActor in
                    self?.recentStocks = stocks
                }
            }
    }
}
