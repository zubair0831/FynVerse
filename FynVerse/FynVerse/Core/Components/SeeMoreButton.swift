import SwiftUI

struct SeeMoreButton: View {
    let resultantStocks: [StockModel]
    let title: String
    let authvm: AuthViewModel
    var marketCapFilter: MarketCapFilter? = nil
    
    enum MarketCapFilter: String, CaseIterable {
        case largeCap = "Large Cap"
        case midCap = "Mid Cap"
        case smallCap = "Small Cap"
    }
    
    var body: some View {
        NavigationLink(
            destination: SeeMoreStocksView(
                stocks: resultantStocks,
                title: title,
                authvm: authvm,
                marketCapFilter: marketCapFilter
            )
        ) {
            HStack(spacing: 4) {
                Text("See More")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Image(systemName: "chevron.right")
                    .font(.caption)
            }
            .foregroundStyle(Color.theme.accent)
        }
        .buttonStyle(.plain)
    }
}
