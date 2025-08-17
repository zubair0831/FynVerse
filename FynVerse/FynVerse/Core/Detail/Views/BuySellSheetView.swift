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
                        (vm.isBuying ? Color.green : Color.red)
                            .opacity(vm.quantity > 0 && !vm.isLoading ? 1 : 0.5)
                    )
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .disabled(vm.quantity <= 0 || vm.isLoading)
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
    }
}
