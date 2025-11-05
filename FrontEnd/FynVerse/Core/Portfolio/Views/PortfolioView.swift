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
                .fill(Color.theme.cardBackground)
                .shadow(color: Color.theme.cardShadow, radius: 4, x: 0, y: 2)
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
                            HStack(spacing: 8) {
                                Image(systemName: "briefcase.fill")
                                    .foregroundStyle(Color.theme.accent)
                                    .font(.title3)
                                
                                Text("Your Holdings")
                                    .font(.title3.bold())
                                    .foregroundStyle(Color.theme.accent)
                            }
                            
                            Spacer()
                            
                            Text("\(vm.portfolioStocks.count) stock\(vm.portfolioStocks.count == 1 ? "" : "s")")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundStyle(Color.theme.secondary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.theme.accent.opacity(0.1))
                                )
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
        VStack(spacing: 20) {
            Image(systemName: "chart.pie")
                .font(.system(size: 70))
                .foregroundStyle(Color.theme.accent.opacity(0.5))
                .padding(.top, 20)
            
            VStack(spacing: 8) {
                Text("Your Portfolio is Empty")
                    .font(.title2.bold())
                    .foregroundStyle(Color.theme.accent)
                
                Text("Start building your investment portfolio by purchasing your first stock")
                    .font(.subheadline)
                    .foregroundStyle(Color.theme.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }
            
            NavigationLink(destination: HomeView(authvm: authvm)) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.headline)
                    Text("Explore Stocks")
                        .font(.headline)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.theme.accent)
                        .shadow(color: Color.theme.accent.opacity(0.3), radius: 4, x: 0, y: 2)
                )
            }
            .padding(.horizontal, 40)
            .padding(.top, 8)
            .padding(.bottom, 20)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.theme.cardBackground)
                .shadow(color: Color.theme.cardShadow, radius: 8, x: 0, y: 2)
        )
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
                subtitle: "Overall",
                color: vm.totalGainLoss >= 0 ? Color.theme.success : Color.theme.red,
                icon: vm.totalGainLoss >= 0 ? "arrow.up.right" : "arrow.down.right",
                gradient: vm.totalGainLoss >= 0 ? Color.theme.cardGradient2 : Color.theme.cardGradient1
            )
            
            if let topHolding = vm.topHolding,
               let stockModel = Hvm.returnStockModel(symbol: topHolding.stockSymbol) {
                QuickStatCard(
                    title: "Top Holding",
                    value: topHolding.stockSymbol,
                    subtitle: stockModel.Last_Price.asCurrencyWith2Decimals(),
                    color: Color.theme.info,
                    icon: "star.fill",
                    gradient: Color.theme.cardGradient1
                )
            } else {
                QuickStatCard(
                    title: "Diversification",
                    value: "\(vm.portfolioStocks.count)",
                    subtitle: "stocks",
                    color: Color.theme.accent,
                    icon: "chart.bar.fill",
                    gradient: Color.theme.cardGradient1
                )
            }
            
            if let topGainer = vm.topGainer,
               let stockModel = Hvm.returnStockModel(symbol: topGainer.stockSymbol) {
                let gainLoss = (stockModel.Last_Price - topGainer.avgBuyPrice) * Double(topGainer.quantity)
                QuickStatCard(
                    title: "Top Gainer",
                    value: topGainer.stockSymbol,
                    subtitle: gainLoss >= 0 ? "+\(gainLoss.asCurrencyWith2Decimals())" : gainLoss.asCurrencyWith2Decimals(),
                    color: gainLoss >= 0 ? Color.theme.success : Color.theme.red,
                    icon: gainLoss >= 0 ? "arrow.up.circle.fill" : "arrow.down.circle.fill",
                    gradient: gainLoss >= 0 ? Color.theme.cardGradient2 : nil
                )
            } else {
                QuickStatCard(
                    title: "Total Value",
                    value: vm.portfolioValue.asCurrencyWith2Decimals(),
                    color: Color.theme.warning,
                    icon: "dollarsign.circle.fill",
                    gradient: nil
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
    var gradient: LinearGradient? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.15))
                        .frame(width: 28, height: 28)
                    
                    Image(systemName: icon)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(color)
                }
                
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
                        .foregroundColor(Color.black)
                        .lineLimit(1)
                }
            }
            
            Text(title)
                .font(.caption2.weight(.medium))
                .foregroundColor(Color.black)
                .lineLimit(1)
        }
        .padding(14)
        .background(
            Group {
                if let gradient = gradient {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(gradient)
                        .shadow(color: color.opacity(0.3), radius: 8, x: 0, y: 4)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(.white.opacity(0.2), lineWidth: 1)
                        )
                } else {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.theme.cardBackground)
                        .shadow(color: Color.theme.cardShadow, radius: 8, x: 0, y: 4)
                }
            }
        )
    }
}
