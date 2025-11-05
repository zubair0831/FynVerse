import SwiftUI

struct DetailView: View {
    @StateObject private var vm: DetailViewModel
    @EnvironmentObject var homeVM: HomeViewModel
    @ObservedObject var authViewModel: AuthViewModel
    
    @Namespace private var animation
    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    init(stock: StockModel?, DBStock: DBPortfolioStock?, authViewModel: AuthViewModel) {
        _vm = StateObject(wrappedValue: DetailViewModel(stock: stock, DBStock: DBStock, authViewModel: authViewModel))
        self.authViewModel = authViewModel
    }
    
    var body: some View {
        ZStack {
            // Background
            Color.theme.background.ignoresSafeArea()
            
            // Main Content
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    // Chart Section
                    chartSection
                    
                    // Stock Info Card
                    stockInfoCard
                    
                    // Tab Section
                    VStack(spacing: 0) {
                        tabSelector
                        tabContent
                    }
                    .padding(.top, 8)
                }
                .padding(.bottom, 120) // Space for floating buttons
            }
            .refreshable {
                await vm.fetchStockDetails()
            }
            
            // Floating Buy/Sell Buttons
            floatingActionButtons
        }
        .task {
            await vm.fetchStockDetails()
        }
        .sheet(isPresented: $vm.showBuySheet) {
            if let stock = vm.stock {
                BuySellSheetView(stock: stock, isBuying: true, authViewModel: authViewModel)
                    .environmentObject(homeVM)
            }
        }
        .sheet(isPresented: $vm.showSellSheet) {
            if let stock = vm.stock {
                BuySellSheetView(stock: stock, isBuying: false, authViewModel: authViewModel)
                    .environmentObject(homeVM)
            }
        }
        .navigationTitle(vm.stock?.SYMBOL ?? "Stock")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if let stock = vm.stock {
                    HStack(spacing: 8) {
                        Text(stock.SYMBOL)
                            .font(.callout)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.theme.accent)
                        
                        StockImageView(stock: stock)
                            .frame(width: 28, height: 28)
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .stroke(Color.theme.accent.opacity(0.2), lineWidth: 1)
                            )
                    }
                }
            }
        }
    }
    
    // MARK: - Chart Section
    private var chartSection: some View {
        Group {
            if let stock = vm.stock {
                VStack(spacing: 0) {
                    StockChartView(symbol: stock.SYMBOL)
                        .frame(height: 300)
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                }
            }
        }
    }
    
    // MARK: - Stock Info Card
    private var stockInfoCard: some View {
        Group {
            if vm.isLoading {
                loadingView
            } else if let stock = vm.stock {
                VStack(spacing: 0) {
                    if let portfolioStock = vm.DBStock {
                        PortfolioRowView(
                            vm: StockRowViewModel(
                                stock: stock,
                                portfolioStock: portfolioStock
                            ),
                            authvm: authViewModel
                        )
                    } else {
                        StockRowView(stock: stock, authvm: authViewModel)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
        }
    }
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: Color.theme.accent))
                .scaleEffect(1.3)
            
            Text("Loading stock details...")
                .font(.subheadline)
                .foregroundColor(Color.theme.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
    
    // MARK: - Improved Uniform Tab Selector
    private var tabSelector: some View {
        HStack(spacing: 0) {
            ForEach(0..<3) { index in
                uniformTabButton(index: index)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.theme.cardBackground)
                .shadow(color: Color.theme.cardShadow.opacity(0.1), radius: 8, x: 0, y: 2)
        )
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
    
    private func uniformTabButton(index: Int) -> some View {
        Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                vm.selectedTab = index
            }
        } label: {
            VStack(spacing: 8) {
                // Icon
                Image(systemName: tabIcon(for: index))
                    .font(.title3)
                    .fontWeight(vm.selectedTab == index ? .semibold : .regular)
                    .foregroundStyle(vm.selectedTab == index ? .white : Color.theme.secondary)
                    .frame(height: 24)
                
                // Title
                Text(tabTitle(for: index))
                    .font(.caption)
                    .fontWeight(vm.selectedTab == index ? .semibold : .medium)
                    .foregroundStyle(vm.selectedTab == index ? .white : Color.theme.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                Group {
                    if vm.selectedTab == index {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.theme.accent)
                            .matchedGeometryEffect(id: "selectedTab", in: animation)
                            .shadow(color: Color.theme.accent.opacity(0.4), radius: 8, x: 0, y: 4)
                    }
                }
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func tabTitle(for index: Int) -> String {
        switch index {
        case 0: return "Details"
        case 1: return "News"
        case 2: return "Analysis"
        default: return ""
        }
    }
    
    private func tabIcon(for index: Int) -> String {
        switch index {
        case 0: return "chart.bar.fill"
        case 1: return "newspaper.fill"
        case 2: return "chart.line.uptrend.xyaxis"
        default: return "circle"
        }
    }

    // MARK: - Tab Content
    private var tabContent: some View {
        Group {
            switch vm.selectedTab {
            case 0:
                detailsTab
            case 1:
                newsTab
            case 2:
                analysisTab
            default:
                EmptyView()
            }
        }
    }
    
    // MARK: - Details Tab
    private var detailsTab: some View {
        VStack(spacing: 24) {
            // Company Overview Section
            if !vm.overviewTuples.isEmpty {
                VStack(spacing: 16) {
                    sectionHeader(
                        title: "Company Overview",
                        icon: "building.2.fill"
                    )
                    
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(vm.overviewTuples.prefix(vm.showMoreOverview ? vm.overviewTuples.count : 4), id: \.0) { item in
                            InfoCell(title: item.0, value: item.1)
                        }
                    }
                    
                    if vm.overviewTuples.count > 4 {
                        expandButton(
                            isExpanded: vm.showMoreOverview,
                            action: { withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                vm.showMoreOverview.toggle()
                            }}
                        )
                    }
                }
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.theme.cardBackground)
                        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
                )
                .padding(.horizontal, 16)
            }
            
            // Additional Metrics Section
            if !vm.additionalTuples.isEmpty {
                VStack(spacing: 16) {
                    sectionHeader(
                        title: "Additional Metrics",
                        icon: "chart.xyaxis.line"
                    )
                    
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(vm.additionalTuples.prefix(vm.showMoreDetails ? vm.additionalTuples.count : 4), id: \.0) { item in
                            InfoCell(title: item.0, value: item.1)
                        }
                    }
                    
                    if vm.additionalTuples.count > 4 {
                        expandButton(
                            isExpanded: vm.showMoreDetails,
                            action: { withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                vm.showMoreDetails.toggle()
                            }}
                        )
                    }
                }
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.theme.cardBackground)
                        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
                )
                .padding(.horizontal, 16)
            }
            
            // Shareholding Chart
            if let shareholding = vm.stockComprehensive?.shareholding {
                VStack(spacing: 16) {
                    sectionHeader(
                        title: "Shareholding Pattern",
                        icon: "chart.pie.fill"
                    )
                    
                    ShareholdingChartView(shareholding: shareholding)
                        .padding(.top, 8)
                }
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.theme.cardBackground)
                        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
                )
                .padding(.horizontal, 16)
            }
        }
        .padding(.vertical, 16)
    }
        
    // MARK: - News Tab
    private var newsTab: some View {
        Group {
            if let stock = vm.stock {
                StockNewsView(symbol: stock.SYMBOL)
                    .padding(.top, 16)
            } else {
                emptyStateView(
                    icon: "newspaper",
                    title: "No News Available",
                    message: "Stock information is not available"
                )
            }
        }
    }
    
    // MARK: - Analysis Tab
    private var analysisTab: some View {
        VStack(spacing: 0) {
            StockAnalysisView(stockSymbol: vm.stock?.SYMBOL ?? "RELIANCE")
                .padding(.top, 16)
        }
    }
    
    // MARK: - Helper Views
    private func sectionHeader(title: String, icon: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(Color.theme.accent)
            
            Text(title)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundStyle(Color.theme.primaryText)
            
            Spacer()
        }
    }
    
    private func expandButton(isExpanded: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(isExpanded ? "Show less" : "Show more")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.caption)
            }
            .foregroundStyle(Color.theme.accent)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.theme.accent.opacity(0.1))
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }
    
    private func emptyStateView(icon: String, title: String, message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundStyle(Color.theme.secondary.opacity(0.5))
            
            Text(title)
                .font(.headline)
                .foregroundStyle(Color.theme.primaryText)
            
            Text(message)
                .font(.subheadline)
                .foregroundStyle(Color.theme.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    // MARK: - Floating Action Buttons
    private var floatingActionButtons: some View {
        VStack {
            Spacer()
            
            HStack(spacing: 12) {
                // Buy Button
                Button {
                    vm.showBuySheet = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title3)
                        Text("Buy")
                            .font(.headline)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.theme.green)
                            .shadow(color: Color.theme.green.opacity(0.3), radius: 12, x: 0, y: 6)
                    )
                }
                
                // Sell Button
                Button {
                    vm.showSellSheet = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.title3)
                        Text("Sell")
                            .font(.headline)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.theme.red)
                            .shadow(color: Color.theme.red.opacity(0.3), radius: 12, x: 0, y: 6)
                    )
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(.ultraThinMaterial)
                    .shadow(color: .black.opacity(0.1), radius: 20, x: 0, y: -5)
            )
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
    }
}



// MARK: - Array Safe Access
extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
