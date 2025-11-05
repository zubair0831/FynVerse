import SwiftUI
import Charts

struct SectorAllocationChartView: View {
    @ObservedObject var analyticsVM: PortfolioAnalyticsViewModel
    @State private var selectedSector: SectorAllocation? = nil
    @State private var sectorForDetail: SectorAllocation? = nil
    @ObservedObject var authViewModel: AuthViewModel
    @EnvironmentObject var homeVM: HomeViewModel
    
    private let colors: [Color] = [
        .blue, .green, .orange, .purple, .pink,
        .yellow, .cyan, .indigo, .mint, .brown,
        .red, .teal
    ]
    
    var body: some View {
        VStack(spacing: 24) {
            headerSection
            
            if analyticsVM.sectorAllocations.isEmpty && !analyticsVM.isLoadingSectors {
                emptyStateView
            } else {
                VStack(spacing: 24) {
                    pieChartSection
                    
                    if let sector = selectedSector {
                        selectedSectorDetails(for: sector)
                    }
                    
                    sectorsListSection
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.theme.cardBackground)
                .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 4)
        )
        .onAppear {
            Task {
                await analyticsVM.calculateSectorAllocations()
            }
        }
        .sheet(item: $sectorForDetail) { sector in
            SectorDetailView(
                sector: sector,
                sectorColor: colors[getColorIndex(for: sector)]
            )
            .environmentObject(homeVM)
            .environmentObject(authViewModel)
        }
    }
    
    @ViewBuilder
    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                Text("Sector Allocation")
                    .font(.title3.bold())
                    .foregroundColor(.primary)
                
                Text("Portfolio diversification breakdown")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if analyticsVM.isLoadingSectors {
                ProgressView()
                    .scaleEffect(0.9)
            }
        }
    }
    
    @ViewBuilder
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color(.systemGray5))
                    .frame(width: 100, height: 100)
                
                Image(systemName: "chart.pie.fill")
                    .font(.system(size: 40, weight: .light))
                    .foregroundColor(.gray)
            }
            
            VStack(spacing: 8) {
                Text("No Sector Data Available")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text("Add stocks to your portfolio to see\nsector diversification breakdown")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
        }
        .frame(height: 280)
        .frame(maxWidth: .infinity)
    }
    
    @ViewBuilder
    private var pieChartSection: some View {
        VStack(spacing: 16) {
            if analyticsVM.isLoadingSectors {
                ProgressView("Loading sectors...")
                    .frame(width: 280, height: 280)
            } else {
                Chart(analyticsVM.sectorAllocations.enumerated().map { $0 }, id: \.element.id) { index, sector in
                    SectorMark(
                        angle: .value("Value", sector.percentage),
                        innerRadius: .ratio(0.55),
                        angularInset: 2.5
                    )
                    .foregroundStyle(colors[index % colors.count].gradient)
                    .opacity(selectedSector == nil ? 1.0 : (selectedSector?.id == sector.id ? 1.0 : 0.35))
                }
                .frame(width: 280, height: 280)
                .chartLegend(.hidden)
                .chartAngleSelection(value: .constant(nil as Double?))
                .chartBackground { chartProxy in
                    GeometryReader { geometry in
                        if let anchor = chartProxy.plotFrame {
                            let frame = geometry[anchor]
                            VStack(spacing: 10) {
                                if let selectedSector = selectedSector {
                                    Image(systemName: getSectorIcon(selectedSector.sector))
                                        .font(.title2)
                                        .foregroundColor(colors[getColorIndex(for: selectedSector)])
                                    
                                    Text(selectedSector.sector)
                                        .font(.headline.bold())
                                        .foregroundColor(.primary)
                                        .multilineTextAlignment(.center)
                                        .lineLimit(2)
                                    
                                    Text("\(String(format: "%.1f%%", selectedSector.percentage))")
                                        .font(.title.bold())
                                        .foregroundColor(colors[getColorIndex(for: selectedSector)])
                                    
                                    Text(fullFormatCurrency(selectedSector.value))
                                        .font(.caption.weight(.medium))
                                        .foregroundColor(.secondary)
                                } else {
                                    Image(systemName: "chart.pie.fill")
                                        .font(.title)
                                        .foregroundColor(.secondary.opacity(0.5))
                                    
                                    Text("Portfolio")
                                        .font(.headline.bold())
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
                .chartOverlay { proxy in
                    GeometryReader { geo in
                        if let anchor = proxy.plotFrame {
                            let frame = geo[anchor]
                            let center = CGPoint(x: frame.midX, y: frame.midY)
                            
                            Rectangle()
                                .fill(.clear)
                                .contentShape(Rectangle())
                                .gesture(
                                    DragGesture(minimumDistance: 0)
                                        .onEnded { value in
                                            let loc = value.location
                                            let dx = loc.x - center.x
                                            let dy = loc.y - center.y
                                            let angle = atan2(dy, dx) * 180 / .pi
                                            let normalizedAngle = angle < 0 ? angle + 360 : angle
                                            
                                            var start: Double = 0
                                            for sector in analyticsVM.sectorAllocations {
                                                let end = start + sector.percentage / 100 * 360
                                                if normalizedAngle >= start && normalizedAngle < end {
                                                    withAnimation(.easeInOut(duration: 0.2)) {
                                                        selectedSector = sector
                                                    }
                                                    break
                                                }
                                                start = end
                                            }
                                        }
                                )
                        }
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private func selectedSectorDetails(for sector: SectorAllocation) -> some View {
        VStack(spacing: 14) {
            HStack {
                Text("Selected Sector")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                
                Spacer()
                
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedSector = nil
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.caption)
                        Text("Clear")
                            .font(.caption.weight(.medium))
                    }
                    .foregroundColor(colors[getColorIndex(for: sector)])
                }
                .buttonStyle(.plain)
            }
            
            HStack(spacing: 12) {
                StatCard(
                    title: "Value",
                    value: fullFormatCurrency(sector.value),
                    color: colors[getColorIndex(for: sector)]
                )
                
                StatCard(
                    title: "Percentage",
                    value: "\(String(format: "%.1f%%", sector.percentage))",
                    color: colors[getColorIndex(for: sector)]
                )
                
                StatCard(
                    title: "Holdings",
                    value: "\(sector.stockCount)",
                    color: colors[getColorIndex(for: sector)]
                )
            }
            
            Button(action: {
                sectorForDetail = sector
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.up.right.square.fill")
                        .font(.subheadline)
                    
                    Text("View Detailed Breakdown")
                        .font(.subheadline.weight(.semibold))
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption.bold())
                }
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(colors[getColorIndex(for: sector)])
                )
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(colors[getColorIndex(for: sector)].opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(colors[getColorIndex(for: sector)].opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    @ViewBuilder
    private var sectorsListSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Sector Breakdown")
                    .font(.headline.weight(.semibold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text("\(analyticsVM.sectorAllocations.count) sectors")
                    .font(.caption.weight(.medium))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        Capsule()
                            .fill(Color(.systemGray6))
                    )
            }
            
            LazyVStack(spacing: 10) {
                ForEach(Array(analyticsVM.sectorAllocations.enumerated()), id: \.element.id) { index, sector in
                    sectorRow(for: sector, colorIndex: index)
                }
            }
        }
    }
    
    @ViewBuilder
    private func sectorRow(for sector: SectorAllocation, colorIndex: Int) -> some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                if selectedSector?.id == sector.id {
                    selectedSector = nil
                } else {
                    selectedSector = sector
                }
            }
        }) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(colors[colorIndex % colors.count].opacity(0.15))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: getSectorIcon(sector.sector))
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(colors[colorIndex % colors.count])
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(sector.sector)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    Text("\(sector.stockCount) holding\(sector.stockCount == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 6) {
                    Text(fullFormatCurrency(sector.value))
                        .font(.subheadline.bold())
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    HStack(spacing: 6) {
                        Text("\(String(format: "%.1f%%", sector.percentage))")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(colors[colorIndex % colors.count])
                        
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Color(.systemGray5))
                                    .frame(height: 4)
                                
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(colors[colorIndex % colors.count])
                                    .frame(
                                        width: geometry.size.width * min(sector.percentage, 100) / 100,
                                        height: 4
                                    )
                            }
                        }
                        .frame(width: 50, height: 4)
                    }
                }
                
                if selectedSector?.id == sector.id {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(colors[colorIndex % colors.count])
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(selectedSector?.id == sector.id ?
                          colors[colorIndex % colors.count].opacity(0.08) :
                          Color(.secondarySystemBackground).opacity(0.3))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                selectedSector?.id == sector.id ?
                                colors[colorIndex % colors.count].opacity(0.4) :
                                Color.clear,
                                lineWidth: 1.5
                            )
                    )
            )
        }
        .buttonStyle(.plain)
    }
    
    private func getColorIndex(for sector: SectorAllocation) -> Int {
        return analyticsVM.sectorAllocations.firstIndex(where: { $0.id == sector.id }) ?? 0
    }
    
    private func getSectorIcon(_ sectorName: String) -> String {
        let sector = sectorName.lowercased()
        switch sector {
        case let s where s.contains("tech"):
            return "cpu.fill"
        case let s where s.contains("health"):
            return "cross.case.fill"
        case let s where s.contains("finance"):
            return "banknote.fill"
        case let s where s.contains("energy"):
            return "bolt.fill"
        case let s where s.contains("consumer"):
            return "cart.fill"
        case let s where s.contains("industrial"):
            return "gearshape.2.fill"
        case let s where s.contains("material"):
            return "cube.box.fill"
        case let s where s.contains("real estate"):
            return "house.fill"
        case let s where s.contains("utility"):
            return "power"
        case let s where s.contains("telecom"):
            return "antenna.radiowaves.left.and.right"
        default:
            return "building.2.fill"
        }
    }
    
    private func fullFormatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "₹"
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 2
        formatter.negativePrefix = "-₹"
        formatter.positivePrefix = "₹"
        return formatter.string(from: NSNumber(value: abs(value))) ?? "₹0.00"
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
                .font(.caption2.weight(.semibold))
                .foregroundColor(.secondary)
                .textCase(.uppercase)
            
            Text(value)
                .font(.subheadline.bold())
                .foregroundColor(color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.secondarySystemBackground).opacity(0.5))
        )
    }
}
