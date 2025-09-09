//
//  PortfolioService.swift
//  FynVerse
//
//  Created by zubair ahmed on 16/08/25.
//

//
//  PortfolioService.swift
//  FynVerse
//

import Foundation

struct PortfolioService {
    private let userManager = UserManager.shared
    
    func fetchPortfolioStocks(for userID: String) async throws -> [DBPortfolioStock] {
        try await userManager.getUserPortfolio(userID: userID)
    }
    
    func calculatePortfolioSummary(portfolioStocks: [DBPortfolioStock], allStocks: [StockModel]) -> (investment: Double, value: Double, gainLoss: Double) {
        guard !portfolioStocks.isEmpty, !allStocks.isEmpty else {
            return (0, 0, 0)
        }
        
        var totalInvestment: Double = 0.0
        var totalValue: Double = 0.0
        
        for portfolioStock in portfolioStocks {
            guard let currentStockData = allStocks.first(where: { $0.SYMBOL == portfolioStock.stockSymbol }) else {
                print("❌ Stock data not found for symbol: \(portfolioStock.stockSymbol)")
                continue
            }
            
            let investment = Double(portfolioStock.quantity) * portfolioStock.avgBuyPrice
            totalInvestment += investment
            
            let currentValue = Double(portfolioStock.quantity) * currentStockData.Last_Price
            totalValue += currentValue
        }
        
        return (totalInvestment, totalValue, totalValue - totalInvestment)
    }
}
