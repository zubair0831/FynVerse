import SwiftUI

// MARK: - Transaction Row
struct TransactionRow: View {
    let txn: DBTransaction
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with symbol and transaction type
            HStack {
                HStack(spacing: 8) {
                    // Stock symbol with background
                    Text(txn.stockSymbol)
                        .font(.system(.headline, design: .rounded, weight: .semibold))
                        .foregroundStyle(Color.theme.accent)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.theme.accent.opacity(0.1))
                        )
                    
                    Spacer()
                    
                    // Transaction type badge
                    Text(txn.transactionType.uppercased())
                        .font(.system(.caption, design: .rounded, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(
                                    txn.transactionType.lowercased() == "buy"
                                    ? Color.theme.green
                                    : Color.theme.red
                                )
                        )
                }
            }
            
            // Price and quantity info
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Price per Share")
                        .font(.caption2)
                        .foregroundColor(Color.theme.secondary)
                        .textCase(.uppercase)
                        .tracking(0.5)
                    
                    Text("₹\(txn.pricePerShare, specifier: "%.2f")")
                        .font(.system(.body, design: .rounded, weight: .semibold))
                        .foregroundStyle(Color.theme.accent)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Quantity")
                        .font(.caption2)
                        .foregroundColor(Color.theme.secondary)
                        .textCase(.uppercase)
                        .tracking(0.5)
                    
                    Text("\(txn.quantity)")
                        .font(.system(.body, design: .rounded, weight: .semibold))
                        .foregroundStyle(Color.theme.accent)
                }
            }
            
            // Total amount
            HStack {
                Text("Total Amount")
                    .font(.caption)
                    .foregroundColor(Color.theme.secondary)
                
                Spacer()
                
                Text("₹\(txn.pricePerShare * Double(txn.quantity), specifier: "%.2f")")
                    .font(.system(.callout, design: .rounded, weight: .medium))
                    .foregroundStyle(Color.theme.accent)
            }
            
            Divider()
                .background(Color.theme.secondary.opacity(0.3))
            
            // Timestamp
            HStack {
                Image(systemName: "clock")
                    .font(.caption)
                    .foregroundColor(Color.theme.secondary)
                
                Text(txn.timestamp.dateValue().formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundColor(Color.theme.secondary)
                
                Spacer()
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.theme.cardBackground)
                .shadow(
                    color: Color.black.opacity(0.08),
                    radius: 8,
                    x: 0,
                    y: 4
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.theme.accent.opacity(0.1),
                            Color.clear
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
    }
}

// MARK: - Enhanced Search Bar
struct EnhancedSearchBar: View {
    @Binding var searchText: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(Color.theme.secondary)
                .font(.system(size: 16, weight: .medium))
            
            TextField("Search transactions...", text: $searchText)
                .font(.system(.body, design: .rounded))
                .foregroundColor(Color.theme.accent)
                .textFieldStyle(PlainTextFieldStyle())
            
            if !searchText.isEmpty {
                Button(action: { searchText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(Color.theme.secondary)
                        .font(.system(size: 16))
                }
                .transition(.opacity)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.theme.cardBackground)
                .shadow(
                    color: Color.black.opacity(0.05),
                    radius: 4,
                    x: 0,
                    y: 2
                )
        )
    }
}

// MARK: - Empty State View
struct EmptyStateViewTransaction: View {
    let searchText: String
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: searchText.isEmpty ? "tray" : "magnifyingglass")
                .font(.system(size: 48, weight: .light))
                .foregroundColor(Color.theme.secondary.opacity(0.6))
            
            Text(searchText.isEmpty ? "No Transactions Yet" : "No Results Found")
                .font(.system(.title3, design: .rounded, weight: .semibold))
                .foregroundColor(Color.theme.accent)
            
            Text(searchText.isEmpty ?
                 "Your transaction history will appear here" :
                 "Try adjusting your search terms")
                .font(.system(.body, design: .rounded))
                .foregroundColor(Color.theme.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(32)
    }
}

// MARK: - Main View
struct TransactionView: View {
    @StateObject private var vm = TransactionViewModel()
    @State private var searchText = ""
    
    var filteredTransactions: [DBTransaction] {
        guard !searchText.isEmpty else { return vm.transactions }
        let lower = searchText.lowercased()
        return vm.transactions.filter {
            $0.stockSymbol.lowercased().contains(lower)
        }
    }
    
    var body: some View {
        ZStack {
            // Background gradient
            
                    Color.theme.background
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header section
                VStack(spacing: 16) {
                    // Search bar
                    EnhancedSearchBar(searchText: $searchText)
                        .padding(.horizontal, 20)
                    
                    // Transaction count
                    if !filteredTransactions.isEmpty {
                        HStack {
                            Text("\(filteredTransactions.count) Transaction\(filteredTransactions.count == 1 ? "" : "s")")
                                .font(.system(.caption, design: .rounded, weight: .medium))
                                .foregroundColor(Color.theme.secondary)
                            
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                    }
                }
                .padding(.top, 8)
                .padding(.bottom, 8)
                
                // Content
                if filteredTransactions.isEmpty {
                    Spacer()
                    EmptyStateViewTransaction(searchText: searchText)
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(filteredTransactions) { txn in
                                TransactionRow(txn: txn)
                                    .transition(.asymmetric(
                                        insertion: .opacity.combined(with: .move(edge: .top)),
                                        removal: .opacity.combined(with: .scale(scale: 0.8))
                                    ))
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                        .padding(.bottom, 32)
                    }
                }
            }
        }
        .navigationTitle("Transactions")
        .navigationBarTitleDisplayMode(.large)
        .task {
            await vm.fetchTransactions()
        }
        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: filteredTransactions)
        .animation(.easeInOut(duration: 0.3), value: searchText)
    }
}
