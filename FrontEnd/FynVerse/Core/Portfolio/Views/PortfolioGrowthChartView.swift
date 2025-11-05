import SwiftUI
import Charts

// MARK: - Portfolio Growth Chart View (Completely Redesigned)
struct PortfolioGrowthChartView: View {
    @ObservedObject var analyticsVM: PortfolioAnalyticsViewModel
    @State private var selectedDataPoint: ChartDataPoint?
    @State private var showInvestmentLine = true
    @State private var showCurrentValueLine = true
    @State private var chartSelection: Date?
    
    var body: some View {
        VStack(spacing: 24) {
            headerSection
            
            if let selectedPoint = selectedDataPoint ?? analyticsVM.chartDataPoints.last {
                performanceSummary(for: selectedPoint)
            }
            
            chartSection
            
            legendSection
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.theme.cardBackground)
                .shadow(color: Color.theme.cardShadow, radius: 12, x: 0, y: 4)
        )
    }
    
    @ViewBuilder
    private var headerSection: some View {
        VStack(spacing: 18) {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Portfolio Growth")
                        .font(.title2.bold())
                        .foregroundColor(Color.theme.primaryText)
                    
                    if let selectedPoint = selectedDataPoint {
                        Text(selectedPoint.date, style: .date)
                            .font(.subheadline)
                            .foregroundColor(Color.theme.secondary)
                    } else {
                        Text("Track your investment journey")
                            .font(.subheadline)
                            .foregroundColor(Color.theme.secondary)
                    }
                }
                
                Spacer()
            }
            
            // Time Range Selector with improved styling
            Picker("Time Range", selection: Binding(
                get: { analyticsVM.selectedTimeRange },
                set: { newValue in
                    Task {
                        await analyticsVM.changeTimeRange(newValue)
                        selectedDataPoint = nil
                        chartSelection = nil
                    }
                }
            )) {
                ForEach(PortfolioAnalyticsViewModel.TimeRange.allCases, id: \.self) { range in
                    Text(range.rawValue).tag(range)
                }
            }
            .pickerStyle(.segmented)
            .background(Color.theme.cardBackground)
        }
    }
    
    @ViewBuilder
    private var chartSection: some View {
        Group {
            if analyticsVM.isLoadingHistory {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.3)
                        .tint(Color.theme.accent)
                    Text("Loading chart data...")
                        .font(.subheadline)
                        .foregroundColor(Color.theme.secondary)
                }
                .frame(height: 340)
                .frame(maxWidth: .infinity)
            } else if analyticsVM.chartDataPoints.isEmpty {
                emptyChartView
            } else {
                chartView
            }
        }
    }
    
    @ViewBuilder
    private var emptyChartView: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(Color.theme.accent.opacity(0.1))
                    .frame(width: 100, height: 100)
                
                Image(systemName: "chart.xyaxis.line")
                    .font(.system(size: 42, weight: .light))
                    .foregroundColor(Color.theme.accent)
            }
            
            VStack(spacing: 8) {
                Text("No Data Available")
                    .font(.title3.bold())
                    .foregroundColor(Color.theme.primaryText)
                
                Text("Start investing to track your\nportfolio growth over time")
                    .font(.subheadline)
                    .foregroundColor(Color.theme.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
        }
        .frame(height: 340)
        .frame(maxWidth: .infinity)
    }
    
    private var minY: Double {
        guard !analyticsVM.chartDataPoints.isEmpty else { return 0 }
        let minInvest = analyticsVM.chartDataPoints.map { $0.investmentValue }.min() ?? 0
        let minCurrent = analyticsVM.chartDataPoints.map { $0.currentValue }.min() ?? 0
        let overallMin = min(minInvest, minCurrent)
        return overallMin > 0 ? overallMin * 0.95 : 0
    }
    
    private var maxY: Double {
        guard !analyticsVM.chartDataPoints.isEmpty else { return 100 }
        let maxInvest = analyticsVM.chartDataPoints.map { $0.investmentValue }.max() ?? 0
        let maxCurrent = analyticsVM.chartDataPoints.map { $0.currentValue }.max() ?? 0
        return max(maxInvest, maxCurrent) * 1.05
    }
    
    @ViewBuilder
    private var chartView: some View {
        Chart {
            ForEach(analyticsVM.chartDataPoints) { dataPoint in
                if showInvestmentLine {
                    LineMark(
                        x: .value("Date", dataPoint.date),
                        y: .value("Investment", dataPoint.investmentValue)
                    )
                    .foregroundStyle(Color.theme.blue)
                    .lineStyle(StrokeStyle(lineWidth: 2.5, dash: [6, 4]))
                    .interpolationMethod(.catmullRom)
                }
                
                if showCurrentValueLine {
                    LineMark(
                        x: .value("Date", dataPoint.date),
                        y: .value("Current Value", dataPoint.currentValue)
                    )
                    .foregroundStyle(Color.theme.accent)
                    .lineStyle(StrokeStyle(lineWidth: 3.5))
                    .interpolationMethod(.catmullRom)
                }
                
                if showCurrentValueLine {
                    AreaMark(
                        x: .value("Date", dataPoint.date),
                        yStart: .value("Min", minY),
                        yEnd: .value("Current Value", dataPoint.currentValue)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                Color.theme.accent.opacity(0.25),
                                Color.theme.accent.opacity(0.05)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .interpolationMethod(.catmullRom)
                }
            }
            
            if let selectedPoint = selectedDataPoint {
                RuleMark(x: .value("Date", selectedPoint.date))
                    .foregroundStyle(Color.theme.accent.opacity(0.5))
                    .lineStyle(StrokeStyle(lineWidth: 2, dash: [4, 4]))
                    .annotation(position: .top, spacing: 10) {
                        VStack(spacing: 6) {
                            Text(fullFormatCurrency(selectedPoint.currentValue))
                                .font(.caption.bold())
                                .foregroundColor(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    Capsule()
                                        .fill(Color.theme.accent)
                                        .shadow(color: Color.theme.accent.opacity(0.4), radius: 4, x: 0, y: 2)
                                )
                        }
                    }
            }
        }
        .frame(height: 340)
        .chartYScale(domain: minY...maxY)
        .chartXAxis {
            AxisMarks(values: .stride(by: getStride(), count: getStrideCount() ?? 6)) { value in
                if let date = value.as(Date.self) {
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(Color.theme.divider)
                    
                    AxisValueLabel {
                        Text(date, format: getDateFormat())
                            .font(.caption)
                            .foregroundColor(Color.theme.secondary)
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 6)) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(Color.theme.divider)
                
                AxisValueLabel {
                    if let doubleValue = value.as(Double.self) {
                        Text(formatCurrency(doubleValue))
                            .font(.caption)
                            .foregroundColor(Color.theme.secondary)
                    }
                }
            }
        }
        .chartXSelection(value: $chartSelection)
        .onChange(of: chartSelection) { oldValue, newValue in
            if let newDate = newValue {
                selectedDataPoint = analyticsVM.chartDataPoints.min(by: {
                    abs($0.date.timeIntervalSince(newDate)) < abs($1.date.timeIntervalSince(newDate))
                })
            } else {
                selectedDataPoint = nil
            }
        }
    }
    
    @ViewBuilder
    private func performanceSummary(for dataPoint: ChartDataPoint) -> some View {
        HStack(spacing: 0) {
            performanceCard(
                title: "Investment",
                value: fullFormatCurrency(dataPoint.investmentValue),
                color: Color.theme.blue
            )
            
            Divider()
                .frame(height: 70)
                .padding(.horizontal, 16)
                .background(Color.theme.divider)
            
            performanceCard(
                title: "Current Value",
                value: fullFormatCurrency(dataPoint.currentValue),
                color: Color.theme.accent
            )
            
            Divider()
                .frame(height: 70)
                .padding(.horizontal, 16)
                .background(Color.theme.divider)
            
            performanceCard(
                title: "Gain/Loss",
                value: fullFormatCurrency(dataPoint.gainLoss),
                subtitle: "(\(String(format: "%.2f%%", dataPoint.gainLossPercentage)))",
                color: dataPoint.gainLoss >= 0 ? Color.theme.green : Color.theme.red
            )
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.theme.background)
                .shadow(color: Color.theme.cardShadow, radius: 6, x: 0, y: 2)
        )
    }
    
    @ViewBuilder
    private func performanceCard(title: String, value: String, subtitle: String = "", color: Color) -> some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundColor(Color.theme.secondary)
                .textCase(.uppercase)
            
            Text(value)
                .font(.headline.bold())
                .foregroundColor(color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            
            if !subtitle.isEmpty {
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(color.opacity(0.8))
            }
        }
        .frame(maxWidth: .infinity)
    }
    
    @ViewBuilder
    private var legendSection: some View {
        HStack(spacing: 20) {
            LegendItem(
                color: Color.theme.blue,
                label: "Investment",
                isVisible: $showInvestmentLine
            )
            
            LegendItem(
                color: Color.theme.accent,
                label: "Current Value",
                isVisible: $showCurrentValueLine
            )
            
            Spacer()
            
            if selectedDataPoint != nil {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        selectedDataPoint = nil
                        chartSelection = nil
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.caption)
                        Text("Clear")
                            .font(.caption.weight(.semibold))
                    }
                    .foregroundColor(Color.theme.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(Color.theme.buttonSecondary)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func getStride() -> Calendar.Component {
        switch analyticsVM.selectedTimeRange {
        case .oneMonth: return .day
        case .threeMonths: return .weekOfYear
        case .sixMonths: return .weekOfYear
        case .oneYear: return .month
        case .all: return .month
        }
    }
    
    private func getStrideCount() -> Int? {
        switch analyticsVM.selectedTimeRange {
        case .oneMonth: return 7
        case .threeMonths: return 12
        case .sixMonths: return 6
        case .oneYear: return 12
        case .all: return nil
        }
    }
    
    private func getDateFormat() -> Date.FormatStyle {
        switch analyticsVM.selectedTimeRange {
        case .oneMonth:
            return .dateTime.month(.abbreviated).day()
        case .threeMonths, .sixMonths:
            return .dateTime.month(.abbreviated).day()
        case .oneYear, .all:
            return .dateTime.month(.abbreviated)
        }
    }
    
    private func formatCurrency(_ value: Double) -> String {
        if value >= 1_000_000 {
            return String(format: "₹%.1fM", value / 1_000_000)
        } else if value >= 1_000 {
            return String(format: "₹%.1fK", value / 1_000)
        } else {
            return fullFormatCurrency(value)
        }
    }
    
    private func fullFormatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "₹"
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 2
        return formatter.string(from: NSNumber(value: value)) ?? "₹0.00"
    }
}

struct LegendItem: View {
    let color: Color
    let label: String
    @Binding var isVisible: Bool
    
    var body: some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.25)) {
                isVisible.toggle()
            }
        }) {
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(isVisible ? color : Color.theme.tertiaryText)
                    .frame(width: 20, height: 4)
                
                Text(label)
                    .font(.caption.weight(.medium))
                    .foregroundColor(isVisible ? Color.theme.primaryText : Color.theme.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isVisible ? color.opacity(0.1) : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }
}
