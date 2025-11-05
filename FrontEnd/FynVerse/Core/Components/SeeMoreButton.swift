import SwiftUI

struct SeeMoreButton: View {
    // Note: StockModel and AuthViewModel must be defined elsewhere
    let resultantStocks: [StockModel]
    let title: String
    let authvm: AuthViewModel
    var marketCapFilter: MarketCapFilter? = nil
    
    // Assuming MarketCapFilter is defined in your HomeView as an Enum
    enum MarketCapFilter: String, CaseIterable {
        case largeCap = "Large Cap"
        case midCap = "Mid Cap"
        case smallCap = "Small Cap"
    }
    
    // Determines if the button should be visible (e.g., if there are enough stocks to show)
    private var shouldShow: Bool {
        // You might want to adjust this logic (e.g., resultantStocks.count > 5)
        return !resultantStocks.isEmpty
    }
    
    var body: some View {
        // Only show the NavigationLink if the button logic determines it should be visible
        if shouldShow {
            NavigationLink(
                destination: SeeMoreStocksView( // Make sure SeeMoreStocksView is defined
                    stocks: resultantStocks,
                    title: title,
                    authvm: authvm,
                    marketCapFilter: marketCapFilter
                )
            ) {
                HStack(spacing: 5) {
                    Text("See All") // Changed to "See All" for a cleaner, more actionable look
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.theme.accent)
                        .lineLimit(1)
                    
                    // Changed to a solid circle icon for a more defined look, like the filter button
                    Image(systemName: "arrow.forward.circle.fill")
                        .font(.caption)
                        .foregroundStyle(Color.theme.accent.opacity(0.8))
                }
                // --- Uniform Button Styling ---
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        // Use a slightly varied background opacity for distinction
                        .fill(Color.theme.secondary.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.theme.secondary.opacity(0.3), lineWidth: 1)
                        )
                )
            }
            // Use the custom scaling button style for consistency
            .buttonStyle(ScaleButtonStyle())
        } else {
            // Return an EmptyView if the button shouldn't be shown
            EmptyView()
        }
    }
}

// NOTE: You must ensure this button style is accessible to your button (usually defined in HomeView.swift)
/*
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}
*/
