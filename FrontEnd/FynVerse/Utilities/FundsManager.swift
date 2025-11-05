//
//  FundsManager.swift
//  FynVerse
//
//  Created by zubair ahmed on 10/09/25.
//

import Foundation
import SwiftUI

@MainActor
class FundsManager: ObservableObject {
    static let shared = FundsManager()
    
    @Published var availableFunds: Double = 0
    @Published var isLoading: Bool = false
    
    private let initialAmount: Double = 1_000_000 // 10 lakhs
    
    private init() {}
    
    func calculateAvailableFunds(from transactions: [DBTransaction]) {
        var currentFunds = initialAmount
        
        for txn in transactions {
            let amount = Double(txn.quantity) * txn.pricePerShare
            
            // Clean type and normalize
            let cleanedType = txn.transactionType
                .replacingOccurrences(of: "\u{00A0}", with: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .uppercased()
            
            switch cleanedType {
            case "BUY":
                currentFunds -= amount
            case "SELL":
                currentFunds += amount
            default:
                break
            }
        }
        
        availableFunds = max(0, currentFunds)
    }
    
    func canAfford(amount: Double) -> Bool {
        return availableFunds >= amount
    }
    
    func getUsedAmount() -> Double {
        return initialAmount - availableFunds
    }
    
    var fundsColor: Color {
        if availableFunds > 800_000 {
            return .green
        } else if availableFunds > 500_000 {
            return .orange
        } else {
            return .red
        }
    }
}
