//
//  BuySellSheetViewModel.swift
//  FynVerse
//
//  Created by zubair ahmed on 16/08/25.
//

import Foundation
import SwiftUI

@MainActor
class BuySellSheetViewModel: ObservableObject {
    @Published var quantityText: String = "1"
    @Published var isLoading: Bool = false
    @Published var showSuccessAlert: Bool = false
    @Published var showErrorAlert: Bool = false
    @Published var errorMessage: String = ""
    
    let stock: StockModel
    let isBuying: Bool
    private let authViewModel: AuthViewModel

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
        isLoading ? "Processing..." : (isBuying ? "Confirm Buy" : "Confirm Sell")
    }

    // MARK: - Action
    func performTransaction() async {
        guard !isLoading else { return }
        guard quantity > 0 else {
            errorMessage = "Please enter a valid quantity."
            showErrorAlert = true
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
}
