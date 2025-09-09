//
//  PortfolioAnalyticsView.swift
//  FynVerse
//
//  Created by zubair ahmed on 08/09/25.
//

import SwiftUI

struct PortfolioAnalyticsView: View {
    @StateObject private var analyticsVM: PortfolioAnalyticsViewModel
    @State private var selectedTab: AnalyticsTab = .growth
    
    enum AnalyticsTab: String, CaseIterable {
        case growth = "Growth"
        case allocation = "Sectors"
        
        var icon: String {
            switch self {
            case .growth: return "chart.line.uptrend.xyaxis"
            case .allocation: return "chart.pie"
            }
        }
    }
    
    init(portfolioViewModel: PortfolioViewModel, homeViewModel: HomeViewModel, authViewModel: AuthViewModel) {
        self._analyticsVM = StateObject(wrappedValue: PortfolioAnalyticsViewModel(
            portfolioViewModel: portfolioViewModel,
            homeViewModel: homeViewModel,
            authViewModel: authViewModel
        ))
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.theme.background
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Custom Tab Selector
                    customTabSelector
                    
                    // Content
                    ScrollView {
                        VStack(spacing: 20) {
                            switch selectedTab {
                            case .growth:
                                PortfolioGrowthChartView(analyticsVM: analyticsVM)
                                
                            case .allocation:
                                SectorAllocationChartView(analyticsVM: analyticsVM)
                            }
                            
                            // Additional insights could go here
                            if selectedTab == .growth && !analyticsVM.chartDataPoints.isEmpty {
                                portfolioInsightsView
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Analytics")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        Task {
                            await analyticsVM.refreshData()
                        }
                    }) {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
        }
        .task {
            await analyticsVM.refreshData()
        }
        .refreshable {
            await analyticsVM.refreshData()
        }
    }
    
    @ViewBuilder
    private var customTabSelector: some View {
        HStack(spacing: 0) {
            ForEach(AnalyticsTab.allCases, id: \.self) { tab in
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        selectedTab = tab
                    }
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 16, weight: .medium))
                        
                        Text(tab.rawValue)
                            .font(.system(size: 16, weight: .medium))
                    }
                    .foregroundColor(selectedTab == tab ? .white : Color.theme.accent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(selectedTab == tab ? Color.theme.accent : Color.clear)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
    
    @ViewBuilder
    private var portfolioInsightsView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Portfolio Insights")
                .font(.title2.bold())
                .foregroundColor(.primary)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                InsightCard(
                    title: "Best Day",
                    value: getBestDay(),
                    subtitle: "Highest single day gain",
                    color: .green
                )
                
                InsightCard(
                    title: "Worst Day",
                    value: getWorstDay(),
                    subtitle: "Biggest single day loss",
                    color: .red
                )
                
                InsightCard(
                    title: "Avg Daily Change",
                    value: getAverageDailyChange(),
                    subtitle: "Average daily movement",
                    color: .blue
                )
                
                InsightCard(
                    title: "Volatility",
                    value: getVolatility(),
                    subtitle: "Portfolio volatility",
                    color: .orange
                )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
        )
    }
    
    // MARK: - Helper Methods for Insights
    
    private func getBestDay() -> String {
        guard analyticsVM.chartDataPoints.count > 1 else { return "N/A" }
        
        var bestGain: Double = 0
        for i in 1..<analyticsVM.chartDataPoints.count {
            let dailyChange = analyticsVM.chartDataPoints[i].currentValue - analyticsVM.chartDataPoints[i-1].currentValue
            if dailyChange > bestGain {
                bestGain = dailyChange
            }
        }
        
        return bestGain > 0 ? "+\(bestGain.asCurrencyWith2Decimals())" : "N/A"
    }
    
    private func getWorstDay() -> String {
        guard analyticsVM.chartDataPoints.count > 1 else { return "N/A" }
        
        var worstLoss: Double = 0
        for i in 1..<analyticsVM.chartDataPoints.count {
            let dailyChange = analyticsVM.chartDataPoints[i].currentValue - analyticsVM.chartDataPoints[i-1].currentValue
            if dailyChange < worstLoss {
                worstLoss = dailyChange
            }
        }
        
        return worstLoss < 0 ? worstLoss.asCurrencyWith2Decimals() : "N/A"
    }
    
    private func getAverageDailyChange() -> String {
        guard analyticsVM.chartDataPoints.count > 1 else { return "N/A" }
        
        var totalChange: Double = 0
        for i in 1..<analyticsVM.chartDataPoints.count {
            totalChange += analyticsVM.chartDataPoints[i].currentValue - analyticsVM.chartDataPoints[i-1].currentValue
        }
        
        let avgChange = totalChange / Double(analyticsVM.chartDataPoints.count - 1)
        return avgChange >= 0 ? "+\(avgChange.asCurrencyWith2Decimals())" : avgChange.asCurrencyWith2Decimals()
    }
    
    private func getVolatility() -> String {
        guard analyticsVM.chartDataPoints.count > 1 else { return "N/A" }
        
        var dailyChanges: [Double] = []
        for i in 1..<analyticsVM.chartDataPoints.count {
            let previousValue = analyticsVM.chartDataPoints[i-1].currentValue
            let currentValue = analyticsVM.chartDataPoints[i].currentValue
            if previousValue > 0 {
                let percentChange = ((currentValue - previousValue) / previousValue) * 100
                dailyChanges.append(percentChange)
            }
        }
        
        guard !dailyChanges.isEmpty else { return "N/A" }
        
        let mean = dailyChanges.reduce(0, +) / Double(dailyChanges.count)
        let variance = dailyChanges.reduce(0) { sum, change in
            sum + pow(change - mean, 2)
        } / Double(dailyChanges.count)
        
        let standardDeviation = sqrt(variance)
        return String(format: "%.2f%%", standardDeviation)
    }
}

struct InsightCard: View {
    let title: String
    let value: String
    let subtitle: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.caption.weight(.medium))
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Circle()
                    .fill(color.opacity(0.2))
                    .frame(width: 8, height: 8)
            }
            
            Text(value)
                .font(.title3.bold())
                .foregroundColor(color)
            
            Text(subtitle)
                .font(.caption2)
                .foregroundColor(.secondary)
                .lineLimit(2)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
    }
}

