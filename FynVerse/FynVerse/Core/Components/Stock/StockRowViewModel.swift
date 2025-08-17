//
//  StockRowViewModel.swift
//  FynVerse
//
//  Created by zubair ahmed on 16/08/25.
//

import Foundation

@MainActor
class StockRowViewModel: ObservableObject {
    let stock: StockModel
    let portfolioStock: DBPortfolioStock?

    init(stock: StockModel, portfolioStock: DBPortfolioStock?) {
        self.stock = stock
        self.portfolioStock = portfolioStock
    }

    // MARK: - Computed Properties
    var currentHoldingValue: Double {
        guard let portfolio = portfolioStock else { return 0 }
        return stock.Last_Price * Double(portfolio.quantity)
    }
    
    var totalInvestment: Double {
        guard let portfolio = portfolioStock else { return 0 }
        return portfolio.avgBuyPrice * Double(portfolio.quantity)
    }

    var gainLoss: Double {
        return currentHoldingValue - totalInvestment
    }

    var gainLossPercentage: Double {
        guard totalInvestment != 0 else { return 0 }
        return (gainLoss / totalInvestment) * 100
    }
}
