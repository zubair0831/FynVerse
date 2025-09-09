import Foundation
import SwiftUI
struct SeeMoreStocksView: View {
    let stocks: [StockModel]
    let title: String
    let authvm: AuthViewModel
    var marketCapFilter: SeeMoreButton.MarketCapFilter? = nil
    
    @State private var searchText: String = ""
    @State private var isRefreshing = false
    
    var filteredStocks: [StockModel] {
        if searchText.isEmpty {
            return stocks
        } else {
            return stocks.filter {
                $0.SYMBOL.localizedCaseInsensitiveContains(searchText) ||
                $0.NAME_OF_COMPANY.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var body: some View {
        ZStack {
            Color.theme.background.ignoresSafeArea()
            
            if stocks.isEmpty {
                emptyStateView
            } else {
                stocksList
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.large)
        .searchable(text: $searchText, prompt: "Search stocks...")
        .refreshable {
            await performRefresh()
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 60))
                .foregroundStyle(Color.theme.accent.opacity(0.6))
            
            Text("No Stocks Available")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundStyle(Color.theme.accent)
            
            Text("Check back later for market updates")
                .font(.subheadline)
                .foregroundStyle(Color.theme.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var stocksList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(filteredStocks, id: \.id) { stock in
                    NavigationLink(
                        destination: DetailView(stock: stock, DBStock: nil, authViewModel: authvm)
                    ) {
                        StockRowView(stock: stock, authvm: authvm)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
        }
    }
    
    private func performRefresh() async {
        isRefreshing = true
        // Add haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second delay for demo
        isRefreshing = false
    }
}
