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
    @ObservedObject var authvm:AuthViewModel
    
    
    // State for the segmented picker selection
    @State private var selectedHomeTab: HomeTab = .explore
    
    enum HomeTab: String, CaseIterable, Identifiable {
        case explore = "Explore"
        case watchlists = "Watchlists"
        
        var id: String { self.rawValue }
    }
    
    var body: some View {
        
        ZStack {
            Color.theme.background.ignoresSafeArea()
            VStack {
                if vm.allStocks.isEmpty {
                    ProgressView()
                        .tint(Color.theme.accent)
                } else {
                    if let stock = vm.returnStockModel(symbol: "NIFTY50") {
                        StatisticsView(nifty50: stock, authvm: authvm)
                            .padding()
                    }
                    
                    ScrollView {
                        
                        Divider()
                        
                        // MARK: - Segmented Picker for Home Content
                        Picker("Home Content", selection: $selectedHomeTab) {
                            ForEach(HomeTab.allCases) { tab in
                                Text(tab.rawValue).tag(tab)
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal)
                        .padding(.vertical, 4)
                        
                        
                        // Conditional content based on picker selection
                        switch selectedHomeTab {
                        case .explore:
                            VStack(spacing: 24) {
                                TopGainersView
                                TopLoosersView
                                ExploreView
                            }
                            .padding(.top, 8)
                            .padding(.bottom, 16)
                        case .watchlists:
                            WatchlistsSection
                        }
                        
                        Text("Fynverse private limited")
                            .font(.title3)
                            .fontWeight(.light)
                            .padding(.top, 20)
                        Text("fynverse@gmail.com")
                            .font(.subheadline)
                            .fontWeight(.light)
                    }
                    .refreshable {
                        await vm.fetchStocks()
                        await vm.fetchUserWatchlists()
                    }
                    
                }
            }
            
            // NEW: Navigation destination for WatchlistDetailView
            
        }
        .onAppear {
            if timerTask == nil {
                timerTask = Task {
                    while !Task.isCancelled {
                        await vm.fetchStocks()
                        try? await Task.sleep(nanoseconds: 5 * 60 * 1_000_000_000)
                    }
                }
            }
        }
        .onDisappear {
            timerTask?.cancel()
            timerTask = nil
        }
        
        .task(id: vm.userWatchlists.isEmpty) {
            if vm.userWatchlists.isEmpty {
                await vm.fetchUserWatchlists()
            }
        }
        .alert("New Watchlist", isPresented: $showAddWatchlistAlert) {
            TextField("Watchlist Name", text: $newWatchlistName)
            Button("Create") {
                if !newWatchlistName.isEmpty {
                    Task {
                        await vm.addWatchlist(name: newWatchlistName)
                        newWatchlistName = ""
                    }
                }
            }
            Button("Cancel", role: .cancel) {
                newWatchlistName = ""
            }
        }
        
    }
    
    // All of the following sub-views remain correct, as they only contain NavigationLink(value: ...)
    private var TopLoosersView: some View {
        LazyVStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Top Losers")
                    .font(.headline)
                    .bold()
                Spacer()
                SeeMoreButton(resultantStocks: vm.topLooserStocks, title: "Top Losers For Today", authvm: authvm)
            }
            .foregroundStyle(Color.theme.accent)
            
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 12) {
                    ForEach(vm.topLooserStocks.prefix(4)) { stock in
                        NavigationLink(destination: DetailView(stock: stock, DBStock: nil, authViewModel: authvm)) {
                            StockExploreView(stock: stock)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding()
        .background(Color.theme.background.opacity(0.1))
        .cornerRadius(16)
        .padding(.horizontal, 16)
    }
    
    var TopGainersView: some View {
        LazyVStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Top Gainers")
                    .font(.headline)
                    .bold()
                Spacer()
                SeeMoreButton(resultantStocks: vm.topGainerStocks, title: "Top Gainers For Today", authvm: authvm)
            }
            .foregroundStyle(Color.theme.accent)
            
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 12) {
                    ForEach(vm.topGainerStocks.prefix(4)) { stock in
                        NavigationLink(destination: DetailView(stock: stock, DBStock: nil, authViewModel: authvm)) {
                            StockExploreView(stock: stock)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding()
        .background(Color.theme.background.opacity(0.1))
        .cornerRadius(16)
        .padding(.horizontal, 16)
    }
    
    var ExploreView: some View {
        LazyVStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Explore Stocks")
                    .font(.headline)
                    .bold()
                Spacer()
                SeeMoreButton(resultantStocks: vm.allStocks, title: "All Stocks listed in NSE", authvm: authvm)
            }
            .foregroundStyle(Color.theme.accent)
            
            LazyVGrid(
                columns: [GridItem(.flexible()), GridItem(.flexible())],
                spacing: 12
            ) {
                ForEach(vm.allStocks.dropFirst().prefix(6)) { stock in
                    NavigationLink(destination: DetailView(stock: stock, DBStock: nil, authViewModel: authvm)) {
                        StockExploreView(stock: stock)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding()
        .background(Color.theme.background.opacity(0.1))
        .cornerRadius(16)
        .padding(.horizontal, 16)
    }
    private var WatchlistsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
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
        .padding(.vertical, 8)
    }
}
