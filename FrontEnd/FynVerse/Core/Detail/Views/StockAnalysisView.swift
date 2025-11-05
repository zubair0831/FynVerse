// StockAnalysisView.swift
// FynVerse
// Created by zubair ahmed

import SwiftUI

struct StockAnalysisView: View {
    let stockSymbol: String
    @StateObject private var viewModel = StockAnalysisViewModel()
    @State private var animatedScore: Double = 0
    
    var body: some View {
        ScrollView {
            Group {
                if viewModel.isLoading {
                    loadingView
                } else if let analysis = viewModel.analysisResponse {
                    analysisContent(analysis)
                } else if let error = viewModel.errorMessage {
                    errorView(error)
                }
            }
        }
        .task {
            await viewModel.fetchAnalysis(for: stockSymbol)
        }
    }
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView("Analyzing \(stockSymbol)...")
                .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                .scaleEffect(1.2)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }
    
    private func errorView(_ message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40))
                .foregroundColor(.orange)
            Text(message)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
    
    private func analysisContent(_ analysis: StockAnalysisResponse) -> some View {
        VStack(spacing: 20) {
            headerSection(analysis)
            scoreCard(analysis.analysis)
            valuationAnalysisSection(analysis.valuationAnalysis)
            priceDataSection(analysis.priceData)
            performanceSection(analysis.performance)
            fundamentalsSection(analysis.fundamentals)
            riskMetricsSection(analysis.riskMetrics)
            signalsSection(analysis.analysis.signals)
            methodologySection(analysis.methodology)
            disclaimerSection(analysis.disclaimer)
        }
        .padding()
    }
    
    private func headerSection(_ analysis: StockAnalysisResponse) -> some View {
        VStack(spacing: 8) {
            Text(analysis.companyName)
                .font(.title2.bold())
                .foregroundStyle(LinearGradient(colors: [.blue, .purple], startPoint: .leading, endPoint: .trailing))
            
            HStack(spacing: 12) {
                Text(analysis.ticker)
                    .font(.caption)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(.blue.opacity(0.2)))
                
                Text(analysis.sector)
                    .font(.caption)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(.purple.opacity(0.2)))
            }
            .foregroundColor(.secondary)
        }
    }
    
    private func scoreCard(_ analysis: StockAnalysisData) -> some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 12)
                    .frame(width: 120, height: 120)
                
                Circle()
                    .trim(from: 0, to: animatedScore / 100)
                    .stroke(recommendationColor(analysis.recommendation), style: StrokeStyle(lineWidth: 12, lineCap: .round))
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut(duration: 1.2), value: animatedScore)
                
                VStack(spacing: 4) {
                    Text(String(format: "%.1f", analysis.score))
                        .font(.system(size: 36, weight: .bold))
                    Text("/ \(analysis.maxScore)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Text(analysis.recommendation)
                .font(.headline.bold())
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .fill(recommendationColor(analysis.recommendation))
                        .shadow(color: recommendationColor(analysis.recommendation).opacity(0.4), radius: 8)
                )
            
            Text(analysis.overallAssessment)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.1), radius: 10)
        )
        .onAppear {
            animatedScore = analysis.scorePercentage
        }
    }
    
    private func valuationAnalysisSection(_ valuation: StockValuationAnalysis) -> some View {
        CardView(title: "Valuation Analysis (Research-Based)", icon: "chart.bar.doc.horizontal.fill") {
            VStack(spacing: 14) {
                // Grade Badge
                HStack {
                    Text("Grade")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(valuation.grade)
                        .font(.title2.bold())
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(gradeColor(valuation.grade))
                        )
                }
                
                // Score Bar
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Valuation Score")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(String(format: "%.1f", valuation.score))/100")
                            .font(.subheadline.bold())
                    }
                    
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.gray.opacity(0.15))
                            RoundedRectangle(cornerRadius: 4)
                                .fill(LinearGradient(colors: [gradeColor(valuation.grade).opacity(0.7), gradeColor(valuation.grade)], startPoint: .leading, endPoint: .trailing))
                                .frame(width: geo.size.width * CGFloat(valuation.score / 100))
                        }
                    }
                    .frame(height: 8)
                }
                
                // Assessment
                Text(valuation.assessment)
                    .font(.caption)
                    .foregroundColor(.primary)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(gradeColor(valuation.grade).opacity(0.1))
                    )
                
                Divider()
                
                // P/E and PEG Ratios
                if let pe = valuation.peRatio {
                    MetricRow(label: "P/E Ratio", value: String(format: "%.2f", pe))
                }
                if let peg = valuation.pegRatio {
                    MetricRow(label: "PEG Ratio", value: String(format: "%.2f", peg), valueColor: pegColor(peg))
                }
                MetricRow(label: "Sector CAGR", value: String(format: "%.1f%%", valuation.sectorCAGR))
                
                // Reasoning
                if !valuation.reasoning.isEmpty {
                    Divider()
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Key Factors")
                            .font(.caption.bold())
                            .foregroundColor(.secondary)
                        
                        ForEach(valuation.reasoning) { reason in
                            ValuationReasonRow(reason: reason)
                        }
                    }
                }
            }
        }
    }
    
    private func priceDataSection(_ priceData: StockPriceData) -> some View {
        CardView(title: "Price Data", icon: "chart.line.uptrend.xyaxis") {
            VStack(spacing: 12) {
                MetricRow(label: "Current Price", value: "₹\(String(format: "%.2f", priceData.currentPrice))", valueColor: .primary)
                
                if let ma20 = priceData.ma20 {
                    MetricRow(label: "20-Day MA", value: "₹\(String(format: "%.2f", ma20))")
                }
                if let ma50 = priceData.ma50 {
                    MetricRow(label: "50-Day MA", value: "₹\(String(format: "%.2f", ma50))")
                }
                if let ma200 = priceData.ma200 {
                    MetricRow(label: "200-Day MA", value: "₹\(String(format: "%.2f", ma200))")
                }
                
                Divider()
                
                MetricRow(label: "52W High", value: "₹\(String(format: "%.2f", priceData.week52High))", valueColor: .green)
                MetricRow(label: "52W Low", value: "₹\(String(format: "%.2f", priceData.week52Low))", valueColor: .red)
                ProgressMetricRow(label: "52W Position", percentage: priceData.positionIn52wRange)
                
                if let rsi = priceData.rsi {
                    MetricRow(label: "RSI", value: String(format: "%.1f", rsi), valueColor: rsiColor(rsi))
                }
            }
        }
    }
    
    private func performanceSection(_ performance: StockPerformanceData) -> some View {
        CardView(title: "Performance", icon: "chart.bar.fill") {
            VStack(spacing: 12) {
                if let oneWeek = performance.oneWeek {
                    PerformanceRow(period: "1 Week", value: oneWeek)
                }
                if let oneMonth = performance.oneMonth {
                    PerformanceRow(period: "1 Month", value: oneMonth)
                }
                if let threeMonth = performance.threeMonth {
                    PerformanceRow(period: "3 Months", value: threeMonth)
                }
                if let sixMonth = performance.sixMonth {
                    PerformanceRow(period: "6 Months", value: sixMonth)
                }
            }
        }
    }
    
    private func fundamentalsSection(_ fundamentals: StockFundamentals) -> some View {
        CardView(title: "Fundamentals", icon: "building.columns.fill") {
            VStack(spacing: 12) {
                if let mcap = fundamentals.marketCap {
                    MetricRow(label: "Market Cap", value: mcap.displayValue, valueColor: .blue)
                    Divider()
                }
                
                if let pe = fundamentals.peRatio {
                    MetricRow(label: "P/E Ratio", value: String(format: "%.2f", pe))
                }
                if let forwardPE = fundamentals.forwardPE {
                    MetricRow(label: "Forward P/E", value: String(format: "%.2f", forwardPE))
                }
                if let pb = fundamentals.pbRatio {
                    MetricRow(label: "P/B Ratio", value: String(format: "%.2f", pb))
                }
                if let de = fundamentals.debtToEquity {
                    MetricRow(label: "Debt/Equity", value: String(format: "%.1f%%", de), valueColor: debtColor(de))
                }
                if let roe = fundamentals.roe {
                    MetricRow(label: "ROE", value: String(format: "%.1f%%", roe), valueColor: roe > 15 ? .green : .primary)
                }
                if let pm = fundamentals.profitMargin {
                    MetricRow(label: "Profit Margin", value: String(format: "%.1f%%", pm), valueColor: pm > 15 ? .green : .primary)
                }
                if let rg = fundamentals.revenueGrowth {
                    MetricRow(label: "Revenue Growth", value: String(format: "%.1f%%", rg), valueColor: rg > 0 ? .green : .red)
                }
                if let eg = fundamentals.earningsGrowth {
                    MetricRow(label: "Earnings Growth", value: String(format: "%.1f%%", eg), valueColor: eg > 0 ? .green : .red)
                }
                if let dy = fundamentals.dividendYield {
                    MetricRow(label: "Dividend Yield", value: String(format: "%.2f%%", dy))
                }
                if let beta = fundamentals.beta {
                    MetricRow(label: "Beta", value: String(format: "%.2f", beta), valueColor: betaColor(beta))
                }
            }
        }
    }
    
    private func riskMetricsSection(_ riskMetrics: StockRiskMetrics) -> some View {
        CardView(title: "Risk Metrics", icon: "exclamationmark.shield.fill") {
            VStack(spacing: 12) {
                if let vol = riskMetrics.volatility60dAnnualized {
                    MetricRow(label: "Volatility (60D)", value: String(format: "%.1f%%", vol), valueColor: volatilityColor(vol))
                }
                if let vr = riskMetrics.volumeRatio {
                    MetricRow(label: "Volume Ratio", value: String(format: "%.2f", vr))
                }
                if let avgVol = riskMetrics.avgVolume20d {
                    MetricRow(label: "Avg Volume (20D)", value: formatVolume(avgVol))
                }
            }
        }
    }
    
    private func signalsSection(_ signals: [AnalysisSignalItem]) -> some View {
        CardView(title: "Analysis Signals", icon: "chart.xyaxis.line") {
            VStack(spacing: 10) {
                ForEach(signals) { signal in
                    SignalRow(signal: signal)
                }
            }
        }
    }
    
    private func methodologySection(_ methodology: AnalysisMethodology) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "doc.text.magnifyingglass")
                    .foregroundColor(.blue)
                Text("Methodology")
                    .font(.headline)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                MethodologyRow(label: "Approach", value: methodology.approach)
                MethodologyRow(label: "P/E Framework", value: methodology.peFramework)
                MethodologyRow(label: "Research Basis", value: methodology.researchBasis)
                MethodologyRow(label: "Reference", value: methodology.reference)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.blue.opacity(0.1))
        )
    }
    
    private func disclaimerSection(_ disclaimer: AnalysisDisclaimer) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(.orange)
                Text("Disclaimer")
                    .font(.headline)
            }
            
            Text(disclaimer.message)
                .font(.caption)
                .foregroundColor(.secondary)
            
            ForEach(disclaimer.warnings, id: \.self) { warning in
                HStack(alignment: .top, spacing: 6) {
                    Text("•")
                    Text(warning)
                        .font(.caption2)
                }
                .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.orange.opacity(0.1))
        )
    }
    
    // MARK: - Helper Functions
    
    private func recommendationColor(_ recommendation: String) -> Color {
        switch recommendation.uppercased() {
        case "POSITIVE": return .green
        case "NEGATIVE": return .red
        case "NEUTRAL", "CAUTIOUS": return .orange
        default: return .gray
        }
    }
    
    private func gradeColor(_ grade: String) -> Color {
        switch grade.uppercased() {
        case "A": return .green
        case "B": return .blue
        case "C": return .orange
        case "D": return .red
        case "F": return .red
        default: return .gray
        }
    }
    
    private func pegColor(_ peg: Double) -> Color {
        if peg < 1.0 { return .green }
        if peg <= 2.0 { return .blue }
        if peg <= 3.0 { return .orange }
        return .red
    }
    
    private func rsiColor(_ rsi: Double) -> Color {
        if rsi > 70 { return .red }
        if rsi < 30 { return .green }
        return .primary
    }
    
    private func betaColor(_ beta: Double) -> Color {
        if beta < 0.8 { return .green }
        if beta <= 1.2 { return .blue }
        return .orange
    }
    
    private func debtColor(_ debt: Double) -> Color {
        if debt < 50 { return .green }
        if debt <= 100 { return .orange }
        return .red
    }
    
    private func volatilityColor(_ vol: Double) -> Color {
        if vol < 20 { return .green }
        if vol <= 40 { return .orange }
        return .red
    }
    
    private func formatVolume(_ volume: Double) -> String {
        if volume >= 1_000_000 {
            return String(format: "%.2fM", volume / 1_000_000)
        } else if volume >= 1_000 {
            return String(format: "%.2fK", volume / 1_000)
        }
        return String(format: "%.0f", volume)
    }
}

// MARK: - Supporting Views

struct CardView<Content: View>: View {
    let title: String
    let icon: String
    let content: Content
    
    init(title: String, icon: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.blue)
                Text(title)
                    .font(.headline)
            }
            content
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.05), radius: 8)
        )
    }
}

struct MetricRow: View {
    let label: String
    let value: String
    var valueColor: Color = .secondary
    
    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline.bold())
                .foregroundColor(valueColor)
        }
    }
}

struct ProgressMetricRow: View {
    let label: String
    let percentage: Double
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(String(format: "%.1f", percentage))%")
                    .font(.caption.bold())
                    .foregroundColor(.secondary)
            }
            
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.15))
                    RoundedRectangle(cornerRadius: 4)
                        .fill(LinearGradient(colors: [.blue, .purple], startPoint: .leading, endPoint: .trailing))
                        .frame(width: geo.size.width * CGFloat(percentage / 100))
                }
            }
            .frame(height: 8)
        }
    }
}

struct PerformanceRow: View {
    let period: String
    let value: Double
    
    var body: some View {
        HStack {
            Text(period)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            HStack(spacing: 4) {
                Image(systemName: value >= 0 ? "arrow.up.right" : "arrow.down.right")
                    .font(.caption)
                Text("\(value >= 0 ? "+" : "")\(String(format: "%.2f", value))%")
                    .font(.subheadline.bold())
            }
            .foregroundColor(value >= 0 ? .green : .red)
        }
    }
}

struct SignalRow: View {
    let signal: AnalysisSignalItem
    
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: signalIcon)
                .foregroundColor(signalColor)
                .frame(width: 20)
            
            Text(signal.message)
                .font(.subheadline)
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)
            
            Spacer()
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(signalColor.opacity(0.1))
        )
    }
    
    private var signalIcon: String {
        switch signal.type.lowercased() {
        case "positive": return "checkmark.circle.fill"
        case "negative": return "xmark.circle.fill"
        case "neutral": return "minus.circle.fill"
        case "warning": return "exclamationmark.triangle.fill"
        default: return "circle.fill"
        }
    }
    
    private var signalColor: Color {
        switch signal.type.lowercased() {
        case "positive": return .green
        case "negative": return .red
        case "neutral": return .orange
        case "warning": return .orange
        default: return .gray
        }
    }
}

struct ValuationReasonRow: View {
    let reason: ValuationReasoningItem
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: reasonIcon)
                .font(.caption)
                .foregroundColor(reasonColor)
                .frame(width: 16)
            
            Text(reason.message)
                .font(.caption)
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)
            
            Spacer()
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(reasonColor.opacity(0.1))
        )
    }
    
    private var reasonIcon: String {
        switch reason.type.lowercased() {
        case "positive": return "arrow.up.circle.fill"
        case "negative": return "arrow.down.circle.fill"
        case "neutral": return "equal.circle.fill"
        case "warning": return "exclamationmark.triangle.fill"
        default: return "circle.fill"
        }
    }
    
    private var reasonColor: Color {
        switch reason.type.lowercased() {
        case "positive": return .green
        case "negative": return .red
        case "neutral": return .blue
        case "warning": return .orange
        default: return .gray
        }
    }
}

struct MethodologyRow: View {
    let label: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption.bold())
                .foregroundColor(.secondary)
            Text(value)
                .font(.caption)
                .foregroundColor(.primary)
        }
    }
}
