//
//  Double.swift
//  FynVerse
//
//  Created by zubair ahmed on 17/07/25.
//
import Foundation
extension Double{
    
    private var currencyFormatter6 : NumberFormatter{
        let formatter = NumberFormatter()
        formatter.usesGroupingSeparator = true
        formatter.numberStyle = .currency
        formatter.currencyCode = "inr"
        formatter.currencySymbol = "₹"
        formatter.locale = .current
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 6
        return formatter
    }
    private var currencyFormatter: NumberFormatter {
            let formatter = NumberFormatter()
            formatter.usesGroupingSeparator = true
            formatter.numberStyle = .currency
            formatter.locale = Locale(identifier: "en_IN") // For Indian Rupee
            formatter.currencySymbol = "₹"
            formatter.minimumFractionDigits = 2
            formatter.maximumFractionDigits = 2
            return formatter
        }

        func asCurrencyWith2Decimals() -> String {
            let number = NSNumber(value: self)
            return currencyFormatter.string(from: number) ?? "₹0.00"
        }
    
    func asCurrencywith6Decimals() ->String{
        let number = NSNumber(value: self)
        return currencyFormatter6.string(from: number) ?? "0.00"
    }
    
    func asNumberString() ->String{
        return String(format: "%.2f", self)
    }
    
    func asPercentString() ->String{
        return asNumberString() + "%"
    }
}
