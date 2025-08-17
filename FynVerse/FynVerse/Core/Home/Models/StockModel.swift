struct StockModel: Codable, Hashable, Identifiable {
    // This is the required 'id' property for Identifiable
    var id: String { SYMBOL }
    
    let SYMBOL: String
    let NAME_OF_COMPANY: String
    let SERIES: String
    let FACE_VALUE: Int
    let Last_Price: Double
    let Previous_Close: Double
    let P_L: Double        // Profit & Loss
    let Percent_Change: Double

    enum CodingKeys: String, CodingKey {
        case SYMBOL
        case NAME_OF_COMPANY = "NAME OF COMPANY"
        case SERIES
        case FACE_VALUE = "FACE VALUE"
        case Last_Price = "Last Price"
        case Previous_Close = "Previous Close"
        case P_L = "P&L"
        case Percent_Change = "Percent Change"
    }
}
