import SwiftUI
// MARK: - Transaction Row
struct TransactionRow: View {
    let txn: DBTransaction
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(txn.stockSymbol)
                    .font(.headline)
                    .foregroundStyle(Color.theme.accent)
                Spacer()
                Text(txn.transactionType.uppercased())
                    .font(.caption.bold())
                    .foregroundColor(
                        txn.transactionType.lowercased() == "buy"
                        ? Color.theme.green
                        : Color.theme.red
                    )
            }
            HStack {
                Text("Price: ₹\(txn.pricePerShare, specifier: "%.2f")")
                Spacer()
                Text("Qty: \(txn.quantity)")
            }
            .foregroundStyle(Color.theme.accent)
            .font(.callout)
            
            Text(txn.timestamp.dateValue().formatted(date: .abbreviated, time: .shortened))
                .font(.caption)
                .foregroundColor(Color.theme.secondary)
        }
        .padding()
        .background(Color.theme.cardBackground)
        .cornerRadius(10)
        .shadow(color: Color.black.opacity(0.05), radius: 3, x: 0, y: 2)
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
            Color.theme.background
                .ignoresSafeArea()
            
            VStack {
                SearchBarView(searchText: $searchText)
                    .padding(.horizontal)
                    .padding(.top)
                
                if filteredTransactions.isEmpty {
                    Spacer()
                    Text("No transactions found")
                        .foregroundColor(.secondary)
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(filteredTransactions) { txn in
                                TransactionRow(txn: txn)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom)
                    }
                }
            }
            .navigationTitle(
               Text( "Transactions")
            )
           
            .task {
                await vm.fetchTransactions()
            }
        }
    }
}
