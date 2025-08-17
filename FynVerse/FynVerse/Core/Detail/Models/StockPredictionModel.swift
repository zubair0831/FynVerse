//
//  StockPredictionModel.swift
//  FynVerse
//
//  Created by zubair ahmed on 12/08/25.
//


struct Next5Dpred: Codable {
    let date: String
    let probability: Double
    let signal: String
}

struct lonShortPred: Codable {
    let symbol: String
    let fundamentalScore01, technicalScore01, shortTermScore01: Double
    let shortTermRating: String
    let longTermScore01: Double
    let longTermRating: String
    let metadata: Metadata

    enum CodingKeys: String, CodingKey {
        case symbol = "Symbol"
        case fundamentalScore01 = "Fundamental score (0-1)"
        case technicalScore01 = "Technical score (0-1)"
        case shortTermScore01 = "Short-term score (0-1)"
        case shortTermRating = "Short-term rating"
        case longTermScore01 = "Long-term score (0-1)"
        case longTermRating = "Long-term rating"
        case metadata = "Metadata"
    }
}

struct Metadata: Codable {
    let lastPE, lastPb: Double
    let peGlobalLow, pbGlobalLow: Bool
    let peMinimaCount, pbMinimaCount: Int

    enum CodingKeys: String, CodingKey {
        case lastPE = "last_pe"
        case lastPb = "last_pb"
        case peGlobalLow = "pe_global_low"
        case pbGlobalLow = "pb_global_low"
        case peMinimaCount = "pe_minima_count"
        case pbMinimaCount = "pb_minima_count"
    }
}
