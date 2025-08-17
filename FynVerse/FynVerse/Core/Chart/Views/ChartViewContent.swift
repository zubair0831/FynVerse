import SwiftUI
import Charts

struct ChartViewContent: View {
    let data: [HistoricPriceModel]
    let isStockUp: Bool
    let yPriceRange: ClosedRange<Double>
    let selectedRange: ChartRange
    
    @Binding var selectedItem: HistoricPriceModel?
    
    // Calculate percent change & PnL
    private var percentChange: Double {
        guard let first = data.first?.close, let last = data.last?.close else { return 0 }
        return ((last - first) / first) * 100
    }
    
    private var pnl: Double {
        guard let first = data.first?.close, let last = data.last?.close else { return 0 }
        return last - first
    }
    
    func formatPrice(_ price: Double) -> String {
        String(format: "₹%.2f", price)
    }
    
    func formatPercent(_ value: Double) -> String {
        String(format: "%.2f%%", value)
    }
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            Chart {
                // Area Fill
                ForEach(data, id: \.date) { item in
                    AreaMark(
                        x: .value("Date", item.date),
                        yStart: .value("Price", yPriceRange.lowerBound),
                        yEnd: .value("Price", item.close)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                (isStockUp ? Color.green : Color.red).opacity(0.25),
                                .clear
                            ]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                }
                
                // Price Line
                ForEach(data, id: \.date) { item in
                    LineMark(
                        x: .value("Date", item.date),
                        y: .value("Price", item.close)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(isStockUp ? .green : .red)
                    .lineStyle(.init(lineWidth: 2))
                }
                
                // Selection Marks
                if let selectedItem {
                    RuleMark(x: .value("Selected Date", selectedItem.date))
                        .foregroundStyle(Color.primary.opacity(0.25))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [5]))
                    
                    PointMark(
                        x: .value("Date", selectedItem.date),
                        y: .value("Price", selectedItem.close)
                    )
                    .foregroundStyle(Color.theme.accent)
                    .symbolSize(120)
                    .shadow(radius: 3)
                }
            }
            .chartYScale(domain: yPriceRange)
            .chartXScale(domain: xScaleDomain)
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisValueLabel {
                        if let doubleValue = value.as(Double.self) {
                            Text(formatPrice(doubleValue))
                                .font(.caption)
                                .foregroundStyle(Color.theme.accent)
                        }
                    }
                }
            }
            .chartXAxis {
                AxisMarks { value in
                    AxisValueLabel {
                        if let dateValue = value.as(Date.self) {
                            Text(dateValue, format: selectedRange == .oneDay ?
                                 .dateTime.hour().minute() :
                                 .dateTime.month().day())
                                .font(.caption)
                                .foregroundStyle(Color.theme.accent)
                        }
                    }
                }
            }
            .chartOverlay { proxy in
                GeometryReader { _ in
                    Rectangle().fill(.clear).contentShape(Rectangle())
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    if let date: Date = proxy.value(atX: value.location.x) {
                                        if let item = data.min(by: {
                                            abs($0.date.timeIntervalSince(date)) <
                                            abs($1.date.timeIntervalSince(date))
                                        }) {
                                            selectedItem = item
                                        }
                                    }
                                }
                                .onEnded { _ in
                                    selectedItem = nil
                                }
                        )
                }
            }
            
            // Percent change / PnL overlay
            VStack(alignment: .trailing, spacing: 2) {
                Text("PnL: \(formatPrice(pnl))")
                    .font(.caption)
                    .bold()
                    .foregroundStyle(isStockUp ? Color.green : Color.red)
                Text("% Change: \(formatPercent(percentChange))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(8)
            .background(Color.theme.cardBackground.opacity(0.8))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .padding([.top, .trailing], 6)
        }
    }
    
    private var xScaleDomain: ClosedRange<Date> {
        if selectedRange == .oneDay {
            let calendar = Calendar.current
            let now = Date()
            guard let marketOpen = calendar.date(bySettingHour: 9, minute: 15, second: 0, of: now) else {
                return now...now
            }
            return marketOpen...now
        }
        return (data.first?.date ?? Date())...(data.last?.date ?? Date())
    }
}
