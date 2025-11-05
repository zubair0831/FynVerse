//  PortfolioRatingModel.swift
//  FynVerse
//
//  Enhanced with ML predictions support

import Foundation

// MARK: - Portfolio Analysis Request Models

struct PortfolioAnalysisRequest: Codable {
    let holdings: [PortfolioHoldingRequest]
}

struct PortfolioHoldingRequest: Codable {
    let symbol: String
    let quantity: Int
    let investedAmount: Double
    
    enum CodingKeys: String, CodingKey {
        case symbol
        case quantity
        case investedAmount = "invested_amount"
    }
}

// MARK: - Portfolio Analysis Response Models

struct PortfolioAnalysisResponse: Codable, Identifiable {
    var id: String { UUID().uuidString }
    let overall: OverallRating
    let scores: DetailedScores
    let metrics: PortfolioMetrics
    let distribution: Distribution
    let insights: [Insight]
    let recommendations: [String]
    let holdings: [AnalyzedHolding]?
    let mlInsights: MLInsights?
    
    enum CodingKeys: String, CodingKey {
        case overall, scores, metrics, distribution, insights, recommendations, holdings
        case mlInsights = "ml_insights"
    }
}

struct OverallRating: Codable {
    let score: Double
    let grade: String
    let assessment: String
    let totalValue: Double
    let holdingsCount: Int
    
    enum CodingKeys: String, CodingKey {
        case score, grade, assessment
        case totalValue = "total_value"
        case holdingsCount = "holdings_count"
    }
}

struct DetailedScores: Codable {
    let diversification: Double
    let peRating: Double
    let riskManagement: Double
    let allocationQuality: Double
    let marketCapMix: Double
    
    enum CodingKeys: String, CodingKey {
        case diversification
        case peRating = "pe_rating"
        case riskManagement = "risk_management"
        case allocationQuality = "allocation_quality"
        case marketCapMix = "market_cap_mix"
    }
}

struct PortfolioMetrics: Codable {
    let averagePE: Double?
    let averageBeta: Double?
    let sectorCount: Int
    let maxSectorWeight: Double
    let maxStockWeight: Double
    
    enum CodingKeys: String, CodingKey {
        case averagePE = "average_pe"
        case averageBeta = "average_beta"
        case sectorCount = "sector_count"
        case maxSectorWeight = "max_sector_weight"
        case maxStockWeight = "max_stock_weight"
    }
}

struct Distribution: Codable {
    let sectors: [String: Double]
    let marketCaps: [String: Double]
    
    enum CodingKeys: String, CodingKey {
        case sectors
        case marketCaps = "market_caps"
    }
    
    var topSectors: [(name: String, percentage: Double)] {
        sectors.sorted { $0.value > $1.value }
            .map { (name: $0.key, percentage: $0.value) }
    }
    
    var marketCapBreakdown: [(category: String, percentage: Double)] {
        marketCaps.sorted { $0.value > $1.value }
            .map { (category: $0.key, percentage: $0.value) }
    }
}

struct Insight: Codable, Identifiable {
    var id: String { "\(type)-\(category)-\(message.prefix(20))" }
    let type: String
    let category: String
    let message: String
    
    var isWarning: Bool { type == "warning" }
    var isPositive: Bool { type == "positive" }
    var isNeutral: Bool { type == "neutral" }
}

struct AnalyzedHolding: Codable, Identifiable {
    var id: String { symbol }
    let symbol: String
    let quantity: Int
    let investedAmount: Double
    let currentPrice: Double
    let currentValue: Double
    let gainLoss: Double
    let gainLossPct: Double
    let sector: String
    let peRatio: Double?
    let beta: Double?
    let marketCap: Double?
    let marketCapCategory: String
    
    enum CodingKeys: String, CodingKey {
        case symbol, quantity, sector, beta
        case investedAmount = "invested_amount"
        case currentPrice = "current_price"
        case currentValue = "current_value"
        case gainLoss = "gain_loss"
        case gainLossPct = "gain_loss_pct"
        case peRatio = "pe_ratio"
        case marketCap = "market_cap"
        case marketCapCategory = "market_cap_category"
    }
    
    var isProfitable: Bool { gainLoss > 0 }
    
    var formattedGainLoss: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "₹"
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: gainLoss)) ?? "₹0"
    }
}

// MARK: - ML Insights

struct MLInsights: Codable {
    let riskPrediction: RiskPrediction
    let anomalyDetection: AnomalyDetection
    
    enum CodingKeys: String, CodingKey {
        case riskPrediction = "risk_prediction"
        case anomalyDetection = "anomaly_detection"
    }
}

struct RiskPrediction: Codable {
    let mlRiskScore: Double?
    let predictedVolatility: Double?
    let confidence: Double
    let predictionAvailable: Bool
    
    enum CodingKeys: String, CodingKey {
        case mlRiskScore = "ml_risk_score"
        case predictedVolatility = "predicted_volatility"
        case confidence
        case predictionAvailable = "prediction_available"
    }
    
    var riskLevel: String {
        guard let score = mlRiskScore else { return "Unknown" }
        if score >= 80 { return "Low Risk" }
        if score >= 60 { return "Moderate Risk" }
        if score >= 40 { return "High Risk" }
        return "Very High Risk"
    }
    
    var confidenceLevel: String {
        if confidence >= 80 { return "High Confidence" }
        if confidence >= 60 { return "Moderate Confidence" }
        return "Low Confidence"
    }
    
    var riskColor: String {
        guard let score = mlRiskScore else { return "gray" }
        if score >= 80 { return "green" }
        if score >= 60 { return "blue" }
        if score >= 40 { return "orange" }
        return "red"
    }
}

struct AnomalyDetection: Codable {
    let isAnomaly: Bool
    let anomalyScore: Double
    let warnings: [String]
    
    enum CodingKeys: String, CodingKey {
        case isAnomaly = "is_anomaly"
        case anomalyScore = "anomaly_score"
        case warnings
    }
    
    var severityLevel: String {
        if anomalyScore >= 80 { return "Critical" }
        if anomalyScore >= 60 { return "High" }
        if anomalyScore >= 40 { return "Moderate" }
        return "Low"
    }
    
    var severityColor: String {
        if anomalyScore >= 80 { return "red" }
        if anomalyScore >= 60 { return "orange" }
        if anomalyScore >= 40 { return "yellow" }
        return "green"
    }
}

// MARK: - Portfolio Rating Service

class PortfolioRatingService {
    private let baseURL = "http://192.168.1.9:8000"
    
    enum RatingError: LocalizedError {
        case invalidURL
        case networkError(Error)
        case serverError(Int)
        case decodingError(Error)
        case noHoldings
        
        var errorDescription: String? {
            switch self {
            case .invalidURL:
                return "Invalid server URL"
            case .networkError(let error):
                return "Network error: \(error.localizedDescription)"
            case .serverError(let code):
                return "Server error: \(code)"
            case .decodingError(let error):
                return "Failed to parse response: \(error.localizedDescription)"
            case .noHoldings:
                return "No holdings to analyze"
            }
        }
    }
    
    func analyzePortfolio(holdings: [DBPortfolioStock]) async throws -> PortfolioAnalysisResponse {
        guard !holdings.isEmpty else {
            throw RatingError.noHoldings
        }
        
        guard let url = URL(string: "\(baseURL)/portfolio/analyze") else {
            throw RatingError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30
        
        let requestHoldings = holdings.map { stock in
            PortfolioHoldingRequest(
                symbol: stock.stockSymbol,
                quantity: stock.quantity,
                investedAmount: stock.avgBuyPrice * Double(stock.quantity)
            )
        }
        
        let analysisRequest = PortfolioAnalysisRequest(holdings: requestHoldings)
        
        do {
            request.httpBody = try JSONEncoder().encode(analysisRequest)
        } catch {
            throw RatingError.decodingError(error)
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw RatingError.serverError(0)
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                throw RatingError.serverError(httpResponse.statusCode)
            }
            
            let decoder = JSONDecoder()
            return try decoder.decode(PortfolioAnalysisResponse.self, from: data)
            
        } catch let error as RatingError {
            throw error
        } catch {
            throw RatingError.networkError(error)
        }
    }
    
    func analyzePortfolioEnhanced(holdings: [DBPortfolioStock]) async throws -> PortfolioAnalysisResponse {
        guard !holdings.isEmpty else {
            throw RatingError.noHoldings
        }
        
        guard let url = URL(string: "\(baseURL)/portfolio/analyze-enhanced") else {
            throw RatingError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 45
        
        let requestHoldings = holdings.map { stock in
            PortfolioHoldingRequest(
                symbol: stock.stockSymbol,
                quantity: stock.quantity,
                investedAmount: stock.avgBuyPrice * Double(stock.quantity)
            )
        }
        
        let analysisRequest = PortfolioAnalysisRequest(holdings: requestHoldings)
        
        do {
            request.httpBody = try JSONEncoder().encode(analysisRequest)
        } catch {
            throw RatingError.decodingError(error)
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw RatingError.serverError(0)
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                print("⚠️ ML analysis failed (HTTP \(httpResponse.statusCode)), falling back to standard analysis")
                return try await analyzePortfolio(holdings: holdings)
            }
            
            let decoder = JSONDecoder()
            return try decoder.decode(PortfolioAnalysisResponse.self, from: data)
            
        } catch let error as RatingError {
            throw error
        } catch {
            print("⚠️ ML analysis error: \(error), falling back to standard analysis")
            return try await analyzePortfolio(holdings: holdings)
        }
    }
}

// MARK: - Helper Extensions

extension PortfolioAnalysisResponse {
    var healthStatus: String {
        switch overall.grade {
        case "A": return "Excellent Health"
        case "B": return "Good Health"
        case "C": return "Fair Health"
        case "D": return "Needs Attention"
        default: return "Critical"
        }
    }
    
    var warningCount: Int {
        insights.filter { $0.isWarning }.count
    }
    
    var hasMLPredictions: Bool {
        mlInsights?.riskPrediction.predictionAvailable ?? false
    }
    
    var combinedRiskScore: Double {
        guard let mlScore = mlInsights?.riskPrediction.mlRiskScore else {
            return scores.riskManagement
        }
        return scores.riskManagement * 0.6 + mlScore * 0.4
    }
    
    var hasAnomalies: Bool {
        mlInsights?.anomalyDetection.isAnomaly ?? false
    }
}

// MARK: - DBPortfolioStock Protocol (Add this if not present in your project)
// If you already have this model, you can remove this section

protocol PortfolioStockProtocol {
    var stockSymbol: String { get }
    var quantity: Int { get }
    var avgBuyPrice: Double { get }
}

// Example implementation - replace with your actual DBPortfolioStock if different
