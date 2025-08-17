import SwiftUI

struct StockSummaryView: View {
    @StateObject private var vm: StockSummaryViewModel
    @State private var isSummaryExpanded: Bool = false

    init(stockName: String) {
        _vm = StateObject(wrappedValue: StockSummaryViewModel(stockName: stockName))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("GEMINI Flash Summary")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(Color.theme.accent)

            if vm.summary.isEmpty {
                ProgressView("Loading Summary...")
                    .progressViewStyle(CircularProgressViewStyle(tint: Color.theme.accent))
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Overview")
                        .font(.headline)

                    Text(vm.summary.first ?? "No summary available.")
                        .foregroundStyle(Color.theme.secondary)
                        .font(.body)
                        .lineLimit(isSummaryExpanded ? nil : 4)

                    Button(action: {
                        withAnimation(.easeInOut) {
                            isSummaryExpanded.toggle()
                        }
                    }) {
                        Text(isSummaryExpanded ? "Read Less" : "Read More")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundStyle(Color.blue)
                    }

                    if vm.summary.count >= 3 {
                        Divider()
                        Text("Pros: \(vm.summary[1])")
                            .foregroundStyle(Color.theme.green)
                            .font(.subheadline)
                        Text("Cons: \(vm.summary[2])")
                            .foregroundStyle(Color.theme.red)
                            .font(.subheadline)
                    }
                }
            }
        }
        .padding()
        .background(Color.theme.background.opacity(0.1))
        .cornerRadius(12)
    }
}
