//
//  PortfolioRowView.swift
//  FynVerse
//
//  Created by zubair ahmed on 04/09/25.
//

import SwiftUI
@MainActor
class StockRowViewModel: ObservableObject {
    let stock: StockModel
    let portfolioStock: DBPortfolioStock?

    init(stock: StockModel, portfolioStock: DBPortfolioStock?) {
        self.stock = stock
        self.portfolioStock = portfolioStock
    }

    // MARK: - Computed Properties
    var currentHoldingValue: Double {
        guard let portfolio = portfolioStock else { return 0 }
        return stock.Last_Price * Double(portfolio.quantity)
    }
    
    var totalInvestment: Double {
        guard let portfolio = portfolioStock else { return 0 }
        return portfolio.avgBuyPrice * Double(portfolio.quantity)
    }

    var gainLoss: Double {
        return currentHoldingValue - totalInvestment
    }

    var gainLossPercentage: Double {
        guard totalInvestment != 0 else { return 0 }
        return (gainLoss / totalInvestment) * 100
    }
}


struct PortfolioRowView: View {
    @StateObject var vm: StockRowViewModel
    @EnvironmentObject var Hvm: HomeViewModel
    @ObservedObject var authvm: AuthViewModel
    
    var body: some View {
        NavigationLink {
            DetailView(
                stock: vm.stock,
                DBStock: vm.portfolioStock,
                authViewModel:authvm // or pass via EnvironmentObject if that’s how you manage it
            )
        } label: {

            VStack(spacing: 0) {
                HStack(spacing: 16) {
                    // MARK: - Stock Icon
                    StockImageView(stock: vm.stock)
                        .frame(width: 40, height: 40)
                        .clipShape(Circle())
                        .padding(.vertical, 8)
                    
                    // MARK: - Stock Info
                    VStack(alignment: .leading, spacing: 4) {
                        Text(vm.stock.SYMBOL)
                            .font(.headline)
                            .foregroundStyle(Color.theme.accent)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        
                        Text(vm.stock.NAME_OF_COMPANY)
                            .font(.footnote)
                            .foregroundStyle(Color.theme.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    
                    Spacer()
                    
                    // MARK: - Market Price + % Change
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(vm.stock.Last_Price.asCurrencyWith2Decimals())
                            .font(.headline)
                            .bold()
                            .foregroundStyle(Color.theme.accent)
                        
                        Text(vm.stock.Percent_Change.asPercentString())
                            .font(.subheadline)
                            .bold()
                            .foregroundStyle(vm.stock.Percent_Change >= 0 ? Color.theme.green : Color.theme.red)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                
                // MARK: - Portfolio Section
                Divider()
                    .padding(.horizontal)
                
                Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
                    GridRow {
                        Text("Holdings:")
                            .font(.caption)
                            .foregroundStyle(Color.theme.secondary)
                        
                        if let quantity = vm.portfolioStock?.quantity {
                            Text("\(quantity)")
                                .font(.subheadline).bold()
                                .foregroundStyle(Color.theme.accent)
                        }

                        
                        Text("Gain/Loss:")
                            .font(.caption)
                            .foregroundStyle(Color.theme.secondary)
                        
                        Text("\(vm.gainLoss.asCurrencyWith2Decimals()) (\(vm.gainLossPercentage.asPercentString()))")
                            .font(.subheadline).bold()
                            .foregroundStyle(vm.gainLoss >= 0 ? Color.theme.green : Color.theme.red)
                    }
                    
                    GridRow {
                        Text("Avg. Price:")
                            .font(.caption)
                            .foregroundStyle(Color.theme.secondary)
                        
                        Text(vm.portfolioStock?.avgBuyPrice.asCurrencyWith2Decimals() ?? "0")
                            .font(.subheadline).bold()
                            .foregroundStyle(Color.theme.accent)
                        
                        Text("Total:")
                            .font(.caption)
                            .foregroundStyle(Color.theme.secondary)
                        
                        Text(vm.currentHoldingValue.asCurrencyWith2Decimals())
                            .font(.subheadline).bold()
                            .foregroundStyle(Color.theme.accent)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom)
                
            }
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.theme.cardBackground)
                    .shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)
            )
            .cornerRadius(12)
            .shadow(color: Color.theme.accent.opacity(0.1), radius: 5, x: 0, y: 5)
            .padding(.horizontal)
        }
    
}
}
