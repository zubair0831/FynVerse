// MARK: - Enhanced Stock Row View

import SwiftUI

struct StockRowView: View {
    let stock: StockModel
    @State private var isPressed = false
    @ObservedObject var authvm: AuthViewModel
    
    var body: some View {
        NavigationLink {
            DetailView(stock: stock, DBStock: nil, authViewModel: authvm)
        } label: {
            HStack(spacing: 16) {
                // Stock Icon with shimmer effect
                stockIcon
                
                // Stock Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(stock.SYMBOL)
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.theme.accent)
                        .lineLimit(1)
                    
                    Text(stock.NAME_OF_COMPANY)
                        .font(.caption)
                        .foregroundStyle(Color.theme.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                // Price and Change
                VStack(alignment: .trailing, spacing: 4) {
                    Text(stock.Last_Price.asCurrencyWith2Decimals())
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.theme.accent)
                    
                    HStack(spacing: 4) {
                        Image(systemName: stock.Percent_Change >= 0 ? "arrowtriangle.up.fill" : "arrowtriangle.down.fill")
                            .font(.caption2)
                        
                        Text(stock.Percent_Change.asPercentString())
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                    .foregroundStyle(stock.Percent_Change >= 0 ? Color.theme.green : Color.theme.red)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.theme.cardBackground)
                    .shadow(
                        color: isPressed ? Color.theme.accent.opacity(0.2) : .black.opacity(0.06),
                        radius: isPressed ? 8 : 4,
                        x: 0,
                        y: isPressed ? 4 : 2
                    )
            )
            .scaleEffect(isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: isPressed)
            .onLongPressGesture(minimumDuration: 0.1, pressing: { pressing in
                isPressed = pressing
            }, perform: {})
        }
    }
    
    // MARK: - Stock Icon
    private var stockIcon: some View {
        ZStack {
            Circle()
                .fill(Color.theme.accent.opacity(0.1))
                .frame(width: 50, height: 50)
            
            StockImageView(stock: stock)
                .frame(width: 40, height: 40)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(Color.theme.accent.opacity(0.2), lineWidth: 1)
                )
        }
    }
}
