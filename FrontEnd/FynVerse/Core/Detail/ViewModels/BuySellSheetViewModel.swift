import Foundation
import SwiftUI

@MainActor
class BuySellSheetViewModel: ObservableObject {
    @Published var quantityText: String = "1"
    @Published var isLoading: Bool = false
    @Published var showSuccessAlert: Bool = false
    @Published var showErrorAlert: Bool = false
    @Published var showInsufficientFundsAlert: Bool = false
    @Published var errorMessage: String = ""
    
    let stock: StockModel
    let isBuying: Bool
    private let authViewModel: AuthViewModel
    private let fundsManager = FundsManager.shared

    init(stock: StockModel, isBuying: Bool, authViewModel: AuthViewModel) {
        self.stock = stock
        self.isBuying = isBuying
        self.authViewModel = authViewModel
    }

    // MARK: - Computed Properties
    var quantity: Int {
        Int(quantityText) ?? 0
    }
    
    var totalAmount: Double {
        Double(quantity) * stock.Last_Price
    }
    
    var buttonText: String {
        if isLoading {
            return "Processing..."
        } else if isBuying {
            return hasInsufficientFunds ? "Insufficient Funds" : "Confirm Buy"
        } else {
            return "Confirm Sell"
        }
    }
    
    var hasInsufficientFunds: Bool {
        isBuying && !fundsManager.canAfford(amount: totalAmount)
    }
    
    var availableFunds: Double {
        fundsManager.availableFunds
    }
    
    var shortfall: Double {
        max(0, totalAmount - availableFunds)
    }

    // MARK: - Action
    func performTransaction() async {
        guard !isLoading else { return }
        guard quantity > 0 else {
            errorMessage = "Please enter a valid quantity."
            showErrorAlert = true
            return
        }
        
        // Check funds before proceeding with buy order
        if isBuying && hasInsufficientFunds {
            showInsufficientFundsAlert = true
            return
        }
        
        guard let userID = authViewModel.user?.userID else {
            errorMessage = "User not authenticated."
            showErrorAlert = true
            return
        }

        isLoading = true
        do {
            if isBuying {
                try await UserManager.shared.performBuyTransaction(
                    userID: userID,
                    stockSymbol: stock.SYMBOL,
                    quantity: quantity,
                    pricePerShare: stock.Last_Price
                )
            } else {
                try await UserManager.shared.performSellTransaction(
                    userID: userID,
                    stockSymbol: stock.SYMBOL,
                    quantity: quantity,
                    pricePerShare: stock.Last_Price
                )
            }
            showSuccessAlert = true
        } catch {
            errorMessage = error.localizedDescription
            showErrorAlert = true
        }
        isLoading = false
    }
    
    // MARK: - Helper Methods
    func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        formatter.locale = Locale(identifier: "en_IN")
        
        return formatter.string(from: NSNumber(value: amount)) ?? "0"
    }
}
