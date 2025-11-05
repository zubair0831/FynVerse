// MARK: - Root

import Foundation
struct StockComprehensiveModel: Codable {
    let basic: BasicInfo?
    let price: PriceData?
    let valuation: ValuationMetrics?
    let financial: FinancialMetrics?
    let balanceSheet: BalanceSheetMetrics?
    let shareholding: ShareholdingPattern?

    enum CodingKeys: String, CodingKey {
        case basic = "basic_info"
        case price = "price_data"
        case valuation = "valuation_metrics"
        case financial = "financial_metrics"
        case balanceSheet = "balance_sheet_metrics"
        case shareholding = "shareholding_pattern"
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
// MARK: - ShareholdingPattern
struct ShareholdingPattern: Codable {
    let sharesOutstanding: String?
    let floatShares: String?
    let sharesShort: String?
    let heldPercentInsiders: String?
    let heldPercentInstitutions: String?
    let sharesPercentSharesOut: String?
    let promoterHoldingPercent: String?
    let publicHoldingPercent: String?
    let fiiHoldingPercent: String?
    let majorHoldersSummary: MajorHoldersSummary?
    let institutionalHolders: InstitutionalHolders?

    enum CodingKeys: String, CodingKey {
        case sharesOutstanding = "shares_outstanding"
        case floatShares = "float_shares"
        case sharesShort = "shares_short"
        case heldPercentInsiders = "held_percent_insiders"
        case heldPercentInstitutions = "held_percent_institutions"
        case sharesPercentSharesOut = "shares_percent_shares_out"
        case promoterHoldingPercent = "promoter_holding_percent"
        case publicHoldingPercent = "public_holding_percent"
        case fiiHoldingPercent = "fii_holding_percent"
        case majorHoldersSummary = "major_holders_summary"
        case institutionalHolders = "institutional_holders"
    }
}

// MARK: - MajorHoldersSummary
struct MajorHoldersSummary: Codable {
    let data: MajorHoldersData?
    let lastUpdated: String?

    enum CodingKeys: String, CodingKey {
        case data
        case lastUpdated = "last_updated"
    }
}

struct MajorHoldersData: Codable {
    let value: MajorHoldersValue?

    enum CodingKeys: String, CodingKey {
        case value = "Value"
    }
}

struct MajorHoldersValue: Codable {
    let insidersPercentHeld: Double?
    let institutionsPercentHeld: Double?
    let institutionsFloatPercentHeld: Double?
    let institutionsCount: Int?
}

// MARK: - InstitutionalHolders
struct InstitutionalHolders: Codable {
    let data: [String: JSONAny]?   // <-- Flexible
    let count: Int?
    let lastUpdated: String?

    enum CodingKeys: String, CodingKey {
        case data
        case count
        case lastUpdated = "last_updated"
    }
}

// MARK: - Decoding Helpers
extension KeyedDecodingContainer {
    func decodeDoubleFromStringIfNeeded(forKey key: Key) -> Double? {
        if let doubleValue = try? decodeIfPresent(Double.self, forKey: key) {
            return doubleValue
        }
        if let stringValue = try? decodeIfPresent(String.self, forKey: key) {
            return Double(stringValue) // handles both "5" and "0.52597"
        }
        return nil
    }

    func decodeIntFromStringIfNeeded(forKey key: Key) -> Int? {
        if let intValue = try? decodeIfPresent(Int.self, forKey: key) {
            return intValue
        }
        if let stringValue = try? decodeIfPresent(String.self, forKey: key) {
            return Int(stringValue)
        }
        return nil
    }
}
// MARK: - JSONAny
struct JSONAny: Codable {
    let value: Any

    init(_ value: Any) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let intVal = try? container.decode(Int.self) {
            value = intVal
        } else if let doubleVal = try? container.decode(Double.self) {
            value = doubleVal
        } else if let boolVal = try? container.decode(Bool.self) {
            value = boolVal
        } else if let stringVal = try? container.decode(String.self) {
            value = stringVal
        } else if let dictVal = try? container.decode([String: JSONAny].self) {
            value = dictVal
        } else if let arrayVal = try? container.decode([JSONAny].self) {
            value = arrayVal
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "JSONAny decoding failed")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        if let intVal = value as? Int {
            try container.encode(intVal)
        } else if let doubleVal = value as? Double {
            try container.encode(doubleVal)
        } else if let boolVal = value as? Bool {
            try container.encode(boolVal)
        } else if let stringVal = value as? String {
            try container.encode(stringVal)
        } else if let dictVal = value as? [String: JSONAny] {
            try container.encode(dictVal)
        } else if let arrayVal = value as? [JSONAny] {
            try container.encode(arrayVal)
        } else {
            throw EncodingError.invalidValue(value, EncodingError.Context(codingPath: encoder.codingPath, debugDescription: "Invalid JSONAny value"))
        }
    }
}
