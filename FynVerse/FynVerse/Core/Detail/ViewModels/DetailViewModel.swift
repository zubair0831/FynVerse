//
//  DetailViewModel.swift
//  FynVerse
//
//  Created by zubair ahmed on 16/08/25.
//

import SwiftUI

@MainActor
class DetailViewModel: ObservableObject {
    let stock: StockModel?
    let DBStock: DBPortfolioStock?
    let authViewModel: AuthViewModel
    
    @Published var selectedTab = 0
    @Published var showMoreOverview = false
    @Published var showMoreDetails = false
    @Published var showBuySheet = false
    @Published var showSellSheet = false
    
    @Published var predictionVM = StockPredictionViewModel()
    
    init(stock: StockModel?, DBStock: DBPortfolioStock?, authViewModel: AuthViewModel) {
        self.stock = stock
        self.DBStock = DBStock
        self.authViewModel = authViewModel
    }
    
    func fetchPredictions() async {
        guard let stock = stock else { return }
        await predictionVM.fetchPredictions(for: stock.SYMBOL)
    }
    
    // MARK: Helpers
    func overviewInfo() -> [(String, String)] {
        [
            ("Symbol", stock?.SYMBOL ?? "-"),
            ("Last Price", stock?.Last_Price.asCurrencywith6Decimals() ?? "-"),
            ("Change %", stock?.Percent_Change.asPercentString() ?? "-"),
            ("Previous Close", stock?.Previous_Close.asCurrencywith6Decimals() ?? "-"),
            ("Change", stock?.P_L.asCurrencywith6Decimals() ?? "-")
        ]
    }

    func additionalInfo() -> [(String, String)] {
        [
            ("PE Ratio", predictionVM.longShortPrediction?.metadata.lastPE.asNumberString() ?? ""),
            ("PB Ratio", predictionVM.longShortPrediction?.metadata.lastPb.asNumberString() ?? ""),
            ("Face Value", "\(stock?.FACE_VALUE ?? 0)"),
            ("Series", stock?.SERIES ?? "")
        ]
    }
}
