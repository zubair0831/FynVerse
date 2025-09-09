// MARK: - Root

import Foundation
struct StockComprehensiveModel: Codable {
    let basic: BasicInfo?
    let price: PriceData?
    let valuation: ValuationMetrics?
    let financial: FinancialMetrics?
    let balanceSheet: BalanceSheetMetrics?

    enum CodingKeys: String, CodingKey {
        case basic = "basic_info"
        case price = "price_data"
        case valuation = "valuation_metrics"
        case financial = "financial_metrics"
        case balanceSheet = "balance_sheet_metrics"
    }
}

// MARK: - Basic Info
struct BasicInfo: Codable {
    let name: String?
    let sector: String?
    let industry: String?
    let country: String?
    let exchange: String?
    let currency: String?
    let employees: String?   // sometimes comes as string
    let website: String?
    let businessSummary: String?   // <-- ✅ summary here

    enum CodingKeys: String, CodingKey {
        case name = "company_name"
        case sector
        case industry
        case country
        case exchange
        case currency
        case employees
        case website
        case businessSummary = "business_summary"
    }
}

// MARK: - PriceData
struct PriceData: Codable {
    let current: Double?
    let previousClose: Double?
    let open: Double?
    let dayLow: Double?
    let dayHigh: Double?
    let week52Low: Double?
    let week52High: Double?
    let volume: Int?
    let avgVolume: Int?
    let marketCap: Double?
    let historical5d: [HistoricalCandle]?

    enum CodingKeys: String, CodingKey {
        case current = "current_price"
        case previousClose = "previous_close"
        case open
        case dayLow = "day_low"
        case dayHigh = "day_high"
        case week52Low = "52_week_low"
        case week52High = "52_week_high"
        case volume
        case avgVolume = "avg_volume"
        case marketCap = "market_cap"
        case historical5d = "historical_5d"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.current = container.decodeDoubleFromStringIfNeeded(forKey: .current)
        self.previousClose = container.decodeDoubleFromStringIfNeeded(forKey: .previousClose)
        self.open = container.decodeDoubleFromStringIfNeeded(forKey: .open)
        self.dayLow = container.decodeDoubleFromStringIfNeeded(forKey: .dayLow)
        self.dayHigh = container.decodeDoubleFromStringIfNeeded(forKey: .dayHigh)
        self.week52Low = container.decodeDoubleFromStringIfNeeded(forKey: .week52Low)
        self.week52High = container.decodeDoubleFromStringIfNeeded(forKey: .week52High)
        self.volume = container.decodeIntFromStringIfNeeded(forKey: .volume)
        self.avgVolume = container.decodeIntFromStringIfNeeded(forKey: .avgVolume)
        self.marketCap = container.decodeDoubleFromStringIfNeeded(forKey: .marketCap)
        self.historical5d = try? container.decodeIfPresent([HistoricalCandle].self, forKey: .historical5d)
    }
}

// MARK: - HistoricalCandle
struct HistoricalCandle: Codable, Identifiable {
    var id = UUID()
    let open: Double?
    let high: Double?
    let low: Double?
    let close: Double?
    let volume: Int?
    let dividends: Double?
    let stockSplits: Double?

    enum CodingKeys: String, CodingKey {
        case open = "Open"
        case high = "High"
        case low = "Low"
        case close = "Close"
        case volume = "Volume"
        case dividends = "Dividends"
        case stockSplits = "Stock Splits"
    }
}

// MARK: - ValuationMetrics
struct ValuationMetrics: Codable {
    let pe: Double?
    let forwardPE: Double?
    let peg: String?
    let priceToBook: Double?
    let priceToSales: Double?
    let enterpriseValue: Double?
    let evToRevenue: Double?
    let evToEbitda: Double?

    enum CodingKeys: String, CodingKey {
        case pe = "pe_ratio"
        case forwardPE = "forward_pe"
        case peg = "peg_ratio"
        case priceToBook = "price_to_book"
        case priceToSales = "price_to_sales"
        case enterpriseValue = "enterprise_value"
        case evToRevenue = "ev_to_revenue"
        case evToEbitda = "ev_to_ebitda"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.pe = container.decodeDoubleFromStringIfNeeded(forKey: .pe)
        self.forwardPE = container.decodeDoubleFromStringIfNeeded(forKey: .forwardPE)
        self.priceToBook = container.decodeDoubleFromStringIfNeeded(forKey: .priceToBook)
        self.priceToSales = container.decodeDoubleFromStringIfNeeded(forKey: .priceToSales)
        self.enterpriseValue = container.decodeDoubleFromStringIfNeeded(forKey: .enterpriseValue)
        self.evToRevenue = container.decodeDoubleFromStringIfNeeded(forKey: .evToRevenue)
        self.evToEbitda = container.decodeDoubleFromStringIfNeeded(forKey: .evToEbitda)
        self.peg = try? container.decodeIfPresent(String.self, forKey: .peg)
    }
}

// MARK: - FinancialMetrics
struct FinancialMetrics: Codable {
    let dividendYield: Double?
    let profitMargin: Double?
    let operatingMargin: Double?

    enum CodingKeys: String, CodingKey {
        case dividendYield = "dividend_yield"
        case profitMargin = "profit_margin"
        case operatingMargin = "operating_margin"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.dividendYield = container.decodeDoubleFromStringIfNeeded(forKey: .dividendYield)
        self.profitMargin = container.decodeDoubleFromStringIfNeeded(forKey: .profitMargin)
        self.operatingMargin = container.decodeDoubleFromStringIfNeeded(forKey: .operatingMargin)
    }
}

// MARK: - BalanceSheetMetrics
struct BalanceSheetMetrics: Codable {
    let totalCash: Double?
    let totalDebt: Double?
    let debtToEquity: Double?
    let bookValue: Double?

    enum CodingKeys: String, CodingKey {
        case totalCash = "total_cash"
        case totalDebt = "total_debt"
        case debtToEquity = "debt_to_equity"
        case bookValue = "book_value"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.totalCash = container.decodeDoubleFromStringIfNeeded(forKey: .totalCash)
        self.totalDebt = container.decodeDoubleFromStringIfNeeded(forKey: .totalDebt)
        self.debtToEquity = container.decodeDoubleFromStringIfNeeded(forKey: .debtToEquity)
        self.bookValue = container.decodeDoubleFromStringIfNeeded(forKey: .bookValue)
    }
}

// MARK: - Decoding Helpers
extension KeyedDecodingContainer {
    func decodeDoubleFromStringIfNeeded(forKey key: KeyedDecodingContainer<K>.Key) -> Double? {
        if let doubleValue = try? decodeIfPresent(Double.self, forKey: key) {
            return doubleValue
        }
        if let stringValue = try? decodeIfPresent(String.self, forKey: key) {
            return Double(stringValue)
        }
        return nil
    }

    func decodeIntFromStringIfNeeded(forKey key: KeyedDecodingContainer<K>.Key) -> Int? {
        if let intValue = try? decodeIfPresent(Int.self, forKey: key) {
            return intValue
        }
        if let stringValue = try? decodeIfPresent(String.self, forKey: key) {
            return Int(stringValue)
        }
        return nil
    }
}
