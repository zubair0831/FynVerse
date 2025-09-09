import SwiftUI
import Charts

struct SectorAllocationChartView: View {
    @ObservedObject var analyticsVM: PortfolioAnalyticsViewModel
    @State private var selectedSector: SectorAllocation? = nil
    @State private var showingSectorDetail = false
    @State private var sectorForDetail: SectorAllocation? = nil
    @State private var lastTapTime: Date = Date()
    @State private var lastTappedSector: String? = nil

    private let colors: [Color] = [
        .blue, .green, .orange, .purple, .pink,
        .yellow, .cyan, .indigo, .mint, .brown,
        .red, .teal, .gray
    ]
    
    var body: some View {
        VStack(spacing: 24) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Sector Allocation")
                        .font(.title2.bold())
                        .foregroundColor(.primary)
                    
                    Text("Portfolio diversification breakdown")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if analyticsVM.isLoadingSectors {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            
            if analyticsVM.sectorAllocations.isEmpty && !analyticsVM.isLoadingSectors {
                emptyStateView
            } else {
                VStack(spacing: 24) {
                    // Pie Chart Section
                    VStack(spacing: 16) {
                        if analyticsVM.isLoadingSectors {
                            ProgressView("Loading sectors...")
                                .frame(width: 280, height: 280)
                        } else {
                            pieChart
                                .frame(width: 280, height: 280)
                        }
                        
                        // Chart Summary
                        chartSummaryView
                    }
                    
                    // Sectors List Section
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("Sector Breakdown")
                                .font(.headline.weight(.semibold))
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            Text("\(analyticsVM.sectorAllocations.count) sectors")
                                .font(.caption.weight(.medium))
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 4)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color(.systemGray6))
                                )
                        }
                        
                        LazyVStack(spacing: 12) {
                            ForEach(Array(analyticsVM.sectorAllocations.enumerated()), id: \.element.id) { index, sector in
                                enhancedSectorRow(for: sector, colorIndex: index)
                            }
                        }
                    }
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.08), radius: 10, x: 0, y: 4)
        )
        .onAppear {
            Task {
                await analyticsVM.calculateSectorAllocations()
            }
        }
        .sheet(isPresented: $showingSectorDetail) {
            if let sector = sectorForDetail {
                SectorDetailView(
                    sector: sector,
                    sectorColor: colors[getColorIndex(for: sector)]
                )
            }
        }
    }
    
    @ViewBuilder
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color(.systemGray6))
                    .frame(width: 100, height: 100)
                
                Image(systemName: "chart.pie")
                    .font(.system(size: 40, weight: .light))
                    .foregroundColor(.gray)
            }
            
            VStack(spacing: 8) {
                Text("No sector data available")
                    .font(.title3.weight(.semibold))
                    .foregroundColor(.primary)
                
                Text("Add stocks to your portfolio to see\nsector diversification breakdown")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
        }
        .frame(height: 250)
        .frame(maxWidth: .infinity)
    }
    
    @ViewBuilder
    private var pieChart: some View {
        Chart(analyticsVM.sectorAllocations.enumerated().map { $0 }, id: \.element.id) { index, sector in
            SectorMark(
                angle: .value("Value", sector.percentage),
                innerRadius: .ratio(0.5),
                angularInset: 3
            )
            .foregroundStyle(colors[index % colors.count].gradient)
            .opacity(selectedSector == nil ? 1.0 : (selectedSector?.id == sector.id ? 1.0 : 0.4))
        }
        .chartLegend(.hidden)
        .chartBackground { chartProxy in
            GeometryReader { geometry in
                if let anchor = chartProxy.plotFrame {
                    let frame = geometry[anchor]
                    VStack(spacing: 8) {
                        if let selectedSector = selectedSector {
                            Text(selectedSector.sector)
                                .font(.title3.bold())
                                .foregroundColor(.primary)
                                .multilineTextAlignment(.center)
                            
                            Text("\(String(format: "%.1f%%", selectedSector.percentage))")
                                .font(.largeTitle.bold())
                                .foregroundColor(colors[getColorIndex(for: selectedSector)])
                            
                            Text(selectedSector.value.asCurrencyWith2Decimals())
                                .font(.caption.weight(.medium))
                                .foregroundColor(.secondary)
                            
                            // View Details Button
                            Button(action: {
                                sectorForDetail = selectedSector
                                showingSectorDetail = true
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "arrow.up.right.square")
                                        .font(.caption2)
                                    Text("View Details")
                                        .font(.caption2.weight(.medium))
                                }
                                .foregroundColor(colors[getColorIndex(for: selectedSector)])
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(colors[getColorIndex(for: selectedSector)].opacity(0.1))
                                )
                            }
                            .padding(.top, 4)
                        } else {
                            Image(systemName: "chart.pie.fill")
                                .font(.title2)
                                .foregroundColor(.secondary.opacity(0.6))
                            
                            Text("Portfolio")
                                .font(.title3.bold())
                                .foregroundColor(.primary)
                            
                            Text("Tap sectors to explore")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .position(x: frame.midX, y: frame.midY)
                }
            }
        }
    }
    
    @ViewBuilder
    private var chartSummaryView: some View {
        if let sector = selectedSector {
            VStack(spacing: 12) {
                HStack {
                    Text("Selected Sector Details")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Button("Clear Selection") {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedSector = nil
                        }
                    }
                    .font(.caption.weight(.medium))
                    .foregroundColor(colors[getColorIndex(for: sector)])
                }
                
                HStack(spacing: 20) {
                    StatCard(
                        title: "Value",
                        value: sector.value.asCurrencyWith2Decimals(),
                        color: colors[getColorIndex(for: sector)]
                    )
                    
                    StatCard(
                        title: "Percentage",
                        value: "\(String(format: "%.1f%%", sector.percentage))",
                        color: colors[getColorIndex(for: sector)]
                    )
                    
                    StatCard(
                        title: "Holdings",
                        value: "\(sector.stockCount) stock\(sector.stockCount == 1 ? "" : "s")",
                        color: colors[getColorIndex(for: sector)]
                    )
                }
                
                // View Details Button
                Button(action: {
                    sectorForDetail = sector
                    showingSectorDetail = true
                }) {
                    HStack {
                        Image(systemName: "arrow.up.right.square.fill")
                            .font(.subheadline)
                        
                        Text("View Individual Holdings")
                            .font(.subheadline.weight(.medium))
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.caption)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(colors[getColorIndex(for: sector)])
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(colors[getColorIndex(for: sector)].opacity(0.05))
                    .stroke(colors[getColorIndex(for: sector)].opacity(0.2), lineWidth: 1)
            )
        }
    }
    
    @ViewBuilder
    private func enhancedSectorRow(for sector: SectorAllocation, colorIndex: Int) -> some View {
        Button(action: {
            handleSectorTap(sector: sector)
        }) {
            HStack(spacing: 16) {
                // Color indicator
                ZStack {
                    Circle()
                        .fill(colors[colorIndex % colors.count].opacity(0.2))
                        .frame(width: 40, height: 40)
                    
                    Circle()
                        .fill(colors[colorIndex % colors.count])
                        .frame(width: 20, height: 20)
                }
                
                // Sector info
                VStack(alignment: .leading, spacing: 4) {
                    Text(sector.sector)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.primary)
                    
                    Text("\(sector.stockCount) holding\(sector.stockCount == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Value and percentage
                VStack(alignment: .trailing, spacing: 4) {
                    Text(sector.value.asCurrencyWith2Decimals())
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.primary)
                    
                    HStack(spacing: 4) {
                        Text("\(String(format: "%.1f%%", sector.percentage))")
                            .font(.caption.weight(.medium))
                            .foregroundColor(colors[colorIndex % colors.count])
                        
                        // Progress bar
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Color(.systemGray5))
                                    .frame(height: 4)
                                
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(colors[colorIndex % colors.count])
                                    .frame(width: geometry.size.width * (sector.percentage / 100), height: 4)
                            }
                        }
                        .frame(width: 60, height: 4)
                    }
                }
                
                // Detail arrow for selected sector
                if selectedSector?.id == sector.id {
                    Image(systemName: "arrow.up.right.square")
                        .font(.subheadline)
                        .foregroundColor(colors[colorIndex % colors.count])
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(selectedSector?.id == sector.id ? colors[colorIndex % colors.count].opacity(0.08) : Color(.systemGray6).opacity(0.3))
                    .stroke(
                        selectedSector?.id == sector.id ? colors[colorIndex % colors.count].opacity(0.3) : Color.clear,
                        lineWidth: 1.5
                    )
            )
        }
        .buttonStyle(.plain)
        .scaleEffect(selectedSector?.id == sector.id ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: selectedSector?.id)
    }
    
    private func handleSectorTap(sector: SectorAllocation) {
        let currentTime = Date()
        let timeSinceLastTap = currentTime.timeIntervalSince(lastTapTime)
        
        // Check for double tap (within 0.5 seconds on same sector)
        if timeSinceLastTap < 0.5 && lastTappedSector == sector.sector {
            // Double tap detected - show detail view
            sectorForDetail = sector
            showingSectorDetail = true
        } else {
            // Single tap - select/deselect sector
            withAnimation(.easeInOut(duration: 0.3)) {
                if selectedSector?.id == sector.id {
                    selectedSector = nil
                } else {
                    selectedSector = sector
                }
            }
        }
        
        lastTapTime = currentTime
        lastTappedSector = sector.sector
    }
    
    private func getColorIndex(for sector: SectorAllocation) -> Int {
        return analyticsVM.sectorAllocations.firstIndex(where: { $0.id == sector.id }) ?? 0
    }
}

// MARK: - Helper Views

struct StatCard: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 6) {
            Text(title)
                .font(.caption2.weight(.medium))
                .foregroundColor(.secondary)
                .textCase(.uppercase)
            
            Text(value)
                .font(.subheadline.bold())
                .foregroundColor(color)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.systemBackground))
        )
    }
}
