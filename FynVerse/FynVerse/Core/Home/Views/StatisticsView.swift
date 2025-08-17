import SwiftUI
import FirebaseFirestore

struct StatisticsView: View {
    let nifty50: StockModel?
    @State private var statistics: [StatisticsModel] = []
    @ObservedObject var authvm:AuthViewModel
    
    // A separate function to fetch statistics data from Firestore
    private func fetchStats() async {
        let db = Firestore.firestore()
        do {
            let snapshot = try await db.collection("stocksStatsCache").getDocuments()
            let fetchedStocks = snapshot.documents.compactMap { doc -> StatisticsModel? in
                try? doc.data(as: StatisticsModel.self)
            }
            if !fetchedStocks.isEmpty {
                self.statistics = fetchedStocks
            } else {
                print("Failed to load or upload to Firestore")
            }
        } catch {
            print("Failed to load or upload to Firestore: \(error)")
        }
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
                // MARK: - Horizontal Scrollable Stats
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        if let stock = nifty50 {
                            NavigationLink(destination: DetailView(stock: nifty50, DBStock: nil, authViewModel: authvm)) {
                                StatCardView(stat: StatisticsModel(
                                    title: stock.SYMBOL,
                                    value: stock.Last_Price.asFormattedString(),
                                    percentChange: stock.Percent_Change
                                ))
                            }
                        }
                        
                        ForEach(statistics) { stat in
                            StatCardView(stat: stat)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                    .padding(.bottom, 4)
                }
            }
        }
        .task {
            // Fetch stats when the view appears
            await fetchStats()
        }
    }
}

// MARK: - StatCardView with Standout UI
struct StatCardView: View {
    let stat: StatisticsModel
    
    // Custom gradient for a premium, standout look
    private let cardGradient = LinearGradient(
        colors: [Color(red: 0.1, green: 0.4, blue: 0.6), Color(red: 0.2, green: 0.6, blue: 0.8)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    // Custom lighter colors for the percentage change to improve readability on the dark background
    private let lightGreen = Color(red: 0.2, green: 0.9, blue: 0.4) // A vibrant, light green
    private let lightRed = Color(red: 0.9, green: 0.3, blue: 0.3)   // A vibrant, light red
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(stat.title)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.8)) // Use a light color for readability
            
            Text("₹" + stat.value)
                .font(.headline)
                .bold()
                .foregroundStyle(.white) // Ensure the main value stands out
            
            HStack(spacing: 4) {
                Image(systemName: "triangle.fill")
                    .font(.caption2)
                    .rotationEffect(.degrees(stat.percentChange >= 0 ? 0 : 180))
                Text(stat.percentChange.asPercentString())
                    .font(.caption)
                    .bold()
            }
            // Use the new custom light colors for the percentage change
            .foregroundStyle(stat.percentChange >= 0 ? lightGreen : lightRed)
        }
        
        .padding()
        .frame(width: 140, height: 80, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(cardGradient) // Apply the new gradient here
                .shadow(color: .black.opacity(0.15), radius: 6, x: 0, y: 4) // More pronounced shadow
        )
    }
}

// MARK: - Extension for Double formatting
extension Double {
    func asFormattedString() -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: self)) ?? "\(self)"
    }
}

