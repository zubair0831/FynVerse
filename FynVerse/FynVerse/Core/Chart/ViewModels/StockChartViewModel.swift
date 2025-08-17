//
//  StockChartViewModel.swift
//  FynVerse
//
//  Created by zubair ahmed on 28/07/25.
//

import Foundation


@MainActor
class StockChartViewModel: ObservableObject {
    @Published var historicData: [HistoricPriceModel] = []
    @Published var selectedRange: ChartRange = .oneMonth {
        didSet {
            Task {
                await fetchChart(for: currentSymbol)
            }
        }
    }
    @Published var isLoading = false

    private var currentSymbol = ""

    func fetchChart(for symbol: String) async {
        isLoading = true
        currentSymbol = symbol

        let fullSymbol: String
        if symbol != "NIFTY50" { // Assuming "NIFTY50" is a special case for index
            fullSymbol = symbol.contains(".NS") ? symbol : symbol + ".NS"
        } else {
            fullSymbol = "^NSEI" // Yahoo Finance symbol for Nifty 50
        }

        let data = await HistoricDataService.shared.fetchHistoricalPrices(
            symbol: fullSymbol,
            interval: selectedRange.interval,
            range: selectedRange.range
        )

        historicData = data
        isLoading = false
    }

    var isStockUp: Bool {
        guard let first = historicData.first?.close,
              let last = historicData.last?.close else {
            return true // Default to green if no data
        }
        return last >= first
    }
}
enum ChartRange: String, CaseIterable, Identifiable {
    case oneDay = "1D"
    case oneWeek = "1W"
    case oneMonth = "1M"
    case oneYear = "1Y"
    case threeYear = "3Y"

    var id: String { rawValue }

    var interval: String {
        switch self {
        case .oneDay: return "5m"
        case .oneWeek: return "30m"
        case .oneMonth: return "1d"
        case .oneYear: return "1wk"
        case .threeYear: return "1mo"
        }
    }

    var range: String {
        switch self {
        case .oneDay: return "1d"
        case .oneWeek: return "5d"
        case .oneMonth: return "1mo"
        case .oneYear: return "1y"
        case .threeYear: return "3y"
        }
    }
}
