//
//  StocksCacheService.swift
//  FynVerse
//
//  Created by zubair ahmed on 16/08/25.
//

//
//  StockCacheService.swift
//  FynVerse
//

import Foundation

struct StockCacheService {
    private static let allStocksKey = "all_stocks_cache"
    
    static func saveStocksToCache(_ stocks: [StockModel]) {
        do {
            let data = try JSONEncoder().encode(stocks)
            UserDefaults.standard.set(data, forKey: allStocksKey)
            print("💾 Stocks saved to cache.")
        } catch {
            print("❌ Failed to save stocks to cache: \(error)")
        }
    }

    static func loadStocksFromCache() -> [StockModel] {
        guard let data = UserDefaults.standard.data(forKey: allStocksKey) else { return [] }
        do {
            let decoded = try JSONDecoder().decode([StockModel].self, from: data)
            print("📦 Loaded \(decoded.count) stocks from cache.")
            return decoded
        } catch {
            print("❌ Failed to load stocks from cache: \(error)")
            return []
        }
    }
}
