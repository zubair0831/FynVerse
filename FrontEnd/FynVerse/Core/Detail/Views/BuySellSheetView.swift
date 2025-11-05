import SwiftUI

struct BuySellSheetView: View {
    @StateObject private var vm: BuySellSheetViewModel
    @FocusState private var isFocused: Bool
    @Environment(\.dismiss) private var dismiss

    init(stock: StockModel, isBuying: Bool, authViewModel: AuthViewModel) {
        _vm = StateObject(wrappedValue: BuySellSheetViewModel(stock: stock, isBuying: isBuying, authViewModel: authViewModel))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(vm.isBuying ? "Buy \(vm.stock.SYMBOL)" : "Sell \(vm.stock.SYMBOL)")
                .font(.title2).bold()

            HStack {
                Text("Current Price:")
                Spacer()
                Text("₹\(String(format: "%.2f", vm.stock.Last_Price))")
                    .foregroundColor(.gray)
            }

            HStack {
                Text("Quantity:")
                Spacer()
                TextField("Enter quantity", text: $vm.quantityText)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 80)
                    .padding(8)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                    .focused($isFocused)
            }

            Divider()

            HStack {
                Text("Total Amount:")
                Spacer()
                Text("₹\(String(format: "%.2f", vm.totalAmount))")
                    .font(.title3).bold()
                    .foregroundColor(vm.hasInsufficientFunds ? .red : .primary)
            }
            
            // Available Funds Display (for buy orders)
            if vm.isBuying {
                HStack {
                    Text("Available Funds:")
                    Spacer()
                    Text("₹\(vm.formatCurrency(vm.availableFunds))")
                        .font(.subheadline)
                        .foregroundColor(vm.hasInsufficientFunds ? .red : .green)
                }
                
                // Insufficient funds warning
                if vm.hasInsufficientFunds {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Insufficient Funds!")
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(.red)
                            Text("You need ₹\(vm.formatCurrency(vm.shortfall)) more to complete this transaction.")
                                .font(.caption)
                                .foregroundColor(.red.opacity(0.8))
                        }
                        Spacer()
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.red.opacity(0.1))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.red.opacity(0.3), lineWidth: 1)
                            )
                    )
                }
            }

            Spacer()

            Button(action: {
                Task { await vm.performTransaction() }
            }) {
                Text(vm.buttonText)
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        buttonBackgroundColor
                    )
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .disabled(shouldDisableButton)
            .contentShape(Rectangle())
        }
        .padding()
        .presentationDetents([.medium, .large])
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isFocused = true
            }
        }
        .alert("Success", isPresented: $vm.showSuccessAlert) {
            Button("OK") {
                dismiss()
            }
        } message: {
            Text(vm.isBuying ? "Stock bought successfully!" : "Stock sold successfully!")
        }
        .alert("Error", isPresented: $vm.showErrorAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(vm.errorMessage)
        }
        .alert("Insufficient Funds", isPresented: $vm.showInsufficientFundsAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("You don't have enough funds to complete this purchase. You need ₹\(vm.formatCurrency(vm.shortfall)) more.")
        }
    }
    
    // MARK: - Computed Properties
    private var buttonBackgroundColor: Color {
        if vm.isLoading {
            return Color.gray
        } else if vm.isBuying {
            return vm.hasInsufficientFunds ? Color.red.opacity(0.6) : Color.green
        } else {
            return Color.red
        }
    }
    
    private var shouldDisableButton: Bool {
        vm.quantity <= 0 || vm.isLoading || (vm.isBuying && vm.hasInsufficientFunds)
    }
}
