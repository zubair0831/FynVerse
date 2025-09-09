import SwiftUI

struct DetailView: View {
    @StateObject private var vm: DetailViewModel
    @StateObject private var predictionVM = StockPredictionViewModel()
    @StateObject private var summaryVM: StockSummaryViewModel
    
    @EnvironmentObject var homeVM: HomeViewModel
    @ObservedObject var authViewModel: AuthViewModel
    
    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    init(stock: StockModel?, DBStock: DBPortfolioStock?, authViewModel: AuthViewModel) {
        _vm = StateObject(wrappedValue: DetailViewModel(stock: stock, DBStock: DBStock, authViewModel: authViewModel))
        _summaryVM = StateObject(wrappedValue: StockSummaryViewModel(stockName: stock?.NAME_OF_COMPANY ?? ""))
        self.authViewModel = authViewModel
    }

    var body: some View {
        ZStack {
            Color.theme.background.ignoresSafeArea()
            
                ScrollView {
                    VStack(spacing: 20) {
                        
                        // Chart
                        if let stock = vm.stock {
                            VStack(spacing: 0) {
                                StockChartView(symbol: stock.SYMBOL)
                                    .frame(height: 280)
                                    .padding(.horizontal)
                                    .padding(.top, 12)
                                Divider()
                                    .padding(.horizontal)
                                    .padding(.bottom, 6)
                            }
                        }
                        if vm.isLoading {
                            VStack {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: Color.theme.accent))
                                    .scaleEffect(1.5)
                                Text("Loading stock details...")
                                    .font(.headline)
                                    .padding(.top, 10)
                                    .foregroundColor(Color.theme.accent)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        } else {
                            
                            // Predictions
                            if let stock = vm.stock {
                                Next5DPredictionView(
                                    stockSymbol: stock.SYMBOL,
                                    prediction: predictionVM.next5DPrediction,
                                    isLoading: predictionVM.isLoading,
                                    animateSpinner: predictionVM.animateSpinner
                                )
                                .padding(.top)
                            }
                            
                            // Tab Selector + Content
                            tabSelector
                            tabDetailView
                        }
                    }
                            .padding(.bottom, 100)
                
            }
            
            // Floating Buttons
            floatingBuySellView
        }
        
        .task {
            await vm.fetchStockDetails()
            guard let stock = vm.stock else { return }
            await predictionVM.fetchPredictions(for: stock.SYMBOL)
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
                    HStack {
                        Text(stock.SYMBOL)
                            .font(.headline)
                            .foregroundStyle(Color.theme.secondary)
                        StockImageView(stock: stock)
                            .frame(width: 25, height: 25)
                    }
                }
            }
        }
    }
    
    // MARK: - Tab Selector
    private var tabSelector: some View {
        HStack(spacing: 0) {
            ForEach(0..<3) { index in
                Button {
                    withAnimation(.spring()) {
                        vm.selectedTab = index
                    }
                } label: {
                    Text(tabTitle(for: index))
                        .fontWeight(vm.selectedTab == index ? .bold : .regular)
                        .foregroundStyle(vm.selectedTab == index ? Color.theme.accent : Color.theme.secondary)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(6)
        .background(Color.theme.secondary.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }
    
    private func tabTitle(for index: Int) -> String {
        switch index {
        case 0: return "Details"
        case 1: return "About"
        case 2: return "News"
        default: return ""
        }
    }

    // MARK: - Floating Buy/Sell Buttons
    private var floatingBuySellView: some View {
        VStack {
            Spacer()
            HStack(spacing: 16) {
                Button {
                    vm.showBuySheet = true
                } label: {
                    Text("Buy")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green)
                        .cornerRadius(12)
                }
                
                Button {
                    vm.showSellSheet = true
                } label: {
                    Text("Sell")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red)
                        .cornerRadius(12)
                }
            }
            .padding()
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .padding(.horizontal)
            .shadow(radius: 5)
        }
    }
    
    // MARK: - Tab Detail View
    private var tabDetailView: some View {
        Group {
            if vm.selectedTab == 0 {
                VStack(spacing: 20) {
                    if let stock = vm.stock {
                        if let portfolioStock = vm.DBStock {
                            // ✅ Show portfolio row if user holds this stock
                            PortfolioRowView(
                                vm: StockRowViewModel(
                                    stock: stock,
                                    portfolioStock: portfolioStock
                                ), authvm: authViewModel
                            )
                        } else {
                            // ✅ Fallback to plain stock row
                            StockRowView(stock: stock, authvm: authViewModel)
                        }
                    }
                    
                    // Company Overview
                    if !vm.overviewTuples.isEmpty {
                        sectionHeader(title: "Company Overview")
                        LazyVGrid(columns: columns, spacing: 16) {
                            ForEach(vm.overviewTuples.prefix(vm.showMoreOverview ? vm.overviewTuples.count : 4), id: \.0) { item in
                                InfoCell(title: item.0, value: item.1)
                            }
                        }
                        .padding(.horizontal)
                        
                        Button(vm.showMoreOverview ? "Show less" : "Read more") {
                            withAnimation { vm.showMoreOverview.toggle() }
                        }
                        .font(.subheadline)
                        .foregroundColor(.blue)
                    }
                    
                    // Additional Metrics
                    if !vm.additionalTuples.isEmpty {
                        sectionHeader(title: "Additional Metrics")
                        LazyVGrid(columns: columns, spacing: 16) {
                            ForEach(vm.additionalTuples.prefix(vm.showMoreDetails ? vm.additionalTuples.count : 4), id: \.0) { item in
                                InfoCell(title: item.0, value: item.1)
                            }
                        }
                        .padding(.horizontal)
                        
                        Button(vm.showMoreDetails ? "Show less" : "Read more") {
                            withAnimation { vm.showMoreDetails.toggle() }
                        }
                        .font(.subheadline)
                        .foregroundColor(.blue)
                    }
                }
                .padding(.top)
            } else if vm.selectedTab == 1 {
                // About tab
                StockSummaryView(Dvm: vm)
                    .padding(.top)
                
            } else if vm.selectedTab == 2 {
                // News tab
                if let stock = vm.stock {
                    StockNewsView(symbol: stock.SYMBOL)
                        .padding(.top)
                } else {
                    Text("No stock selected")
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    
    // MARK: - Helper Views
    private func sectionHeader(title: String) -> some View {
        VStack(alignment: .leading) {
            Text(title)
                .font(.headline)
                .foregroundColor(Color.theme.accent)
                .frame(maxWidth: .infinity, alignment: .leading)
            Divider()
        }
        .padding(.horizontal)
    }
}


// MARK: - Array Safe Access
extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}


