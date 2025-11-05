import SwiftUI

struct StockExploreView: View {
    let stock: StockModel
    @ObservedObject var authvm: AuthViewModel // Assumed to be available
    
    // Determine the color based on the stock's performance
    private var changeColor: Color {
        stock.Percent_Change >= 0 ? Color.theme.success : Color.theme.red
    }
    
    // Format change with explicit + or -
    private var formattedChange: String {
        let percent = stock.Percent_Change.asPercentString()
        if stock.Percent_Change >= 0 {
            return "+\(percent)"
        } else {
            return percent // Assumes it already includes the -
        }
    }
    
    // Format P&L using the currency formatter and add + for positive (assumes formatter includes ₹)
    private var formattedPnL: String {
        let pnlStr = stock.P_L.asCurrencywith6Decimals()
        return stock.P_L >= 0 ? "+\(pnlStr)" : pnlStr
    }
    
    var body: some View {
        NavigationLink {
            // Assumed DetailView exists in the environment
            DetailView(stock: stock, DBStock: nil, authViewModel: authvm)
        } label: {
            VStack(spacing: 6) { // Slightly reduced spacing
                
                // MARK: - Symbol and Logo
                HStack(spacing: 6) {
                    // Assumed StockImageView exists
                    StockImageView(stock: stock)
                        .scaledToFit()
                        // UPDATED: Increased logo size
                        .frame(width: 32, height: 32)
                        .clipShape(Circle())
                    
                    Text(stock.SYMBOL)
                        // UPDATED: Increased font size and weight
                        .font(.system(size: 14, weight: .bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .foregroundStyle(Color.theme.primaryText)
                    
                    Spacer()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                Spacer(minLength: 4)
                
                // MARK: - Price, Change, and P&L
                HStack(spacing: 6) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(stock.Last_Price.asCurrencywith6Decimals()) // Assumes formatter includes ₹
                            .font(.system(size: 14, weight: .bold))
                            // EDITED: Highlighted the Last Price by using the changeColor
                            .foregroundStyle(changeColor)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        
                        // MARK: - Change %
                        HStack(spacing: 3) {
                            Image(systemName: stock.Percent_Change >= 0 ? "arrow.up.right" : "arrow.down.right")
                                .font(.system(size: 8, weight: .bold)) // Smaller icon
                                .foregroundStyle(changeColor)
                            
                            Text(formattedChange) // With explicit +/-
                                .font(.system(size: 11, weight: .medium))
                        }
                        .foregroundStyle(changeColor)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // MARK: - P&L - Right-aligned with label, emphasized for visibility
                    VStack(alignment: .trailing, spacing: 0) {
                        Text("P&L")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(Color.theme.primaryText)
                            .lineLimit(1)
                        
                        Text(formattedPnL)
                            // EDITED: Decreased P&L value font size from 18 to 14
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(changeColor)
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                    }
                    .frame(width: 60) // Fixed width to ensure space
                }
                .frame(maxWidth: .infinity)
            }
            .padding(8) // Reduced padding
            // UPDATED: Decreased width from 200 to 160
            .frame(width: 160, height: 115)
            .background(
                RoundedRectangle(cornerRadius: 16) // Softer corners
                    .fill(Color.theme.cardBackground)
                    .shadow(
                        color: Color.theme.cardShadow,
                        radius: 8, // Softer, more diffused shadow
                        x: 0,
                        y: 4
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(changeColor.opacity(0.2), lineWidth: 1) // Subtler border
                    )
            )
        }
        .buttonStyle(.plain) // Ensure the navigation link doesn't use default button styling
    }
}
