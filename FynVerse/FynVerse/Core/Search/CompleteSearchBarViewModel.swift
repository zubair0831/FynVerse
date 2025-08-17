//
//  CompleteSearchBarViewModel.swift
//  FynVerse
//
//  Created by zubair ahmed on 16/08/25.
//

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
            "percentChange": stock.Percent_Change,
            "timestamp": FieldValue.serverTimestamp()
        ]

        recentRef.document(stock.SYMBOL).setData(stockData) { [weak self] error in
            if let error = error {
                print("❌ Error saving search: \(error.localizedDescription)")
                return
            }

            // ✅ Run on MainActor to safely update @Published properties
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
                        let percentChange = data["percentChange"] as? Double
                    else {
                        return nil
                    }

                    return StockModel(
                        SYMBOL: symbol,
                        NAME_OF_COMPANY: name,
                        SERIES: data["SERIES"] as? String ?? "EQ",
                        FACE_VALUE: data["FACE_VALUE"] as? Int ?? 10,
                        Last_Price: lastPrice,
                        Previous_Close: data["Previous_Close"] as? Double ?? lastPrice,
                        P_L: data["P_L"] as? Double ?? 0.0,
                        Percent_Change: percentChange
                    )
                } ?? []
                
                // ✅ Update main actor
                Task { @MainActor in
                    self?.recentStocks = stocks
                }
            }
    }

}
