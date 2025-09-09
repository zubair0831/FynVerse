//
//  SellDetailModel.swift
//  FynVerse
//
//  Created by zubair ahmed on 16/08/25.
//

import Foundation

struct SellDetail: Identifiable {
    var id: String {
        txn.id ?? "\(txn.stockSymbol.lowercased())-\(Int(txn.timestamp.dateValue().timeIntervalSince1970))"
    }
    let txn: DBTransaction
    let pnl: Double
    let avgCost: Double
    let matchedQty: Int
    let unmatchedQty: Int
}
