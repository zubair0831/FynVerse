//
//  previewProvider.swift
//  FynVerse
//
//  Created by zubair ahmed on 17/07/25.
//
import SwiftUI

extension PreviewProvider{
    static var dev:DeveloperPreview {
        return DeveloperPreview.instance
    }
}
extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}

class DeveloperPreview{
    static let instance = DeveloperPreview()
    
    private init(){
        
    }
    
    let stat1 = [
        StatisticsModel(title: "SENSEX", value: "81,757", percentChange: -0.61),
        StatisticsModel(title: "NASDAQ", value: "20,895", percentChange: 0.048),
        StatisticsModel(title: "GOLD", value: "1,01,295", percentChange: -1.5),
        StatisticsModel(title: "SILVER", value: "1,11,000", percentChange: 2.5)
    ]
    
}
