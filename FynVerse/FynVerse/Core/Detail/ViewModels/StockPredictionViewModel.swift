//
//  StockPredictionViewModel.swift
//  FynVerse
//
//  Created by zubair ahmed on 12/08/25.
//

import Foundation

@MainActor
class StockPredictionViewModel: ObservableObject {
    @Published var next5DPrediction: Next5Dpred?
    @Published var longShortPrediction: lonShortPred?
    @Published var isLoading: Bool = false
    @Published var animateSpinner: Bool = false
    
    func fetchPredictions(for symbol: String) async {
        isLoading = true
        animateSpinner = true
        
        async let next5D = StockPredictionService.fetchNext5D(stockSymbol: symbol)
        async let longShort = StockPredictionService.fetchLongShort(stockSymbol: symbol)
        
        self.next5DPrediction = await next5D
        self.longShortPrediction = await longShort
        
        isLoading = false
        animateSpinner = false
    }
}
