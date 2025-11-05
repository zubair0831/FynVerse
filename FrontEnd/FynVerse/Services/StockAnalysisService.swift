// StockAnalysisService.swift
// FynVerse
// Created by zubair ahmed

import Foundation

struct StockAnalysisService {
    
    static func fetchAnalysis(for symbol: String) async -> StockAnalysisResponse? {
        let urlString = "http://192.168.1.9:8000/stock/\(symbol)/analysis"
        guard let url = URL(string: urlString) else {
            print("❌ Invalid URL for symbol: \(symbol)")
            return nil
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ Invalid response type")
                return nil
            }
            
            guard httpResponse.statusCode == 200 else {
                print("❌ Server error: HTTP \(httpResponse.statusCode)")
                return nil
            }
            
            let decoder = JSONDecoder()
            let analysis = try decoder.decode(StockAnalysisResponse.self, from: data)
            print("✅ Successfully fetched analysis for \(symbol)")
            return analysis
            
        } catch let decodingError as DecodingError {
            switch decodingError {
            case .keyNotFound(let key, let context):
                print("❌ Missing key '\(key.stringValue)': \(context.debugDescription)")
            case .typeMismatch(let type, let context):
                print("❌ Type mismatch for type \(type): \(context.debugDescription)")
            case .valueNotFound(let type, let context):
                print("❌ Value not found for type \(type): \(context.debugDescription)")
            case .dataCorrupted(let context):
                print("❌ Data corrupted: \(context.debugDescription)")
            @unknown default:
                print("❌ Unknown decoding error: \(decodingError)")
            }
            return nil
        } catch {
            print("❌ Failed to fetch analysis: \(error.localizedDescription)")
            return nil
        }
    }
}
