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
    
    // Helper function to clear old incompatible data
    func clearOldSearches() {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        let db = Firestore.firestore()
        let recentRef = db.collection("users").document(userId).collection("recentSearches")
        
        recentRef.getDocuments { snapshot, _ in
            guard let docs = snapshot?.documents else { return }
            print("🗑️ Clearing \(docs.count) old searches with incompatible format")
            for doc in docs {
                recentRef.document(doc.documentID).delete()
            }
            Task { @MainActor in
                self.recentStocks = []
                print("✅ Old searches cleared. New searches will use correct format.")
            }
        }
    }
    
    func saveRecentSearch(stock: StockModel) {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        let db = Firestore.firestore()
        let recentRef = db.collection("users").document(userId).collection("recentSearches")
        
        // ✅ FIXED: Use field names with SPACES (matching StockModel's CodingKeys exactly)
        let stockData: [String: Any] = [
            "SYMBOL": stock.SYMBOL,
            "NAME OF COMPANY": stock.NAME_OF_COMPANY,  // ✅ Spaces!
            "Last Price": stock.Last_Price,
            "Previous Close": stock.Previous_Close,
            "Open": stock.Open ?? 0.0,
            "High": stock.High ?? 0.0,
            "Low": stock.Low ?? 0.0,
            "Volume": stock.Volume ?? 0,
            "MarketCap": stock.MarketCap,
            "YahooSymbol": stock.YahooSymbol,
            "Percent Change": stock.Percent_Change,
            "P&L": stock.P_L,  // ✅ Ampersand!
            "SERIES": stock.SERIES,
            "FACE VALUE": stock.FACE_VALUE,
            "timestamp": FieldValue.serverTimestamp()
        ]
        
        recentRef.document(stock.SYMBOL).setData(stockData) { [weak self] error in
            if let error = error {
                print("❌ Error saving search: \(error.localizedDescription)")
                return
            }
            
            print("✅ Successfully saved recent search: \(stock.SYMBOL)")
            
            Task { @MainActor in
                self?.pruneOldSearches()
                // Small delay to let Firestore sync timestamp
                try? await Task.sleep(nanoseconds: 500_000_000)
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
                print("🗑️ Pruning \(docs.count - 10) old searches")
                for doc in docs.dropFirst(10) {
                    recentRef.document(doc.documentID).delete()
                }
            }
        }
    }
    
    private func loadRecentSearches() {
        guard let userId = Auth.auth().currentUser?.uid else {
            print("❌ No user logged in")
            return
        }
        
        let db = Firestore.firestore()
        
        print("📥 Loading recent searches...")
        
        db.collection("users")
            .document(userId)
            .collection("recentSearches")
            .order(by: "timestamp", descending: true)
            .limit(to: 10)
            .getDocuments { [weak self] snapshot, error in
                
                if let error = error {
                    print("❌ Error loading recent searches: \(error.localizedDescription)")
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    print("⚠️ No documents in snapshot")
                    return
                }
                
                print("📄 Found \(documents.count) recent search documents")
                
                // ✅ FIX: Use the corrected custom initializer
                let stocks: [StockModel] = documents.compactMap { doc in
                    let data = doc.data()
                    print("🔍 Processing document: \(doc.documentID)")
                    
                    let stock = StockModel(documentData: data)
                    if stock == nil {
                        print("❌ Failed to decode: \(doc.documentID)")
                        print("   Data keys: \(data.keys.sorted())")
                    } else {
                        print("✅ Successfully decoded: \(stock!.SYMBOL)")
                    }
                    return stock
                }
                
                Task { @MainActor in
                    self?.recentStocks = stocks
                    print("✅ Loaded \(stocks.count) recent stocks into UI")
                }
            }
    }
}

extension StockModel {
    
    // ✅ FIXED: Custom initializer that handles BOTH old and new key formats
    init?(documentData data: [String: Any]) {
        var mutableData = data
        
        // Remove timestamp field (not needed for StockModel)
        mutableData.removeValue(forKey: "timestamp")
        
        // 🔄 MAP OLD LOWERCASE KEYS TO NEW KEYS (matching StockModel's CodingKeys EXACTLY)
        // The decoder expects keys with SPACES like "NAME OF COMPANY", not underscores
        let keyMappings: [(old: String, new: String)] = [
            ("symbol", "SYMBOL"),
            ("name", "NAME OF COMPANY"),  // ✅ Space, not underscore!
            ("lastPrice", "Last Price"),  // ✅ Space, not underscore!
            ("previousClose", "Previous Close"),  // ✅ Space, not underscore!
            ("open", "Open"),
            ("high", "High"),
            ("low", "Low"),
            ("volume", "Volume"),
            ("marketCap", "MarketCap"),
            ("percentChange", "Percent Change")  // ✅ Space, not underscore!
        ]
        
        // Convert old keys to new keys
        for (oldKey, newKey) in keyMappings {
            if let value = mutableData[oldKey] {
                mutableData[newKey] = value
                mutableData.removeValue(forKey: oldKey)
            }
        }
        
        // Also handle if keys already use underscores (from new saves)
        if let name = mutableData["NAME_OF_COMPANY"] {
            mutableData["NAME OF COMPANY"] = name
            mutableData.removeValue(forKey: "NAME_OF_COMPANY")
        }
        if let lastPrice = mutableData["Last_Price"] {
            mutableData["Last Price"] = lastPrice
            mutableData.removeValue(forKey: "Last_Price")
        }
        if let prevClose = mutableData["Previous_Close"] {
            mutableData["Previous Close"] = prevClose
            mutableData.removeValue(forKey: "Previous_Close")
        }
        if let pctChange = mutableData["Percent_Change"] {
            mutableData["Percent Change"] = pctChange
            mutableData.removeValue(forKey: "Percent_Change")
        }
        // ✅ FIX: P&L uses ampersand, not space or underscore!
        if let pl = mutableData["P_L"] {
            mutableData["P&L"] = pl
            mutableData.removeValue(forKey: "P_L")
        }
        if let pl = mutableData["P L"] {
            mutableData["P&L"] = pl
            mutableData.removeValue(forKey: "P L")
        }
        if let faceValue = mutableData["FACE_VALUE"] {
            mutableData["FACE VALUE"] = faceValue
            mutableData.removeValue(forKey: "FACE_VALUE")
        }
        
        // Set default values for ALL missing fields (some docs are incomplete)
        if mutableData["Open"] == nil { mutableData["Open"] = 0.0 }
        if mutableData["High"] == nil { mutableData["High"] = 0.0 }
        if mutableData["Low"] == nil { mutableData["Low"] = 0.0 }
        if mutableData["Volume"] == nil { mutableData["Volume"] = 0 }
        if mutableData["MarketCap"] == nil { mutableData["MarketCap"] = 0.0 }
        if mutableData["Previous Close"] == nil { mutableData["Previous Close"] = 0.0 }
        if mutableData["YahooSymbol"] == nil { mutableData["YahooSymbol"] = "" }
        if mutableData["P&L"] == nil { mutableData["P&L"] = 0.0 }
        if mutableData["SERIES"] == nil { mutableData["SERIES"] = "EQ" }
        if mutableData["FACE VALUE"] == nil { mutableData["FACE VALUE"] = 0.0 }
        
        // Convert dictionary to JSON Data
        guard let jsonData = try? JSONSerialization.data(withJSONObject: mutableData) else {
            print("❌ Failed to serialize dictionary to JSON")
            print("   Keys: \(data.keys.sorted())")
            return nil
        }
        
        // Decode using JSONDecoder
        let decoder = JSONDecoder()
        do {
            self = try decoder.decode(StockModel.self, from: jsonData)
            print("✅ Successfully decoded stock with mapped keys")
        } catch {
            print("❌ Decoding Error for StockModel:")
            print("   \(error)")
            print("   Available keys after mapping: \(mutableData.keys.sorted())")
            if let decodingError = error as? DecodingError {
                switch decodingError {
                case .keyNotFound(let key, _):
                    print("   Missing key: \(key.stringValue)")
                case .typeMismatch(let type, let context):
                    print("   Type mismatch for: \(type)")
                    print("   At path: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))")
                case .valueNotFound(let type, _):
                    print("   Value not found for: \(type)")
                case .dataCorrupted(let context):
                    print("   Data corrupted: \(context.debugDescription)")
                @unknown default:
                    print("   Unknown decoding error")
                }
            }
            return nil
        }
    }
}
