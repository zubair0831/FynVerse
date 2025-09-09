import SwiftUI

struct PortfolioView: View {
    @ObservedObject var vm: PortfolioViewModel
    @EnvironmentObject var Hvm: HomeViewModel
    @ObservedObject var authvm: AuthViewModel
    @State private var hasLoadedPortfolio = false
    @State private var selectedTab: PortfolioTab = .holdings
    
    enum PortfolioTab: String, CaseIterable {
        case holdings = "Holdings"
        case analytics = "Analytics"
        
        var icon: String {
            switch self {
            case .holdings: return "list.bullet"
            case .analytics: return "chart.bar.fill"
            }
        }
    }
    
    var body: some View {
        ZStack {
            Color.theme.background
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Custom Tab Selector
                customTabSelector
                
                // Content based on selected tab
                switch selectedTab {
                case .holdings:
                    holdingsView
                case .analytics:
                    PortfolioAnalyticsView(
                        portfolioViewModel: vm,
                        homeViewModel: Hvm,
                        authViewModel: authvm
                    )
                }
            }
        }
        .navigationTitle("Portfolio")
        .navigationBarTitleDisplayMode(.large)
        .refreshable {
            await vm.fetchPortfolioStocks()
        }
        .task {
            if !hasLoadedPortfolio {
                // make sure Home stocks are loaded first
                if Hvm.allStocks.isEmpty {
                    await Hvm.fetchStocks()
                }
                await vm.fetchPortfolioStocks()
                hasLoadedPortfolio = true
            }
        }
    }
    
    @ViewBuilder
    private var customTabSelector: some View {
        HStack(spacing: 0) {
            ForEach(PortfolioTab.allCases, id: \.self) { tab in
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        selectedTab = tab
                    }
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 16, weight: .medium))
                        
                        Text(tab.rawValue)
                            .font(.system(size: 16, weight: .medium))
                    }
                    .foregroundColor(selectedTab == tab ? .white : Color.theme.accent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(selectedTab == tab ? Color.theme.accent : Color.clear)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
    
    @ViewBuilder
    private var holdingsView: some View {
        ScrollView {
            VStack(spacing: 24) {
                
                // MARK: - Portfolio Summary
                if !vm.portfolioStocks.isEmpty {
                    PortfolioSummaryView()
                        .environmentObject(vm)
                } else {
                    emptyPortfolioView
                }
                
                // MARK: - Quick Stats (only show if portfolio exists)
                if !vm.portfolioStocks.isEmpty {
                    quickStatsView
                }
                
                // MARK: - Your Holdings
                if !vm.portfolioStocks.isEmpty {
                    LazyVStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("Your Holdings")
                                .font(.title3.bold())
                                .foregroundStyle(Color.theme.accent)
                            
                            Spacer()
                            
                            Text("\(vm.portfolioStocks.count) stock\(vm.portfolioStocks.count == 1 ? "" : "s")")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal)
                        
                        ForEach(vm.portfolioStocks, id: \.id) { dbStock in
                            if let stockModel = Hvm.returnStockModel(symbol: dbStock.stockSymbol) {
                                PortfolioRowView(
                                    vm: StockRowViewModel(
                                        stock: stockModel,
                                        portfolioStock: dbStock
                                    ),
                                    authvm: authvm
                                )
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
            .padding(.vertical, 16)
        }
    }
    
    @ViewBuilder
    private var emptyPortfolioView: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.pie")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("Your Portfolio is Empty")
                .font(.title2.bold())
                .foregroundColor(.primary)
            
            Text("Start building your investment portfolio by purchasing your first stock")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            NavigationLink(destination: HomeView(authvm: authvm)) {
                Text("Explore Stocks")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.theme.accent)
                    .cornerRadius(12)
            }
            .padding(.horizontal, 40)
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
        .padding(.horizontal)
    }
    
    @ViewBuilder
    private var quickStatsView: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 12) {
            QuickStatCard(
                title: "Performance",
                value: String(format: "%.2f%%", vm.portfolioPerformancePercentage),
                color: vm.totalGainLoss >= 0 ? .green : .red,
                icon: vm.totalGainLoss >= 0 ? "arrow.up.right" : "arrow.down.right"
            )
            
            if let topHolding = vm.topHolding,
               let stockModel = Hvm.returnStockModel(symbol: topHolding.stockSymbol) {
                QuickStatCard(
                    title: "Top Holding",
                    value: topHolding.stockSymbol,
                    subtitle: stockModel.Last_Price.asCurrencyWith2Decimals(),
                    color: .blue,
                    icon: "star.fill"
                )
            } else {
                QuickStatCard(
                    title: "Diversification",
                    value: "\(vm.portfolioStocks.count)",
                    subtitle: "stocks",
                    color: .purple,
                    icon: "chart.bar.fill"
                )
            }
            
            if let topGainer = vm.topGainer,
               let stockModel = Hvm.returnStockModel(symbol: topGainer.stockSymbol) {
                let gainLoss = (stockModel.Last_Price - topGainer.avgBuyPrice) * Double(topGainer.quantity)
                QuickStatCard(
                    title: "Top Gainer",
                    value: topGainer.stockSymbol,
                    subtitle: gainLoss >= 0 ? "+\(gainLoss.asCurrencyWith2Decimals())" : gainLoss.asCurrencyWith2Decimals(),
                    color: gainLoss >= 0 ? .green : .red,
                    icon: gainLoss >= 0 ? "arrow.up.circle.fill" : "arrow.down.circle.fill"
                )
            } else {
                QuickStatCard(
                    title: "Total Value",
                    value: vm.portfolioValue.asCurrencyWith2Decimals(),
                    color: .orange,
                    icon: "dollarsign.circle.fill"
                )
            }
        }
        .padding(.horizontal)
    }
}

struct QuickStatCard: View {
    let title: String
    let value: String
    var subtitle: String = ""
    let color: Color
    let icon: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(color)
                
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.headline.bold())
                    .foregroundColor(color)
                    .lineLimit(1)
                
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            
            Text(title)
                .font(.caption2.weight(.medium))
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
    }
}

