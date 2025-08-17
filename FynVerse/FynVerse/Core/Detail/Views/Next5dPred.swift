import SwiftUI

struct Next5DPredictionView: View {
    let stockSymbol: String
    let prediction: Next5Dpred?
    let longPred: lonShortPred?
    let isLoading: Bool
    let animateSpinner: Bool

    @State private var animatedNext5D: Double = 0
    @State private var animatedShort: Double = 0
    @State private var animatedLong: Double = 0
    @State private var animatedFundamental: Double = 0
    @State private var animatedTechnical: Double = 0

    var body: some View {
        Group {
            if isLoading {
                loadingView
            } else if let prediction = prediction {
                VStack(spacing: 20) {
                    
                    Text("\(stockSymbol) Predictions")
                        .font(.title3.bold())
                        .foregroundStyle(LinearGradient(colors: [.green, .blue], startPoint: .leading, endPoint: .trailing))
                    
                    // Main 3 Bars
                    PredictionBar(title: "Next 5D", percentage: animatedNext5D, color: .green)
                    
                    if let _ = longPred {
                        PredictionBar(title: "Short-Term", percentage: animatedShort, color: .orange)
                        PredictionBar(title: "Long-Term", percentage: animatedLong, color: .blue)
                        
                        Divider().padding(.vertical, 4)
                        
                        // Smaller supporting bars
                        PredictionBar(title: "Fundamental", percentage: animatedFundamental, color: .purple)
                            .scaleEffect(y: 0.8, anchor: .center)
                        PredictionBar(title: "Technical", percentage: animatedTechnical, color: .pink)
                            .scaleEffect(y: 0.8, anchor: .center)
                    }
                    
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
                    animatedNext5D = prediction.probability * 100
                    if let lp = longPred {
                        animatedShort = lp.shortTermScore01 * 100
                        animatedLong = lp.longTermScore01 * 100
                        animatedFundamental = lp.fundamentalScore01 * 100
                        animatedTechnical = lp.technicalScore01 * 100
                    }
                }
            } else {
                Text("Failed to load prediction.")
                    .foregroundColor(.red)
            }
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

struct PredictionBar: View {
    let title: String
    let percentage: Double
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(String(format: "%.1f", percentage))%")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.15))
                    RoundedRectangle(cornerRadius: 8)
                        .fill(color.gradient)
                        .frame(width: max(8, geo.size.width * CGFloat(percentage / 100)))
                        .animation(.easeOut(duration: 1.2), value: percentage)
                }
            }
            .frame(height: 14)
        }
    }
}
