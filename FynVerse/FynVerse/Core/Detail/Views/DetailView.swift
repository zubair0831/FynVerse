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
                    
                    // Predictions
                    if let stock = vm.stock {
                        Next5DPredictionView(
                            stockSymbol: stock.SYMBOL,
                            prediction: predictionVM.next5DPrediction,
                            longPred: predictionVM.longShortPrediction,
                            isLoading: predictionVM.isLoading,
                            animateSpinner: predictionVM.animateSpinner
                        )
                        .padding(.top)
                    }

                    // Tab Selector + Content
                    tabSelector
                    tabDetailView
                }
                .padding(.bottom, 100)
            }
            
            // Floating Buttons
            floatingBuySellView
        }
        .task {
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
    var tabSelector: some View {
        HStack(spacing: 0) {
            Button {
                vm.selectedTab = 0
            } label: {
                Text("Details")
                    .fontWeight(vm.selectedTab == 0 ? .bold : .regular)
                    .foregroundStyle(vm.selectedTab == 0 ? .white : .primary)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)

            Button {
                vm.selectedTab = 1
            } label: {
                Text("About")
                    .fontWeight(vm.selectedTab == 1 ? .bold : .regular)
                    .foregroundStyle(vm.selectedTab == 1 ? .white : .primary)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
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
                        StockRowView(stock: stock, portfolioStock: vm.DBStock)
                    }
                    
                    // Overview
                    SectionHeader(title: "Overview")
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(vm.overviewInfo().prefix(vm.showMoreOverview ? .max : 4), id: \.0) { item in
                            InfoCell(title: item.0, value: item.1)
                        }
                    }
                    .padding(.horizontal)
                    
                    Button(vm.showMoreOverview ? "Show less" : "Read more") {
                        withAnimation { vm.showMoreOverview.toggle() }
                    }
                    .font(.subheadline)
                    .foregroundColor(.blue)
                    
                    // Additional Details
                    SectionHeader(title: "Additional Details")
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(vm.additionalInfo().prefix(vm.showMoreDetails ? .max : 4), id: \.0) { item in
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
                .padding(.top)
            } else {
                StockSummaryView(stockName: summaryVM.stockName)
                    .padding(.top)
            }
        }
    }
}


// MARK: - Array Safe Access
extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
