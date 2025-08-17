
import SwiftUI
struct StockChartView: View {
    let symbol: String
    @StateObject private var vm = StockChartViewModel()
    @State private var scale: CGFloat = 1.0
    @State private var dragOffset: CGSize = .zero
    
    var body: some View {
        VStack(spacing: 12) {
            if vm.isLoading {
                ProgressView("Loading \(symbol)...")
                    .padding()
            } else if vm.historicData.isEmpty {
                Text("No chart data available.")
                    .foregroundStyle(.secondary)
                    .padding(.top)
            } else {
                ZoomableChartView(
                    data: vm.historicData,
                    isStockUp: vm.isStockUp,
                    selectedRange: vm.selectedRange,
                    scale: $scale,
                    dragOffset: $dragOffset
                )
                .frame(height: 220)
                .background(.clear) // inherits parent bg
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            
            Picker("Range", selection: $vm.selectedRange) {
                ForEach(ChartRange.allCases) { range in
                    Text(range.rawValue).tag(range)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
        }
        .task { await vm.fetchChart(for: symbol) }
        .background(.clear)
    }
}
