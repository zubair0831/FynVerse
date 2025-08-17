import SwiftUI

struct PortfolioView: View {
    @EnvironmentObject var vm: HomeViewModel
    @ObservedObject var authvm:AuthViewModel
    @State private var hasLoadedPortfolio = false
    var body: some View {
       
            ZStack {
                Color.theme.background
                    .ignoresSafeArea()
                VStack {
                    // CRITICAL FIX: Removed StatisticsView from PortfolioView
                    // if let stock = vm.returnStockModel(symbol: "NIFTY 50") {
                    //     StatisticsView(nifty50: stock)
                    // }
                    ScrollView {
                        VStack(spacing: 24) {
                            // MARK: - Portfolio Summary Card
                            if !vm.portfolioStocks.isEmpty {
                                PortfolioSummaryView()
                            } else {
                                Text("You have no stocks in your portfolio.")
                                    .foregroundColor(.secondary)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color(.systemGray6))
                                    .cornerRadius(12)
                                    .padding(.horizontal)
                            }
                            
                            // MARK: - Your Holdings Section
                            if !vm.portfolioStocks.isEmpty {
                                LazyVStack(alignment: .leading, spacing: 16) {
                                    Text("Your Holdings")
                                        .font(.title3.bold())
                                        .padding(.horizontal)
                                        .foregroundStyle(Color.theme.accent)
                                    
                                    ForEach(vm.portfolioStocks, id: \.id) { dbStock in
                                        if let stockModel = vm.returnStockModel(symbol: dbStock.stockSymbol) {
                                            NavigationLink(destination: DetailView(stock: stockModel, DBStock: dbStock, authViewModel: authvm)) {
                                                StockRowView(stock: stockModel, portfolioStock: dbStock)
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 16)
                    }
                    .navigationTitle("Portfolio")
                }
            .refreshable {
                await vm.fetchPortfolioStocks()
            }
            // CRITICAL FIX: Call the portfolio-specific initialization function
            .task {
                if !hasLoadedPortfolio {
                    await vm.fetchPortfolioStocks()
                    hasLoadedPortfolio = true
                }
            }
        }
    }
}
