//
//  PortfolioGrowthChartView.swift
//  FynVerse
//
//  Created by zubair ahmed on 08/09/25.
//

import SwiftUI
import Charts

struct PortfolioGrowthChartView: View {
    @ObservedObject var analyticsVM: PortfolioAnalyticsViewModel
    @State private var selectedDataPoint: ChartDataPoint?
    @State private var showInvestmentLine = true
    @State private var showCurrentValueLine = true
    
    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Portfolio Growth")
                        .font(.title2.bold())
                        .foregroundColor(.primary)
                    
                    if let selectedPoint = selectedDataPoint {
                        Text(selectedPoint.date, style: .date)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Text("Tap to view details")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Time Range Selector
                Picker("Time Range", selection: Binding(
                    get: { analyticsVM.selectedTimeRange },
                    set: { newValue in
                        Task {
                            await analyticsVM.changeTimeRange(newValue)
                        }
                    }
                )) {
                    ForEach(PortfolioAnalyticsViewModel.TimeRange.allCases, id: \.self) { range in
                        Text(range.rawValue).tag(range)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 200)
            }
            
            // Performance Summary
            if let selectedPoint = selectedDataPoint {
                performanceSummary(for: selectedPoint)
            } else if let latestPoint = analyticsVM.chartDataPoints.last {
                performanceSummary(for: latestPoint)
            }
            
            // Chart
            if analyticsVM.isLoadingHistory {
                ProgressView("Loading chart data...")
                    .frame(height: 300)
            } else if analyticsVM.chartDataPoints.isEmpty {
                VStack {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 50))
                        .foregroundColor(.gray)
                    Text("No data available")
                        .foregroundColor(.secondary)
                    Text("Start investing to see your portfolio growth")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(height: 300)
            } else {
                chartView
            }
            
            // Legend
            HStack(spacing: 20) {
                LegendItem(
                    color: .blue,
                    label: "Investment",
                    isVisible: $showInvestmentLine
                )
                
                LegendItem(
                    color: .green,
                    label: "Current Value",
                    isVisible: $showCurrentValueLine
                )
                
                Spacer()
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
        )
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
                    .foregroundStyle(.blue)
                    .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 5]))
                    .interpolationMethod(.catmullRom)
                }
                
                if showCurrentValueLine {
                    LineMark(
                        x: .value("Date", dataPoint.date),
                        y: .value("Current Value", dataPoint.currentValue)
                    )
                    .foregroundStyle(.green)
                    .lineStyle(StrokeStyle(lineWidth: 3))
                    .interpolationMethod(.catmullRom)
                }
                
                // Area under current value line
                if showCurrentValueLine {
                    AreaMark(
                        x: .value("Date", dataPoint.date),
                        y: .value("Current Value", dataPoint.currentValue)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.green.opacity(0.3), .green.opacity(0.1)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .interpolationMethod(.catmullRom)
                }
            }
            
            // Selection indicator
            if let selectedPoint = selectedDataPoint {
                RuleMark(x: .value("Date", selectedPoint.date))
                    .foregroundStyle(.gray.opacity(0.5))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
            }
        }
        .frame(height: 300)
        .chartXAxis {
            AxisMarks(values: .stride(by: .day, count: max(1, analyticsVM.chartDataPoints.count / 5))) { _ in
                AxisGridLine()
                AxisTick()
                AxisValueLabel(format: .dateTime.month(.abbreviated).day())
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisGridLine()
                AxisTick()
                AxisValueLabel {
                    if let doubleValue = value.as(Double.self) {
                        Text(doubleValue.asCurrencyWith2Decimals())
                    }
                }
            }
        }
        .chartAngleSelection(value: .constant(nil as Double?))
        .chartBackground { chartProxy in
            GeometryReader { geometry in
                Rectangle()
                    .fill(Color.clear)
                    .contentShape(Rectangle())
                    .onTapGesture { location in
                        updateSelectedDataPoint(at: location, geometry: geometry, chartProxy: chartProxy)
                    }
            }
        }
    }
    
    @ViewBuilder
    private func performanceSummary(for dataPoint: ChartDataPoint) -> some View {
        HStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Investment")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(dataPoint.investmentValue.asCurrencyWith2Decimals())
                    .font(.headline)
                    .foregroundColor(.blue)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Current Value")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(dataPoint.currentValue.asCurrencyWith2Decimals())
                    .font(.headline)
                    .foregroundColor(.green)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Gain/Loss")
                    .font(.caption)
                    .foregroundColor(.secondary)
                HStack(spacing: 4) {
                    Text(dataPoint.gainLoss.asCurrencyWith2Decimals())
                        .font(.headline)
                    Text("(\(String(format: "%.2f%%", dataPoint.gainLossPercentage)))")
                        .font(.subheadline)
                }
                .foregroundColor(dataPoint.gainLoss >= 0 ? .green : .red)
            }
            
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
    
    private func updateSelectedDataPoint(
        at location: CGPoint,
        geometry: GeometryProxy,
        chartProxy: ChartProxy
    ) {
        guard let plotFrame = chartProxy.plotFrame else { return }
        
        let frameInGeometry = geometry[plotFrame]
        let xPosition = location.x - frameInGeometry.minX
        let plotWidth = frameInGeometry.width
        
        guard plotWidth > 0 else { return }
        
        let proportion = xPosition / plotWidth
        let dataIndex = Int(proportion * Double(analyticsVM.chartDataPoints.count))
        
        if dataIndex >= 0 && dataIndex < analyticsVM.chartDataPoints.count {
            selectedDataPoint = analyticsVM.chartDataPoints[dataIndex]
        }
    }
}

struct LegendItem: View {
    let color: Color
    let label: String
    @Binding var isVisible: Bool
    
    var body: some View {
        Button(action: {
            isVisible.toggle()
        }) {
            HStack(spacing: 6) {
                Circle()
                    .fill(isVisible ? color : Color.gray.opacity(0.3))
                    .frame(width: 12, height: 12)
                
                Text(label)
                    .font(.caption)
                    .foregroundColor(isVisible ? .primary : .secondary)
            }
        }
        .buttonStyle(.plain)
    }
}
