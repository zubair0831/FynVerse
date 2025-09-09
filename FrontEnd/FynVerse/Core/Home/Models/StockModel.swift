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
    let MarketCap: Double
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
}

