//
//  HistoricPriceModel.swift
//  FynVerse
//
//  Created by zubair ahmed on 20/07/25.
//


import Foundation

struct HistoricPriceModel: Identifiable,Codable,Equatable {
    var id = UUID()
    let date: Date
    let open: Double
    let high: Double
    let low: Double
    let close: Double
    let volume: Int
}
