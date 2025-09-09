//
//  StockImageView.swift
//  FynVerse
//
//  Created by zubair ahmed on 18/07/25.
//

import SwiftUI
import Foundation
struct StockImageView: View {
    let stock:StockModel
    @StateObject  var viewModel:StockImageViewModel
    init(stock: StockModel) {
            self.stock = stock
            _viewModel = StateObject(wrappedValue: StockImageViewModel(stock: stock))
        }
    var body: some View {
        ZStack{
            if let image = viewModel.image{
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            }
            else if viewModel.isLoading{
                ProgressView()
            }
            else{
                Image(systemName: "chart.line.uptrend.xyaxis") // Substitute
                    .resizable()
                    .scaledToFit()
                    .foregroundColor(.gray)
                    .padding()
            }
        } .onAppear {
            Task {
                await viewModel.getStockImage()
            }
        }
    }
}


