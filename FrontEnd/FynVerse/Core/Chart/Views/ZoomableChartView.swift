import SwiftUI

// MARK: - Zoomable Chart View
struct ZoomableChartView: View {
    let data: [HistoricPriceModel]
    let isStockUp: Bool
    let selectedRange: ChartRange
    
    @Binding var scale: CGFloat
    @Binding var dragOffset: CGSize
    @State private var selectedItem: HistoricPriceModel?
    
    private var priceRange: ClosedRange<Double> {
        let prices = data.map { $0.close }
        guard let min = prices.min(), let max = prices.max() else { return 0...1 }
        let pad = (max - min) * 0.15
        return (min - pad)...(max + pad)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            ChartViewContent(
                data: data,
                isStockUp: isStockUp,
                yPriceRange: priceRange,
                selectedRange: selectedRange,
                selectedItem: $selectedItem
            )
            .scaleEffect(scale)
            .offset(dragOffset)
            .animation(.easeInOut(duration: 0.2), value: selectedItem)
            
            if let selectedItem {
                VStack(alignment: .leading, spacing: 4) {
                    Text(selectedItem.date, format: .dateTime.month().day().year())
                        .font(.caption2).foregroundStyle(.secondary)
                    Text("₹\(String(format: "%.2f", selectedItem.close))")
                        .font(.headline)
                        .foregroundStyle(isStockUp ? .green : .red)
                }
                .padding(8)
                .background(Color.theme.cardBackground.opacity(0.9))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .shadow(radius: 2)
                .padding(.top, 6)
            }

        }
        .gesture(
            MagnificationGesture()
                .onChanged { value in scale = max(1, min(value, 3)) }
        )
    }
}
