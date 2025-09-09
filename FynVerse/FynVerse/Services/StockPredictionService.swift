//
//  StockPredictionService.swift
//  FynVerse
//
//  Created by zubair ahmed on 16/08/25.
//

//
//  StockPredictionService.swift
//  FynVerse
//
//  Created by zubair ahmed on 16/08/25.
//

import Foundation

struct StockPredictionService {
    
    static func fetchNext5D(stockSymbol: String) async -> Next5Dpred? {
        let urlString = "http://localhost:8000/prediction5d?ticker=\(stockSymbol).NS"
        guard let url = URL(string: urlString) else { return nil }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            return try JSONDecoder().decode(Next5Dpred.self, from: data)
        } catch {
            print("❌ Failed to fetch 5D prediction:", error)
            return nil
        }
    }
    
    
}

