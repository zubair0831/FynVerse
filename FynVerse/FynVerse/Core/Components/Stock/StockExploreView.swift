import SwiftUI
import SwiftUI

struct StockExploreView: View {
    let stock: StockModel
    // Removed @State private var selectedStock: StockModel? = nil

    var body: some View {
        VStack(spacing: 6) {
            // Symbol with logo
            HStack(spacing: 8) {
                StockImageView(stock: stock)
                    .scaledToFit()
                    .frame(width: 28, height: 28)
                    .clipShape(Circle())

                Text(stock.SYMBOL)
                    .font(.callout)
                    .bold()
                    .foregroundStyle(Color.theme.accent)
            }
            .frame(maxWidth: .infinity, alignment: .center)
            
            // Price
           
                Text(stock.Last_Price.asCurrencywith6Decimals())
                    .font(.callout)
                    .bold()
                    .foregroundStyle(Color.theme.secondary)
            

            // Change %
            Text(stock.Percent_Change.asPercentString())
                .font(.callout)
                .foregroundStyle(stock.Percent_Change >= 0 ? Color.theme.green : Color.theme.red)
        }
        // Removed .onTapGesture
        // Removed .navigationDestination
        .frame(width: 140)
        .padding(.vertical, 12)
        .padding(.horizontal, 8)
        .frame(height: 100)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.theme.cardBackground)
                .shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)
        )

    }
}
