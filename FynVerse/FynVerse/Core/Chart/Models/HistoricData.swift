import Foundation

struct HistoricalChartResponse: Decodable {
    let chart: ChartData
}

struct ChartData: Decodable {
    let result: [ChartResult]
}

struct ChartResult: Decodable {
    let timestamp: [Int]?
    let indicators: ChartIndicators
}

struct ChartIndicators: Decodable {
    let quote: [ChartQuote]
}

struct ChartQuote: Decodable {
    let open: [Double?]
    let high: [Double?]
    let low: [Double?]
    let close: [Double?]
    let volume: [Int?]
}
