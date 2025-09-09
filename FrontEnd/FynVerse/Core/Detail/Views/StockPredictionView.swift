import SwiftUI

struct StockPredictionView: View {
    let stockSymbol: String
    @StateObject private var vm = StockPredictionViewModel()
    
    @State private var animatedNext5D: Double = 0
    @State private var animatedShort: Double = 0
    @State private var animatedLong: Double = 0
    @State private var animatedFundamental: Double = 0
    @State private var animatedTechnical: Double = 0
    
    var body: some View {
        Group {
            if vm.isLoading {
                loadingView
            } else if let prediction = vm.next5DPrediction {
                VStack(spacing: 20) {
                    
                    Text("\(stockSymbol) Predictions")
                        .font(.title3.bold())
                        .foregroundStyle(LinearGradient(colors: [.green, .blue], startPoint: .leading, endPoint: .trailing))
                    
                    // Main bars
                    PredictionBar(title: "Next 5D", percentage: animatedNext5D, color: .green)
                    
                    
                    Text(prediction.signal.uppercased())
                        .font(.subheadline.bold())
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(LinearGradient(colors: [.blue.opacity(0.8), .purple.opacity(0.8)],
                                                     startPoint: .leading,
                                                     endPoint: .trailing))
                                .shadow(color: .purple.opacity(0.5), radius: 5)
                        )
                        .foregroundColor(.white)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(.ultraThinMaterial)
                        .shadow(color: .black.opacity(0.2), radius: 10)
                )
                .padding(.horizontal)
                .onAppear {
                    withAnimation(.easeOut(duration: 1.2)) {
                        animatedNext5D = prediction.probability * 100
                        
                    }
                }
            } else {
                Text("Failed to load prediction.")
                    .foregroundColor(.red)
            }
        }
        .task {
            await vm.fetchPredictions(for: stockSymbol)
        }
    }
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView("Predicting...")
                .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                .scaleEffect(1.2)
        }
        .padding()
    }
}

