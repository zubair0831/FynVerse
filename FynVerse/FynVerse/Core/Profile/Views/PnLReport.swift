import SwiftUI
import Foundation


// MARK: - PnL Report View
struct PnLReport: View {
    @StateObject var vm = TransactionViewModel()
    
    var body: some View {
        ZStack{
            Color.theme.background
                .ignoresSafeArea()
            VStack(spacing: 0) { // Changed spacing to 0 for a cleaner look
                
                // Summary Card at the top
                SummaryCard(
                    title: "Realized PnL",
                    subtitle: "\(vm.sellDetails.count) Stocks Sold",
                    valueText: String(format: "₹%.2f", vm.totalSellPnL),
                    valueIsPositive: vm.totalSellPnL >= 0,
                    systemImage: "chart.line.uptrend.xyaxis"
                )
                .padding(.horizontal)
                .padding(.top)
                
                // Separator line
                Divider()
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                
                // List of sell transactions
                if vm.sellDetails.isEmpty {
                    Spacer()
                    EmptyStateView(
                        title: "No sales yet.",
                        subtitle: "Your realized PnL will appear here.",
                        systemImage: "chart.bar.doc.horizontal"
                    )
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(vm.sellDetailsNewestFirst) { detail in
                                SellRow(detail: detail)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top)
                    }
                    .refreshable { await vm.fetchTransactions() }
                }
            }
            .background(Color.theme.background.ignoresSafeArea())
            .navigationTitle(" PnL Report")
            .foregroundStyle(Color.theme.accent)
            .task { await vm.fetchTransactions() }
        }
    }
}
// MARK: - Sell Row Component
private struct SellRow: View {
    let detail: SellDetail
    
    var body: some View {
        let txn = detail.txn
        
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(txn.stockSymbol)
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.theme.accent)
                Spacer()
                Text("PnL: \(detail.pnl >= 0 ? "+" : "-")₹\(abs(detail.pnl), specifier: "%.2f")")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(detail.pnl >= 0 ? Color.theme.green : Color.theme.red)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 20) {
                    Label("Sold: ₹\(txn.pricePerShare, specifier: "%.2f")", systemImage: "arrow.up.right")
                    Label("Qty: \(txn.quantity)", systemImage: "chart.bar")
                }
                .font(.caption)
                .foregroundColor(Color.theme.secondary)
                
                if detail.matchedQty > 0 {
                    HStack {
                        Label("Avg Cost: ₹\(detail.avgCost, specifier: "%.2f")", systemImage: "arrow.down.left")
                    }
                    .font(.caption)
                    .foregroundColor(Color.theme.secondary)
                }
                
                Text(txn.timestamp.dateValue().formatted(date: .abbreviated, time: .shortened))
                    .font(.caption2)
                    .foregroundStyle(Color.theme.secondary)
            }
            
            if detail.unmatchedQty > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text("Sold \(detail.unmatchedQty) shares without prior buys.")
                        .font(.caption2)
                        .foregroundColor(.orange)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .foregroundColor(Color.theme.cardBackground)
        )
    }
}

// MARK: - Summary Card Component
private struct SummaryCard: View {
    let title: String
    let subtitle: String
    let valueText: String
    let valueIsPositive: Bool
    let systemImage: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title).font(.headline)
                    .foregroundColor(Color.theme.accent)
                
                Spacer()
                Image(systemName: systemImage)
                    .foregroundColor(valueIsPositive ? Color.theme.green : Color.theme.red)
            }
            
            Text(valueText)
                .font(.largeTitle.bold())
                .foregroundColor(valueIsPositive ? Color.theme.green : Color.theme.red)
                .minimumScaleFactor(0.7)
            
            Text(subtitle)
                .font(.footnote)
                .foregroundColor(Color.theme.secondary)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .foregroundColor(Color.theme.cardBackground)
        )
    }
}

// MARK: - Empty State Component
private struct EmptyStateView: View {
    let title: String
    let subtitle: String
    let systemImage: String
    
    var body: some View {
        ZStack{
            Color.theme.background
                .ignoresSafeArea()
            VStack(spacing: 12) {
                Image(systemName: systemImage)
                    .font(.system(size: 50))
                    .foregroundColor(.secondary)
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .multilineTextAlignment(.center)
            .padding()
        }
    }
}

// Placeholder for `Color.theme`
