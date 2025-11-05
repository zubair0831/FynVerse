//  HomeView.swift
//  FynVerse
//

import SwiftUI

// This is the model the SeeMoreButton will push
struct SeeMoreStocks: Hashable {
    let stocks: [StockModel]
}

struct HomeView: View {
    @EnvironmentObject private var vm: HomeViewModel
    @State private var showAddWatchlistAlert: Bool = false
    @State private var newWatchlistName: String = ""
    @State private var timerTask: Task<Void, Never>? = nil
    @ObservedObject var authvm: AuthViewModel
    
    // Namespace for the custom tab picker animation
    @Namespace private var namespace
    
    // State for the custom tab selection
    @State private var selectedHomeTab: HomeTab = .explore
    
    // State for market cap filters for each section
    @State private var gainersMarketCapFilter: MarketCapFilter = .all
    @State private var losersMarketCapFilter: MarketCapFilter = .all
    @State private var exploreMarketCapFilter: MarketCapFilter = .all
    
    enum HomeTab: String, CaseIterable, Identifiable {
        case explore = "Explore"
        case watchlists = "Watchlists"
        
        var id: String { self.rawValue }
    }
    
    enum MarketCapFilter: String, CaseIterable, Identifiable {
        case all = "All"
        case largeCap = "Large Cap"
        case midCap = "Mid Cap"
        case smallCap = "Small Cap"
        
        var id: String { self.rawValue }
        
        var icon: String {
            switch self {
            case .all: return "chart.bar.fill"
            case .largeCap: return "l.circle.fill"
            case .midCap: return "m.circle.fill"
            case .smallCap: return "s.circle.fill"
            }
        }
        
        var shortName: String {
            switch self {
            case .all: return "All"
            case .largeCap: return "Large"
            case .midCap: return "Mid"
            case .smallCap: return "Small"
            }
        }
        
        var description: String {
            switch self {
            case .all:
                return "All Stocks"
            case .largeCap:
                return "Top 100"
            case .midCap:
                return "Top 101-350"
            case .smallCap:
                return "Remaining"
            }
        }
        
        func next() -> MarketCapFilter {
            let all = MarketCapFilter.allCases
            guard let currentIndex = all.firstIndex(of: self) else { return .all }
            let nextIndex = (currentIndex + 1) % all.count
            return all[nextIndex]
        }
    }
    
    var body: some View {
        ZStack {
            backgroundColor
            mainContent
        }
        .onAppear {
            startTimerIfNeeded()
        }
        .onDisappear {
            stopTimer()
        }
        .task(id: vm.userWatchlists.isEmpty) {
            await fetchWatchlistsIfNeeded()
        }
        .alert("New Watchlist", isPresented: $showAddWatchlistAlert) {
            watchlistAlert
        }
    }
    
    // MARK: - Computed Properties
    private var backgroundColor: some View {
        Color.theme.background.ignoresSafeArea()
    }
    
    private var mainContent: some View {
        VStack(spacing: 0) {
            if vm.allStocks.isEmpty {
                loadingView
            } else {
                stocksContent
            }
        }
    }
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
                .tint(Color.theme.accent)
                .padding(.top, 50)
                
            Text("Loading market data...")
                .font(.subheadline)
                .foregroundStyle(Color.theme.secondary)
        }
    }
    
    private var stocksContent: some View {
        VStack(spacing: 0) {
            statisticsSection
            scrollableContent
        }
    }
    
    private var statisticsSection: some View {
        // Reduced vertical padding for compactness
        CompactStatisticsView(nifty50: vm.returnStockModel(symbol: "NIFTY50"), authvm: authvm)
            .padding(.top, 4)
            .padding(.bottom, 2)
    }
    
    private var scrollableContent: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                Divider()
                    .background(Color.theme.divider)
                    .padding(.bottom, 0)
                    
                customHomeTabPicker // Use the new custom picker
                    
                tabContent
                footerSection
            }
        }
        .refreshable {
            await refreshData()
        }
    }
    
    // MARK: - Custom Tab Picker (Sleeker design)
    private var customHomeTabPicker: some View {
        HStack(spacing: 0) {
            ForEach(HomeTab.allCases) { tab in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedHomeTab = tab
                    }
                } label: {
                    Text(tab.rawValue)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .foregroundStyle(selectedHomeTab == tab ? Color.theme.cardBackground : Color.theme.secondary)
                }
                .background(
                    ZStack {
                        if selectedHomeTab == tab {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.theme.accent)
                                .shadow(color: Color.theme.accent.opacity(0.3), radius: 6, x: 0, y: 3)
                                .matchedGeometryEffect(id: "selectedTab", in: namespace)
                        }
                    }
                )
                .cornerRadius(12)
            }
        }
        .padding(4) // Padding inside the container for a pill-like effect
        .background(Color.theme.cardBackground.opacity(0.9)) // Soft background for the bar
        .cornerRadius(16)
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
    }
    
    @ViewBuilder
    private var tabContent: some View {
        switch selectedHomeTab {
        case .explore:
            exploreTabContent
        case .watchlists:
            watchlistsSection
        }
    }
    
    private var exploreTabContent: some View {
        // Adjusted spacing for better flow
        VStack(spacing: 20) {
            // Top Gainers Section using the improved card layout
            stockCardSection(
                title: "Top Gainers",
                titleIcon: "arrow.up.right",
                iconColor: Color.theme.success,
                filter: $gainersMarketCapFilter,
                filteredStocks: getFilteredGainers(),
                seeMoreTitle: getGainersSeeMoreTitle(),
                baseStocks: vm.topGainerStocks
            )
            
            // Top Losers Section using the improved card layout
            stockCardSection(
                title: "Top Losers",
                titleIcon: "arrow.down.right",
                iconColor: Color.theme.red,
                filter: $losersMarketCapFilter,
                filteredStocks: getFilteredLosers(),
                seeMoreTitle: getLosersSeeMoreTitle(),
                baseStocks: vm.topLooserStocks
            )
            
            exploreStocksSection // Improved grid layout
        }
        .padding(.top, 8)
        .padding(.bottom, 24)
    }
    
    // MARK: - Reusable Stock Card Section (Gainers/Losers) - Improved with better alignment
    private func stockCardSection(
        title: String,
        titleIcon: String,
        iconColor: Color,
        filter: Binding<MarketCapFilter>,
        filteredStocks: [StockModel],
        seeMoreTitle: String,
        baseStocks: [StockModel]
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            
            // MODIFIED: Header now contains Title, Market Cap Filter (1st), and See More Button (2nd)
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: titleIcon)
                        .font(.body)
                        .fontWeight(.bold)
                        .foregroundStyle(iconColor)
                        .frame(width: 20, height: 20)
                        
                    Text(title)
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.theme.primaryText)
                }
                
                Spacer()
                
                // Compact Market Cap Filter Chip
                marketCapFilterChip(
                    currentFilter: filter.wrappedValue,
                    stockCount: getStockCount(for: filter.wrappedValue, in: baseStocks)
                ) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        filter.wrappedValue = filter.wrappedValue.next()
                    }
                }
                // Separator space between the two buttons
                .padding(.trailing, 8)
                
                // See More Button (Now in the header)
                SeeMoreButton(
                    resultantStocks: filteredStocks,
                    title: seeMoreTitle,
                    authvm: authvm
                )
                .font(.caption)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            // Added bottom padding to separate the header from the horizontal scroll view
            .padding(.bottom, 8)
            
            // Horizontal Scroll List with Improved Cards
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 12) {
                    ForEach(filteredStocks.prefix(5)) { stock in
                        NavigationLink(destination: DetailView(stock: stock, DBStock: nil, authViewModel: authvm)) {
                           StockExploreView(stock: stock, authvm: authvm)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)                // REMOVED: .padding(.bottom, 16) to reduce space at the bottom of the content
            }
            
            // REMOVED: The old separate HStack for the See More Button and its .padding(.bottom, 20)
        }
        // Enhanced card styling with subtle shadow
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.theme.cardBackground)
                .shadow(color: Color.theme.cardShadow, radius: 8, x: 0, y: 4)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.theme.divider, lineWidth: 1)
                )
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 0) // Ensures no implicit bottom padding from the card itself
    }
    
    // MARK: - Explore Stocks Section (Improved Grid)
    private var exploreStocksSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            exploreHeader
            exploreStockGrid
        }
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.theme.cardBackground)
                .shadow(color: Color.theme.cardShadow, radius: 8, x: 0, y: 4)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.theme.divider, lineWidth: 1)
                )
        )
        .padding(.horizontal, 16)
    }
    
    private var exploreHeader: some View {
        HStack {
            HStack(spacing: 8) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.body)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.theme.blue)
                    .frame(width: 20, height: 20)
                    
                Text("Explore Stocks")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.theme.primaryText)
            }
            .padding(.leading, 20)
            .padding(.top, 20)
            
            Spacer()
            
            HStack(spacing: 12) {
                // Compact Market Cap Filter Button
                marketCapFilterChip(
                    currentFilter: exploreMarketCapFilter,
                    stockCount: getStockCount(for: exploreMarketCapFilter, in: vm.allStocks)
                ) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        exploreMarketCapFilter = exploreMarketCapFilter.next()
                    }
                }
                
                SeeMoreButton(
                    resultantStocks: getFilteredExploreStocks(),
                    title: getExploreSeeMoreTitle(),
                    authvm: authvm
                )
                .font(.caption)
            }
            .padding(.trailing, 20)
            .padding(.top, 20)
        }
    }
    
    private var exploreStockGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible())
                ],
                spacing: 12
            ) {
                ForEach(Array(getFilteredExploreStocks().prefix(6))) { stock in
                    NavigationLink(destination: DetailView(stock: stock, DBStock: nil, authViewModel: authvm)) {
                        StockExploreView(stock: stock, authvm: authvm)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
    }
    
    // MARK: - Improved Market Cap Filter Chip
    private func marketCapFilterChip(
        currentFilter: MarketCapFilter,
        stockCount: Int,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: currentFilter.icon)
                    .font(.subheadline)
                    .foregroundStyle(Color.theme.primaryText)
                    
                VStack(alignment: .leading, spacing: 0) {
                    Text(currentFilter.shortName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(Color.theme.primaryText)
                        
                    if currentFilter != .all {
                        Text("(\(stockCount))")
                            .font(.caption2)
                            .foregroundStyle(Color.theme.secondary)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.theme.accent.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.theme.accent.opacity(0.3), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }
    
    // MARK: - Improved Stock Card View (Based on StockExploreView for consistency)
    
    
    private var footerSection: some View {
        VStack(spacing: 8) {
            Divider()
                .background(Color.theme.divider)
                .padding(.bottom, 8)
                
            Text("Fynverse Private Limited")
                .font(.callout)
                .fontWeight(.medium)
                .foregroundStyle(Color.theme.secondary)
                
            Text("fynverse@gmail.com")
                .font(.footnote)
                .foregroundStyle(Color.theme.secondary.opacity(0.7))
        }
        .padding(.vertical, 20)
    }
    
    // MARK: - Watchlists Section (Updated styling)
    private var watchlistsSection: some View {
        VStack(alignment: .leading, spacing: 12) { // Reduced spacing
            watchlistsHeader
            watchlistsContent
        }
        .padding(.top, 8)
        .padding(.bottom, 24)
    }
    
    private var watchlistsHeader: some View {
        HStack {
            HStack(spacing: 10) {
                Image(systemName: "star.fill")
                    .font(.body)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.theme.warning)
                    .frame(width: 20, height: 20)
                    
                Text("My Watchlists")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.theme.primaryText)
            }
            
            Spacer()
            
            Button {
                showAddWatchlistAlert = true
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "plus.circle.fill")
                    Text("New Watchlist")
                }
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.theme.accent)
                        .shadow(color: Color.theme.accent.opacity(0.4), radius: 4, x: 0, y: 2)
                )
            }
            .buttonStyle(ScaleButtonStyle())
        }
        .padding(.horizontal, 20)
    }
    
    @ViewBuilder
    private var watchlistsContent: some View {
        if vm.userWatchlists.isEmpty {
            VStack(spacing: 12) { // Reduced spacing
                Image(systemName: "magnifyingglass.circle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(Color.theme.accent.opacity(0.3))
                    .padding(.top, 30)
                    
                Text("No watchlists found")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.theme.primaryText)
                    
                Text("Start tracking your investments by creating a new watchlist above.")
                    .font(.subheadline)
                    .foregroundStyle(Color.theme.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 30)
                    .padding(.bottom, 30)
            }
            .frame(maxWidth: .infinity)
            // Consistent card styling
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.theme.cardBackground)
                    .shadow(color: Color.theme.cardShadow, radius: 8, x: 0, y: 4)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.theme.divider, lineWidth: 1)
                    )
            )
            .padding(.horizontal, 16)
        } else {
            VStack(spacing: 12) { // Increased spacing for better separation
                ForEach(vm.userWatchlists.indices, id: \.self) { index in
                    NavigationLink(destination: WatchlistDetailView(watchlist: vm.userWatchlists[index], homeVM: vm, authvm: authvm)) {
                        // Assuming WatchlistCardView is already relatively sleek
                        WatchlistCardView(watchlist: vm.userWatchlists[index], authvm: authvm)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
        }
    }
    
    private var watchlistAlert: some View {
        Group {
            TextField("Watchlist Name", text: $newWatchlistName)
            Button("Create") {
                createWatchlist()
            }
            Button("Cancel", role: .cancel) {
                newWatchlistName = ""
            }
        }
    }
    
    // MARK: - Filtering Helper Methods (Unchanged)
    private func getFilteredGainers() -> [StockModel] {
        let baseStocks = vm.topGainerStocks
        return applyMarketCapFilter(to: baseStocks, filter: gainersMarketCapFilter)
    }
    
    private func getFilteredLosers() -> [StockModel] {
        let baseStocks = vm.topLooserStocks
        return applyMarketCapFilter(to: baseStocks, filter: losersMarketCapFilter)
    }
    
    private func getFilteredExploreStocks() -> [StockModel] {
        let baseStocks = vm.allStocks
        return applyMarketCapFilter(to: baseStocks, filter: exploreMarketCapFilter)
    }
    
    private func applyMarketCapFilter(to stocks: [StockModel], filter: MarketCapFilter) -> [StockModel] {
        switch filter {
        case .all:
            return stocks
        case .largeCap:
            return stocks.filter { stock in
                vm.largeCapStocks.contains { $0.SYMBOL == stock.SYMBOL }
            }
        case .midCap:
            return stocks.filter { stock in
                vm.midCapStocks.contains { $0.SYMBOL == stock.SYMBOL }
            }
        case .smallCap:
            return stocks.filter { stock in
                vm.smallCapStocks.contains { $0.SYMBOL == stock.SYMBOL }
            }
        }
    }
    
    private func getStockCount(for filter: MarketCapFilter, in stocks: [StockModel]) -> Int {
        return applyMarketCapFilter(to: stocks, filter: filter).count
    }
    
    // MARK: - See More Title Helpers (Unchanged)
    private func getGainersSeeMoreTitle() -> String {
        if gainersMarketCapFilter == .all {
            return "Top Gainers For Today"
        } else {
            return "\(gainersMarketCapFilter.rawValue) - Top Gainers For Today"
        }
    }
    
    private func getLosersSeeMoreTitle() -> String {
        if losersMarketCapFilter == .all {
            return "Top Losers For Today"
        } else {
            return "\(losersMarketCapFilter.rawValue) - Top Losers For Today"
        }
    }
    
    private func getExploreSeeMoreTitle() -> String {
        if exploreMarketCapFilter == .all {
            return "All Stocks listed in NSE"
        } else {
            return "\(exploreMarketCapFilter.rawValue) - All Stocks listed in NSE"
        }
    }
    
    // MARK: - Lifecycle Methods (Unchanged)
    private func startTimerIfNeeded() {
        if timerTask == nil {
            timerTask = Task {
                while !Task.isCancelled {
                    await vm.fetchStocks()
                    try? await Task.sleep(nanoseconds: 5 * 60 * 1_000_000_000)
                }
            }
        }
    }
    
    private func stopTimer() {
        timerTask?.cancel()
        timerTask = nil
    }
    
    private func fetchWatchlistsIfNeeded() async {
        if vm.userWatchlists.isEmpty {
            await vm.fetchUserWatchlists()
        }
    }
    
    private func refreshData() async {
        await vm.fetchStocks()
        await vm.fetchUserWatchlists()
    }
    
    private func createWatchlist() {
        if !newWatchlistName.isEmpty {
            Task {
                await vm.addWatchlist(name: newWatchlistName)
                newWatchlistName = ""
            }
        }
    }
}

// MARK: - Custom Button Style (Unchanged)
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}
