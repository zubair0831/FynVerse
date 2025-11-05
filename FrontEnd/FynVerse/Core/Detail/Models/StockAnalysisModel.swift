// StockAnalysisModel.swift
// FynVerse
// Created by zubair ahmed

import Foundation

struct StockAnalysisResponse: Codable {
    let ticker: String
    let companyName: String
    let sector: String
    let industry: String
    let timestamp: String
    let priceData: StockPriceData
    let performance: StockPerformanceData
    let fundamentals: StockFundamentals
    let valuationAnalysis: StockValuationAnalysis
    let riskMetrics: StockRiskMetrics
    let analysis: StockAnalysisData
    let methodology: AnalysisMethodology
    let disclaimer: AnalysisDisclaimer
    
    enum CodingKeys: String, CodingKey {
        case ticker
        case companyName = "company_name"
        case sector, industry, timestamp
        case priceData = "price_data"
        case performance, fundamentals
        case valuationAnalysis = "valuation_analysis"
        case riskMetrics = "risk_metrics"
        case analysis, methodology, disclaimer
    }
}

struct StockPriceData: Codable {
    let currentPrice: Double
    let ma20: Double?
    let ma50: Double?
    let ma200: Double?
    let week52High: Double
    let week52Low: Double
    let positionIn52wRange: Double
    let rsi: Double?
    
    enum CodingKeys: String, CodingKey {
        case currentPrice = "current_price"
        case ma20 = "ma_20"
        case ma50 = "ma_50"
        case ma200 = "ma_200"
        case week52High = "52_week_high"
        case week52Low = "52_week_low"
        case positionIn52wRange = "position_in_52w_range"
        case rsi
    }
}

struct StockPerformanceData: Codable {
    let oneWeek: Double?
    let oneMonth: Double?
    let threeMonth: Double?
    let sixMonth: Double?
    
    enum CodingKeys: String, CodingKey {
        case oneWeek = "1_week"
        case oneMonth = "1_month"
        case threeMonth = "3_month"
        case sixMonth = "6_month"
    }
}

struct StockFundamentals: Codable {
    let peRatio: Double?
    let forwardPE: Double?
    let pbRatio: Double?
    let debtToEquity: Double?
    let roe: Double?
    let profitMargin: Double?
    let revenueGrowth: Double?
    let earningsGrowth: Double?
    let dividendYield: Double?
    let beta: Double?
    let marketCap: StockMarketCapValue?
    
    enum CodingKeys: String, CodingKey {
        case peRatio = "pe_ratio"
        case forwardPE = "forward_pe"
        case pbRatio = "pb_ratio"
        case debtToEquity = "debt_to_equity"
        case roe
        case profitMargin = "profit_margin"
        case revenueGrowth = "revenue_growth"
        case earningsGrowth = "earnings_growth"
        case dividendYield = "dividend_yield"
        case beta
        case marketCap = "market_cap"
    }
}

// Handle both numeric and string market cap values
enum StockMarketCapValue: Codable {
    case numeric(Double)
    case string(String)
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let doubleValue = try? container.decode(Double.self) {
            self = .numeric(doubleValue)
        } else if let stringValue = try? container.decode(String.self) {
            self = .string(stringValue)
        } else {
            self = .string("N/A")
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .numeric(let value):
            try container.encode(value)
        case .string(let value):
            try container.encode(value)
        }
    }
    
    var displayValue: String {
        switch self {
        case .numeric(let value):
            return formatMarketCap(value)
        case .string(let value):
            return value
        }
    }
    
    private func formatMarketCap(_ value: Double) -> String {
        if value >= 1_000_000_000_000 {
            return String(format: "₹%.2fT", value / 1_000_000_000_000)
        } else if value >= 100_000_000_000 {
            return String(format: "₹%.2fB", value / 1_000_000_000_000)
        } else if value >= 10_000_000 {
            return String(format: "₹%.2fCr", value / 10_000_000)
        } else {
            return String(format: "₹%.2fL", value / 100_000)
        }
    }
}

struct StockValuationAnalysis: Codable {
    let score: Double
    let grade: String
    let assessment: String
    let peRatio: Double?
    let pegRatio: Double?
    let sectorCAGR: Double
    let reasoning: [ValuationReasoningItem]
    let methodology: String
    
    enum CodingKeys: String, CodingKey {
        case score, grade, assessment
        case peRatio = "pe_ratio"
        case pegRatio = "peg_ratio"
        case sectorCAGR = "sector_cagr"
        case reasoning, methodology
    }
}

struct ValuationReasoningItem: Codable, Identifiable {
    let id = UUID()
    let type: String
    let message: String
    
    enum CodingKeys: String, CodingKey {
        case type, message
    }
}

struct StockRiskMetrics: Codable {
    let volatility60dAnnualized: Double?
    let volumeRatio: Double?
    let avgVolume20d: Double?
    
    enum CodingKeys: String, CodingKey {
        case volatility60dAnnualized = "volatility_60d_annualized"
        case volumeRatio = "volume_ratio"
        case avgVolume20d = "avg_volume_20d"
    }
}

struct StockAnalysisData: Codable {
    let score: Double
    let maxScore: Int
    let scorePercentage: Double
    let recommendation: String
    let overallAssessment: String
    let signals: [AnalysisSignalItem]
    
    enum CodingKeys: String, CodingKey {
        case score
        case maxScore = "max_score"
        case scorePercentage = "score_percentage"
        case recommendation
        case overallAssessment = "overall_assessment"
        case signals
    }
}

struct AnalysisSignalItem: Codable, Identifiable {
    let id = UUID()
    let type: String
    let message: String
    
    enum CodingKeys: String, CodingKey {
        case type, message
    }
}

struct AnalysisMethodology: Codable {
    let approach: String
    let peFramework: String
    let researchBasis: String
    let reference: String
    
    enum CodingKeys: String, CodingKey {
        case approach
        case peFramework = "pe_framework"
        case researchBasis = "research_basis"
        case reference
    }
}

struct AnalysisDisclaimer: Codable {
    let message: String
    let warnings: [String]
}
