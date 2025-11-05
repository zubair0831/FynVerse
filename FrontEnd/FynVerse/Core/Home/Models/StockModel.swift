struct StockModel: Codable, Hashable, Identifiable {
    var id: String { SYMBOL }
    
    let SYMBOL: String
    let NAME_OF_COMPANY: String
    let SERIES: String
    let FACE_VALUE: Int
    let YahooSymbol: String
    let Open: Double?
    let High: Double?
    let Low: Double?
    let Last_Price: Double
    let Previous_Close: Double
    let Volume: Int?
    let MarketCap: Double?   // 👈 only this field is handled safely
    let P_L: Double
    let Percent_Change: Double

    enum CodingKeys: String, CodingKey {
        case SYMBOL
        case NAME_OF_COMPANY = "NAME OF COMPANY"
        case SERIES
        case FACE_VALUE = "FACE VALUE"
        case YahooSymbol
        case Open
        case High
        case Low
        case Last_Price = "Last Price"
        case Previous_Close = "Previous Close"
        case Volume
        case MarketCap = "Market Cap"
        case P_L = "P&L"
        case Percent_Change = "Percent Change"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        SYMBOL = try c.decode(String.self, forKey: .SYMBOL)
        NAME_OF_COMPANY = try c.decode(String.self, forKey: .NAME_OF_COMPANY)
        SERIES = try c.decode(String.self, forKey: .SERIES)
        FACE_VALUE = try c.decode(Int.self, forKey: .FACE_VALUE)
        YahooSymbol = try c.decode(String.self, forKey: .YahooSymbol)
        Open = try? c.decode(Double.self, forKey: .Open)
        High = try? c.decode(Double.self, forKey: .High)
        Low = try? c.decode(Double.self, forKey: .Low)
        Last_Price = try c.decode(Double.self, forKey: .Last_Price)
        Previous_Close = try c.decode(Double.self, forKey: .Previous_Close)
        Volume = try? c.decode(Int.self, forKey: .Volume)

        // ✅ Safe MarketCap decoding (handles NA, -, null, or missing)
        if let value = try? c.decode(Double.self, forKey: .MarketCap) {
            MarketCap = value
        } else if let str = try? c.decode(String.self, forKey: .MarketCap),
                  let value = Double(str) {
            MarketCap = value
        } else {
            MarketCap = nil
        }

        P_L = try c.decode(Double.self, forKey: .P_L)
        Percent_Change = try c.decode(Double.self, forKey: .Percent_Change)
    }
}
