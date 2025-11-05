import SwiftUI
import Charts

struct PortfolioRatingView: View {
    let rating: PortfolioAnalysisResponse
    @State private var selectedScore: String? = nil
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // ML Status Banner (if available)
                if rating.hasMLPredictions {
                    mlStatusBanner
                }
                
                // Overall Rating Card
                overallRatingCard
                
                // ML Risk Prediction (if available)
                if let mlInsights = rating.mlInsights {
                    mlRiskPredictionCard(mlInsights: mlInsights)
                }
                
                // Anomaly Detection (if flagged)
                if rating.hasAnomalies, let mlInsights = rating.mlInsights {
                    anomalyWarningCard(anomaly: mlInsights.anomalyDetection)
                }
                
                // Score Breakdown Cards
                scoreBreakdownSection
                
                // Insights Section
                if !rating.insights.isEmpty {
                    insightsSection
                }
                
                // Recommendations Section
                if !rating.recommendations.isEmpty {
                    recommendationsSection
                }
                
                // Key Metrics
                keyMetricsSection
                
                // Distribution Charts
                distributionSection
            }
            .padding(20)
        }
        .background(Color(.systemGroupedBackground))
    }
    
    // MARK: - ML Status Banner
    
    @ViewBuilder
    private var mlStatusBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "brain.head.profile")
                .font(.title3)
                .foregroundColor(.purple)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("AI-Enhanced Analysis")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.primary)
                
                Text("Machine learning predictions included")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Image(systemName: "checkmark.seal.fill")
                .foregroundColor(.purple)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.purple.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.purple.opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    // MARK: - Overall Rating Card
    
    @ViewBuilder
    private var overallRatingCard: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Portfolio Rating")
                        .font(.title3.bold())
                        .foregroundColor(.primary)
                    
                    Text(rating.hasMLPredictions ? "AI-Powered Analysis" : "Rules-Based Analysis")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            HStack(spacing: 20) {
                // Grade Circle
                ZStack {
                    Circle()
                        .fill(gradeColor.opacity(0.15))
                        .frame(width: 100, height: 100)
                    
                    Circle()
                        .stroke(gradeColor, lineWidth: 8)
                        .frame(width: 100, height: 100)
                    
                    VStack(spacing: 4) {
                        Text(rating.overall.grade)
                            .font(.system(size: 40, weight: .bold))
                            .foregroundColor(gradeColor)
                        
                        Text(String(format: "%.0f", rating.overall.score))
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.secondary)
                    }
                }
                
                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(rating.overall.assessment)
                            .font(.title2.bold())
                            .foregroundColor(.primary)
                        
                        Text("Portfolio Health")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Divider()
                    
                    HStack(spacing: 16) {
                        MetricPill(
                            label: "Holdings",
                            value: "\(rating.overall.holdingsCount)",
                            color: .blue
                        )
                        
                        MetricPill(
                            label: "Value",
                            value: formatCurrency(rating.overall.totalValue),
                            color: .green
                        )
                    }
                }
                
                Spacer()
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.secondarySystemGroupedBackground))
                .shadow(color: gradeColor.opacity(0.2), radius: 10, x: 0, y: 4)
        )
    }
    
    // MARK: - ML Risk Prediction Card
    
    @ViewBuilder
    private func mlRiskPredictionCard(mlInsights: MLInsights) -> some View {
        let prediction = mlInsights.riskPrediction
        
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.title3)
                    .foregroundColor(.purple)
                
                Text("AI Risk Prediction")
                    .font(.headline.weight(.semibold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                if prediction.predictionAvailable {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                }
            }
            
            if prediction.predictionAvailable, let mlScore = prediction.mlRiskScore {
                VStack(spacing: 14) {
                    HStack(spacing: 20) {
                        // ML Risk Score Gauge
                        ZStack {
                            Circle()
                                .stroke(Color(.systemGray5), lineWidth: 12)
                                .frame(width: 90, height: 90)
                            
                            Circle()
                                .trim(from: 0, to: mlScore / 100)
                                .stroke(
                                    riskScoreColor(mlScore),
                                    style: StrokeStyle(lineWidth: 12, lineCap: .round)
                                )
                                .frame(width: 90, height: 90)
                                .rotationEffect(.degrees(-90))
                            
                            VStack(spacing: 2) {
                                Text(String(format: "%.0f", mlScore))
                                    .font(.title.bold())
                                    .foregroundColor(riskScoreColor(mlScore))
                                
                                Text("Risk")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: 10) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(prediction.riskLevel)
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                Text("Machine Learning Assessment")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            if let volatility = prediction.predictedVolatility {
                                HStack(spacing: 6) {
                                    Image(systemName: "waveform.path.ecg")
                                        .font(.caption)
                                        .foregroundColor(.orange)
                                    
                                    Text("Predicted Volatility: \(String(format: "%.3f", volatility))")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            HStack(spacing: 6) {
                                Image(systemName: "checkmark.shield.fill")
                                    .font(.caption)
                                    .foregroundColor(.green)
                                
                                Text("Confidence: \(String(format: "%.0f%%", prediction.confidence))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                    }
                    
                    // Comparison with rules-based score
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Combined Risk Score")
                                .font(.caption.weight(.medium))
                                .foregroundColor(.secondary)
                            
                            Text(String(format: "%.1f", rating.combinedRiskScore))
                                .font(.title3.bold())
                                .foregroundColor(.primary)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("Rules-Based")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text(String(format: "%.1f", rating.scores.riskManagement))
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(.blue)
                        }
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color(.tertiarySystemGroupedBackground))
                    )
                }
            } else {
                Text("ML risk prediction not available")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 8)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.secondarySystemGroupedBackground))
                .shadow(color: .purple.opacity(0.15), radius: 8, x: 0, y: 4)
        )
    }
    
    // MARK: - Anomaly Warning Card
    
    @ViewBuilder
    private func anomalyWarningCard(anomaly: AnomalyDetection) -> some View {
        VStack(spacing: 14) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.title3)
                    .foregroundColor(.red)
                
                Text("Portfolio Anomaly Detected")
                    .font(.headline.weight(.semibold))
                    .foregroundColor(.primary)
                
                Spacer()
            }
            
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Severity: \(anomaly.severityLevel)")
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.red)
                    
                    Text("Anomaly Score: \(String(format: "%.0f", anomaly.anomalyScore))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            if !anomaly.warnings.isEmpty {
                VStack(spacing: 8) {
                    ForEach(Array(anomaly.warnings.enumerated()), id: \.offset) { _, warning in
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "exclamationmark.circle.fill")
                                .font(.caption)
                                .foregroundColor(.orange)
                            
                            Text(warning)
                                .font(.caption)
                                .foregroundColor(.primary)
                                .fixedSize(horizontal: false, vertical: true)
                            
                            Spacer()
                        }
                        .padding(10)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.orange.opacity(0.1))
                        )
                    }
                }
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.red.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(Color.red.opacity(0.3), lineWidth: 2)
                )
        )
    }
    
    // MARK: - Score Breakdown Section
    
    @ViewBuilder
    private var scoreBreakdownSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Score Breakdown")
                .font(.headline.weight(.semibold))
                .foregroundColor(.primary)
            
            VStack(spacing: 12) {
                ScoreRow(
                    title: "Diversification",
                    score: rating.scores.diversification,
                    icon: "chart.pie.fill",
                    description: "Sector and stock distribution"
                )
                
                ScoreRow(
                    title: "Valuation (P/E)",
                    score: rating.scores.peRating,
                    icon: "chart.bar.fill",
                    description: "Price to earnings analysis"
                )
                
                ScoreRow(
                    title: "Risk Management",
                    score: rating.scores.riskManagement,
                    icon: "shield.fill",
                    description: "Beta and concentration risk"
                )
                
                ScoreRow(
                    title: "Allocation Quality",
                    score: rating.scores.allocationQuality,
                    icon: "scale.3d",
                    description: "Position sizing balance"
                )
                
                ScoreRow(
                    title: "Market Cap Mix",
                    score: rating.scores.marketCapMix,
                    icon: "building.2.fill",
                    description: "Large/Mid/Small cap distribution"
                )
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.secondarySystemGroupedBackground))
                .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 4)
        )
    }
    
    // MARK: - Insights Section
    
    @ViewBuilder
    private var insightsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .font(.title3)
                    .foregroundColor(.orange)
                
                Text("Insights")
                    .font(.headline.weight(.semibold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text("\(rating.insights.count)")
                    .font(.caption.weight(.medium))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color(.systemGray6))
                    )
            }
            
            LazyVStack(spacing: 10) {
                ForEach(rating.insights) { insight in
                    InsightCard(insight: insight)
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.secondarySystemGroupedBackground))
                .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 4)
        )
    }
    
    // MARK: - Recommendations Section
    
    @ViewBuilder
    private var recommendationsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "star.fill")
                    .font(.title3)
                    .foregroundColor(.blue)
                
                Text("Recommendations")
                    .font(.headline.weight(.semibold))
                    .foregroundColor(.primary)
            }
            
            VStack(spacing: 10) {
                ForEach(Array(rating.recommendations.enumerated()), id: \.offset) { index, recommendation in
                    HStack(alignment: .top, spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Color.blue.opacity(0.15))
                                .frame(width: 28, height: 28)
                            
                            Text("\(index + 1)")
                                .font(.caption.bold())
                                .foregroundColor(.blue)
                        }
                        
                        Text(recommendation)
                            .font(.subheadline)
                            .foregroundColor(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                        
                        Spacer()
                    }
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.tertiarySystemGroupedBackground))
                    )
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.secondarySystemGroupedBackground))
                .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 4)
        )
    }
    
    // MARK: - Key Metrics Section
    
    @ViewBuilder
    private var keyMetricsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Key Metrics")
                .font(.headline.weight(.semibold))
                .foregroundColor(.primary)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                KeyMetricCard(
                    title: "Avg P/E Ratio",
                    value: rating.metrics.averagePE != nil ? String(format: "%.1f", rating.metrics.averagePE!) : "N/A",
                    icon: "chart.line.uptrend.xyaxis",
                    color: .purple
                )
                
                KeyMetricCard(
                    title: "Avg Beta",
                    value: rating.metrics.averageBeta != nil ? String(format: "%.2f", rating.metrics.averageBeta!) : "N/A",
                    icon: "waveform.path.ecg",
                    color: .orange
                )
                
                KeyMetricCard(
                    title: "Sectors",
                    value: "\(rating.metrics.sectorCount)",
                    icon: "square.grid.3x3.fill",
                    color: .green
                )
                
                KeyMetricCard(
                    title: "Max Sector",
                    value: String(format: "%.1f%%", rating.metrics.maxSectorWeight),
                    icon: "chart.pie.fill",
                    color: .red
                )
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.secondarySystemGroupedBackground))
                .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 4)
        )
    }
    
    // MARK: - Distribution Section
    
    @ViewBuilder
    private var distributionSection: some View {
        VStack(spacing: 20) {
            // Sector Distribution
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "chart.pie.fill")
                        .font(.title3)
                        .foregroundColor(.blue)
                    
                    Text("Sector Distribution")
                        .font(.headline.weight(.semibold))
                        .foregroundColor(.primary)
                }
                
                if !rating.distribution.topSectors.isEmpty {
                    VStack(spacing: 10) {
                        ForEach(rating.distribution.topSectors, id: \.name) { sector in
                            HStack {
                                Text(sector.name)
                                    .font(.subheadline)
                                    .foregroundColor(.primary)
                                
                                Spacer()
                                
                                Text(String(format: "%.1f%%", sector.percentage))
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundColor(.blue)
                            }
                            
                            GeometryReader { geometry in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color(.systemGray5))
                                        .frame(height: 8)
                                    
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color.blue)
                                        .frame(width: geometry.size.width * (sector.percentage / 100), height: 8)
                                }
                            }
                            .frame(height: 8)
                        }
                    }
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(.secondarySystemGroupedBackground))
                    .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 4)
            )
            
            // Market Cap Distribution
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "building.2.fill")
                        .font(.title3)
                        .foregroundColor(.green)
                    
                    Text("Market Cap Distribution")
                        .font(.headline.weight(.semibold))
                        .foregroundColor(.primary)
                }
                
                if !rating.distribution.marketCapBreakdown.isEmpty {
                    VStack(spacing: 10) {
                        ForEach(rating.distribution.marketCapBreakdown, id: \.category) { cap in
                            HStack {
                                Text(cap.category)
                                    .font(.subheadline)
                                    .foregroundColor(.primary)
                                
                                Spacer()
                                
                                Text(String(format: "%.1f%%", cap.percentage))
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundColor(capColor(cap.category))
                            }
                            
                            GeometryReader { geometry in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color(.systemGray5))
                                        .frame(height: 8)
                                    
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(capColor(cap.category))
                                        .frame(width: geometry.size.width * (cap.percentage / 100), height: 8)
                                }
                            }
                            .frame(height: 8)
                        }
                    }
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(.secondarySystemGroupedBackground))
                    .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 4)
            )
        }
    }
    
    // MARK: - Helper Properties
    
    private var gradeColor: Color {
        switch rating.overall.grade {
        case "A": return .green
        case "B": return .blue
        case "C": return .orange
        case "D": return .red
        default: return .red
        }
    }
    
    private func riskScoreColor(_ score: Double) -> Color {
        if score >= 80 { return .green }
        if score >= 60 { return .blue }
        if score >= 40 { return .orange }
        return .red
    }
    
    private func capColor(_ category: String) -> Color {
        switch category {
        case "Large": return .green
        case "Mid": return .blue
        case "Small": return .orange
        default: return .gray
        }
    }
    
    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "₹"
        formatter.maximumFractionDigits = 0
        
        if value >= 10000000 {
            return "₹\(String(format: "%.2f", value / 10000000))Cr"
        } else if value >= 100000 {
            return "₹\(String(format: "%.2f", value / 100000))L"
        } else {
            return formatter.string(from: NSNumber(value: value)) ?? "₹0"
        }
    }
}

// MARK: - Supporting Views

struct ScoreRow: View {
    let title: String
    let score: Double
    let icon: String
    let description: String
    
    @State private var animatedScore: Double = 0
    
    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(scoreColor.opacity(0.15))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(scoreColor)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.primary)
                    
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text(String(format: "%.0f", animatedScore))
                        .font(.title3.bold())
                        .foregroundColor(scoreColor)
                    
                    Text("/ 100")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(.systemGray5))
                        .frame(height: 8)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [scoreColor.opacity(0.7), scoreColor],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * (animatedScore / 100), height: 8)
                }
            }
            .frame(height: 8)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.tertiarySystemGroupedBackground))
        )
        .onAppear {
            withAnimation(.easeOut(duration: 1.0)) {
                animatedScore = score
            }
        }
    }
    
    private var scoreColor: Color {
        if score >= 80 { return .green }
        else if score >= 70 { return .blue }
        else if score >= 60 { return .orange }
        else { return .red }
    }
}

struct InsightCard: View {
    let insight: Insight
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: insightIcon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(insightColor)
                .frame(width: 24, height: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(insight.category)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(insightColor)
                    .textCase(.uppercase)
                
                Text(insight.message)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(insightColor.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(insightColor.opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    private var insightIcon: String {
        switch insight.type {
        case "warning": return "exclamationmark.triangle.fill"
        case "positive": return "checkmark.circle.fill"
        default: return "info.circle.fill"
        }
    }
    
    private var insightColor: Color {
        switch insight.type {
        case "warning": return .orange
        case "positive": return .green
        default: return .blue
        }
    }
}

struct KeyMetricCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(color)
                
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(value)
                    .font(.title2.bold())
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.tertiarySystemGroupedBackground))
        )
    }
}

struct MetricPill: View {
    let label: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
                .textCase(.uppercase)
            
            Text(value)
                .font(.caption.bold())
                .foregroundColor(color)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(color.opacity(0.1))
        )
    }
}

// MARK: - Preview

#Preview {
    NavigationView {
        PortfolioRatingView(rating: PortfolioAnalysisResponse(
            overall: OverallRating(
                score: 78.5,
                grade: "B",
                assessment: "Good",
                totalValue: 250000,
                holdingsCount: 8
            ),
            scores: DetailedScores(
                diversification: 75.0,
                peRating: 82.0,
                riskManagement: 68.0,
                allocationQuality: 80.0,
                marketCapMix: 85.0
            ),
            metrics: PortfolioMetrics(
                averagePE: 22.5,
                averageBeta: 1.15,
                sectorCount: 5,
                maxSectorWeight: 35.0,
                maxStockWeight: 18.0
            ),
            distribution: Distribution(
                sectors: ["Technology": 35.0, "Finance": 25.0, "Healthcare": 20.0, "Consumer": 15.0, "Energy": 5.0],
                marketCaps: ["Large": 70.0, "Mid": 20.0, "Small": 10.0]
            ),
            insights: [
                Insight(type: "positive", category: "Valuation", message: "Well-valued portfolio with attractive P/E ratios"),
                Insight(type: "warning", category: "Risk", message: "Consider reducing volatility exposure"),
                Insight(type: "neutral", category: "Diversification", message: "Good sector spread across 5 sectors")
            ],
            recommendations: [
                "Add defensive stocks to reduce overall portfolio beta",
                "Diversify into more sectors to reduce concentration risk",
                "Consider rebalancing to maintain 60-70% large-cap allocation"
            ],
            holdings: nil,
            mlInsights: MLInsights(
                riskPrediction: RiskPrediction(
                    mlRiskScore: 72.5,
                    predictedVolatility: 0.245,
                    confidence: 85.0,
                    predictionAvailable: true
                ),
                anomalyDetection: AnomalyDetection(
                    isAnomaly: false,
                    anomalyScore: 25.0,
                    warnings: []
                )
            )
        ))
        .navigationTitle("Portfolio Rating")
    }
}
