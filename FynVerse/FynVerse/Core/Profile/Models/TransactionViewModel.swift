//
//  TransactionViewModel.swift
//  FynVerse
//
//  Created by zubair ahmed on 16/08/25.
//

import Foundation
import FirebaseFirestore
import FirebaseAuth


// MARK: - ViewModel
@MainActor
class TransactionViewModel: ObservableObject {
    @Published var transactions: [DBTransaction] = []
    
    private let db = Firestore.firestore()
    
    func fetchTransactions() async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        
        do {
            let snapshot = try await db
                .collection("users")
                .document(uid)
                .collection("transactions")
                .order(by: "timestamp", descending: false)
                .getDocuments()
            
            let txns = snapshot.documents.compactMap { doc -> DBTransaction? in
                try? doc.data(as: DBTransaction.self)
            }
            
            
            self.transactions = txns
            
        } catch {
            
        }
    }

    
    
    
    /// Calculates PnL for all sell transactions using the FIFO method.
    /// It correctly handles short sells by assigning a zero cost basis to unmatched shares.
    var sellDetails: [SellDetail] {
        var details: [SellDetail] = []
        var queues: [String: [BuyLot]] = [:]
        
        // Sort all transactions by date to ensure FIFO order
        let allTxns = transactions.sorted { $0.timestamp.dateValue() < $1.timestamp.dateValue() }
        
        for txn in allTxns {
            let symbol = txn.stockSymbol.uppercased()
            let type = txn.transactionType
                .replacingOccurrences(of: "\u{00A0}", with: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
            
            if type.contains("buy") {
                queues[symbol, default: []].append(BuyLot(price: txn.pricePerShare, qty: txn.quantity))
                continue
            }
            
            if type.contains("sell") {
                var remaining = txn.quantity
                var matchedCost: Double = 0
                var matchedQty = 0
                
                var lots = queues[symbol] ?? []
                var i = 0
                
                while remaining > 0 && i < lots.count {
                    var lot = lots[i]
                    let use = min(remaining, lot.qty)
                    matchedCost += Double(use) * lot.price
                    matchedQty += use
                    lot.qty -= use
                    remaining -= use
                    
                    if lot.qty == 0 {
                        lots.remove(at: i)
                    } else {
                        lots[i] = lot
                        i += 1
                    }
                }
                
                let unmatchedQty = remaining
                // FIX: Cost of unmatched shares (short sell) is correctly set to 0.
                let totalCost = matchedCost
                let revenue   = Double(txn.quantity) * txn.pricePerShare
                let pnl       = revenue - totalCost
                
                let avgCost   = matchedQty > 0 ? matchedCost / Double(matchedQty) : 0
                
                details.append(
                    SellDetail(txn: txn, pnl: pnl, avgCost: avgCost, matchedQty: matchedQty, unmatchedQty: unmatchedQty)
                )
                
                queues[symbol] = lots
                continue
            }
            
            // This case should ideally not be reached with proper data validation.
            print("⚠️ Unknown transaction type '\(type)' — skipping.")
        }
        
        return details
    }
    
    var sellDetailsNewestFirst: [SellDetail] {
        sellDetails.sorted { $0.txn.timestamp.dateValue() > $1.txn.timestamp.dateValue() }
    }
    
    var totalSellPnL: Double {
        sellDetails.reduce(0) { $0 + $1.pnl }
    }


}

