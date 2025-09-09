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
    
    // State for the segmented picker selection
    @State private var selectedHomeTab: HomeTab = .explore
    
    // State for market cap filters for each section
    @State private var gainersMarketCapFilter: MarketCapFilter = .all
    @State private var losersMarketCapFilter: MarketCapFilter = .all
    @State private var exploreMarketCapFilter: MarketCapFilter = .all
    
    // States for dropdown visibility
    @State private var showGainersDropdown: Bool = false
    @State private var showLosersDropdown: Bool = false
    @State private var showExploreDropdown: Bool = false
    
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
                return "Top 100 Companies"
            case .midCap:
                return "Top 101-350 Companies"
            case .smallCap:
                return "Remaining Companies"
            }
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
        VStack {
            if vm.allStocks.isEmpty {
                loadingView
            } else {
                stocksContent
            }
        }
    }
    
    private var loadingView: some View {
        ProgressView()
            .tint(Color.theme.accent)
    }
    
    private var stocksContent: some View {
        VStack {
            statisticsSection
            scrollableContent
        }
    }
    
    private var statisticsSection: some View {
        CompactStatisticsView(nifty50: vm.returnStockModel(symbol: "NIFTY50"), authvm: authvm)
            .padding(.top, 8)
    }
    private var scrollableContent: some View {
        ScrollView {
            VStack(spacing: 0) {
                Divider()
                homeTabPicker
                tabContent
                footerSection
            }
        }
        .refreshable {
            await refreshData()
        }
    }
    
    private var homeTabPicker: some View {
        Picker("Home Content", selection: $selectedHomeTab) {
            ForEach(HomeTab.allCases) { tab in
                Text(tab.rawValue).tag(tab)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal)
        .padding(.vertical, 4)
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
        VStack(spacing: 24) {
            topGainersSection
            topLosersSection
            exploreStocksSection
        }
        .padding(.top, 8)
        .padding(.bottom, 16)
    }
    
    private var footerSection: some View {
        VStack {
            Text("Fynverse private limited")
                .font(.title3)
                .fontWeight(.light)
                .padding(.top, 20)
            Text("fynverse@gmail.com")
                .font(.subheadline)
                .fontWeight(.light)
        }
    }
    
    // MARK: - Top Gainers Section
    private var topGainersSection: some View {
        LazyVStack(alignment: .leading, spacing: 12) {
            gainersHeader
            gainersStockList
        }
        .padding()
        .background(Color.theme.background.opacity(0.1))
        .cornerRadius(16)
        .padding(.horizontal, 16)
    }
    
    private var gainersHeader: some View {
        HStack {
            Text("Top Gainers")
                .font(.headline)
                .bold()
            
            Spacer()
            
            // Market Cap Filter Dropdown
            marketCapDropdown(
                currentFilter: gainersMarketCapFilter,
                showDropdown: $showGainersDropdown,
                stocks: vm.topGainerStocks
            ) { filter in
                gainersMarketCapFilter = filter
                showGainersDropdown = false
            }
            
            SeeMoreButton(
                resultantStocks: getFilteredGainers(),
                title: getGainersSeeMoreTitle(),
                authvm: authvm
            )
        }
        .foregroundStyle(Color.theme.accent)
    }
    
    private var gainersStockList: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 12) {
                ForEach(getFilteredGainers().prefix(4)) { stock in
                    NavigationLink(destination: DetailView(stock: stock, DBStock: nil, authViewModel: authvm)) {
                        StockExploreView(stock: stock, authvm: authvm)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.top, 4)
        }
    }
    
    // MARK: - Top Losers Section
    private var topLosersSection: some View {
        LazyVStack(alignment: .leading, spacing: 12) {
            losersHeader
            losersStockList
        }
        .padding()
        .background(Color.theme.background.opacity(0.1))
        .cornerRadius(16)
        .padding(.horizontal, 16)
    }
    
    private var losersHeader: some View {
        HStack {
            Text("Top Losers")
                .font(.headline)
                .bold()
            
            Spacer()
            
            // Market Cap Filter Dropdown
            marketCapDropdown(
                currentFilter: losersMarketCapFilter,
                showDropdown: $showLosersDropdown,
                stocks: vm.topLooserStocks
            ) { filter in
                losersMarketCapFilter = filter
                showLosersDropdown = false
            }
            
            SeeMoreButton(
                resultantStocks: getFilteredLosers(),
                title: getLosersSeeMoreTitle(),
                authvm: authvm
            )
        }
        .foregroundStyle(Color.theme.accent)
    }
    
    private var losersStockList: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 12) {
                ForEach(getFilteredLosers().prefix(4)) { stock in
                    NavigationLink(destination: DetailView(stock: stock, DBStock: nil, authViewModel: authvm)) {
                        StockExploreView(stock: stock, authvm: authvm)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.top, 4)
        }
    }
    
    // MARK: - Explore Stocks Section
    private var exploreStocksSection: some View {
        LazyVStack(alignment: .leading, spacing: 12) {
            exploreHeader
            exploreStockGrid
        }
        .padding()
        .background(Color.theme.background.opacity(0.1))
        .cornerRadius(16)
        .padding(.horizontal, 16)
    }
    
    private var exploreHeader: some View {
        HStack {
            Text("Explore Stocks")
                .font(.headline)
                .bold()
            
            Spacer()
            
            // Market Cap Filter Dropdown
            marketCapDropdown(
                currentFilter: exploreMarketCapFilter,
                showDropdown: $showExploreDropdown,
                stocks: vm.allStocks
            ) { filter in
                exploreMarketCapFilter = filter
                showExploreDropdown = false
            }
            
            SeeMoreButton(
                resultantStocks: getFilteredExploreStocks(),
                title: getExploreSeeMoreTitle(),
                authvm: authvm
            )
        }
        .foregroundStyle(Color.theme.accent)
    }
    
    private var exploreStockGrid: some View {
        LazyVGrid(
            columns: [GridItem(.flexible()), GridItem(.flexible())],
            spacing: 12
        ) {
            ForEach(Array(getFilteredExploreStocks().prefix(6))) { stock in
                NavigationLink(destination: DetailView(stock: stock, DBStock: nil, authViewModel: authvm)) {
                    StockExploreView(stock: stock, authvm: authvm)
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    // MARK: - Market Cap Dropdown Component
    private func marketCapDropdown(
        currentFilter: MarketCapFilter,
        showDropdown: Binding<Bool>,
        stocks: [StockModel],
        onSelection: @escaping (MarketCapFilter) -> Void
    ) -> some View {
        VStack {
            // Dropdown Button
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showDropdown.wrappedValue.toggle()
                }
            } label: {
                HStack(spacing: 6) {
                    Text(currentFilter.shortName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Image(systemName: showDropdown.wrappedValue ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(Color.theme.accent)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.theme.accent.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.theme.accent.opacity(0.3), lineWidth: 1)
                        )
                )
            }
            
            // Dropdown Menu
            if showDropdown.wrappedValue {
                VStack(spacing: 0) {
                    ForEach(MarketCapFilter.allCases) { filter in
                        Button {
                            onSelection(filter)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(filter.rawValue)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    
                                    Text(filter.description)
                                        .font(.caption2)
                                        .foregroundStyle(Color.theme.secondary)
                                    
                                    if filter != .all {
                                        Text("\(getStockCount(for: filter, in: stocks)) stocks")
                                            .font(.caption2)
                                            .foregroundStyle(Color.theme.accent)
                                    }
                                }
                                
                                Spacer()
                                
                                if currentFilter == filter {
                                    Image(systemName: "checkmark")
                                        .font(.caption)
                                        .foregroundStyle(Color.theme.accent)
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(
                                currentFilter == filter
                                ? Color.theme.accent.opacity(0.1)
                                : Color.clear
                            )
                        }
                        .buttonStyle(.plain)
                        
                        if filter != MarketCapFilter.allCases.last {
                            Divider()
                                .padding(.leading, 12)
                        }
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.theme.cardBackground)
                        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                )
                .padding(.top, 4)
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.95).combined(with: .opacity),
                    removal: .scale(scale: 0.95).combined(with: .opacity)
                ))
            }
        }
        .zIndex(1000) // Ensure dropdown appears above other content
    }
    
    // MARK: - Watchlists Section
    private var watchlistsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            watchlistsHeader
            watchlistsContent
        }
        .padding(.vertical, 8)
    }
    
    private var watchlistsHeader: some View {
        HStack {
            Text("My Watchlists")
                .font(.headline)
                .bold()
            Spacer()
            Button {
                showAddWatchlistAlert = true
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                    .foregroundStyle(Color.theme.accent)
            }
        }
        .padding(.horizontal)
    }
    
    @ViewBuilder
    private var watchlistsContent: some View {
        if vm.userWatchlists.isEmpty {
            Text("No watchlists yet. Tap '+' to create one!")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding(.horizontal)
        } else {
            ForEach(vm.userWatchlists.indices, id: \.self) { index in
                NavigationLink(destination: WatchlistDetailView(watchlist: vm.userWatchlists[index], homeVM: vm, authvm: authvm)) {
                    WatchlistCardView(watchlist: vm.userWatchlists[index], authvm: authvm)
                }
                .buttonStyle(.plain)
            }
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
    
    // MARK: - Filtering Helper Methods
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
    
    // MARK: - See More Title Helpers
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
    
    // MARK: - Lifecycle Methods
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
