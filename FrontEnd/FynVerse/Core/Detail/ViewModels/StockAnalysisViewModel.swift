// StockAnalysisViewModel.swift
// FynVerse
// Created by zubair ahmed

import Foundation

@MainActor
class StockAnalysisViewModel: ObservableObject {
    @Published var analysisResponse: StockAnalysisResponse?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let baseURL = "http://192.168.1.9:8000" // Update with your server URL
    
    func fetchAnalysis(for symbol: String) async {
        isLoading = true
        errorMessage = nil
        
        guard let url = URL(string: "\(baseURL)/stock/\(symbol)/analysis") else {
            errorMessage = "Invalid URL"
            isLoading = false
            return
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                errorMessage = "Invalid response from server"
                isLoading = false
                return
            }
            
            if httpResponse.statusCode == 200 {
                let decoder = JSONDecoder()
                let analysisData = try decoder.decode(StockAnalysisResponse.self, from: data)
                self.analysisResponse = analysisData
            } else if httpResponse.statusCode == 404 {
                errorMessage = "Stock \(symbol) not found"
            } else if httpResponse.statusCode == 500 {
                // Try to decode error message
                if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                    errorMessage = errorResponse.detail
                } else {
                    errorMessage = "Server error occurred"
                }
            } else {
                errorMessage = "Unexpected error: HTTP \(httpResponse.statusCode)"
            }
        } catch let decodingError as DecodingError {
            errorMessage = "Failed to parse analysis data: \(decodingError.localizedDescription)"
            print("Decoding error: \(decodingError)")
        } catch {
            errorMessage = "Network error: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
}

// Error response model
struct ErrorResponse: Codable {
    let detail: String
}
