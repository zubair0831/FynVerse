import SwiftUI
import Charts

struct SectorDetailView: View {
    let sector: SectorAllocation
    let sectorColor: Color
    @Environment(\.dismiss) private var dismiss
    @State private var selectedStock: SectorStock? = nil
    
    private let stockColors: [Color] = [
        .blue, .green, .orange, .purple, .pink,
        .yellow, .cyan, .indigo, .mint, .brown,
        .red, .teal, .gray, .black
    ]
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header Section
                    headerSection
                    
                    // Chart Section
                    chartSection
                    
                    // Holdings List Section
                    holdingsSection
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(sectorColor)
                }
            }
        }
    }
    
    @ViewBuilder
    private var headerSection: some View {
        VStack(spacing: 16) {
            // Sector Icon and Title
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(sectorColor.opacity(0.15))
                        .frame(width: 80, height: 80)
                    
                    Image(systemName: sectorIconName)
                        .font(.system(size: 32, weight: .medium))
                        .foregroundColor(sectorColor)
                }
                
                VStack(spacing: 4) {
                    Text(sector.sector)
                        .font(.title.bold())
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.center)
                    
                    Text("Sector Analysis")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            // Key Metrics Cards
            HStack(spacing: 16) {
                MetricCard(
                    title: "Total Value",
                    value: sector.value.asCurrencyWith2Decimals(),
                    color: sectorColor,
                    icon: "dollarsign.circle.fill"
                )
                
                MetricCard(
                    title: "Portfolio %",
                    value: "\(String(format: "%.1f%%", sector.percentage))",
                    color: sectorColor,
                    icon: "chart.pie.fill"
                )
                
                MetricCard(
                    title: "Holdings",
                    value: "\(sector.stockCount)",
                    color: sectorColor,
                    icon: "building.2.fill"
                )
            }
        }
        .padding(.top, 20)
    }
    
    @ViewBuilder
    private var chartSection: some View {
        VStack(spacing: 20) {
            HStack {
                Text("Holdings Distribution")
                    .font(.title2.bold())
                    .foregroundColor(.primary)
                
                Spacer()
                
                if let selectedStock = selectedStock {
                    Button("Clear Selection") {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            self.selectedStock = nil
                        }
                    }
                    .font(.caption.weight(.medium))
                    .foregroundColor(sectorColor)
                }
            }
            
            // Pie Chart
            Chart(sector.stocks.enumerated().map { $0 }, id: \.element.symbol) { index, stock in
                SectorMark(
                    angle: .value("Value", stock.percentage),
                    innerRadius: .ratio(0.45),
                    angularInset: 2
                )
                .foregroundStyle(stockColors[index % stockColors.count].gradient)
                .opacity(selectedStock == nil ? 1.0 : (selectedStock?.symbol == stock.symbol ? 1.0 : 0.3))
            }
            .frame(height: 250)
            .chartLegend(.hidden)
            .chartBackground { chartProxy in
                GeometryReader { geometry in
                    if let anchor = chartProxy.plotFrame {
                        let frame = geometry[anchor]
                        VStack(spacing: 8) {
                            if let selectedStock = selectedStock {
                                Text(selectedStock.symbol)
                                    .font(.title3.bold())
                                    .foregroundColor(.primary)
                                
                                Text("\(String(format: "%.1f%%", selectedStock.percentage))")
                                    .font(.largeTitle.bold())
                                    .foregroundColor(stockColors[getStockColorIndex(for: selectedStock)])
                                
                                Text(selectedStock.value.asCurrencyWith2Decimals())
                                    .font(.caption.weight(.medium))
                                    .foregroundColor(.secondary)
                            } else {
                                Image(systemName: sectorIconName)
                                    .font(.title2)
                                    .foregroundColor(sectorColor.opacity(0.7))
                                
                                Text(sector.sector)
                                    .font(.title3.bold())
                                    .foregroundColor(.primary)
                                    .multilineTextAlignment(.center)
                                
                                Text("Tap holdings to explore")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .position(x: frame.midX, y: frame.midY)
                    }
                }
            }
            
            // Selected Stock Details
            if let selectedStock = selectedStock {
                selectedStockDetailsView(for: selectedStock)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
        )
    }
    
    @ViewBuilder
    private var holdingsSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("Individual Holdings")
                    .font(.title2.bold())
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text("\(sector.stocks.count) stock\(sector.stocks.count == 1 ? "" : "s")")
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
                ForEach(Array(sector.stocks.sorted { $0.value > $1.value }.enumerated()), id: \.element.symbol) { index, stock in
                    stockRow(for: stock, colorIndex: index)
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
        )
    }
    
    @ViewBuilder
    private func selectedStockDetailsView(for stock: SectorStock) -> some View {
        VStack(spacing: 16) {
            HStack {
                Text("Stock Details")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.secondary)
                
                Spacer()
            }
            
            HStack(spacing: 16) {
                StockStatCard(
                    title: "Value",
                    value: stock.value.asCurrencyWith2Decimals(),
                    color: stockColors[getStockColorIndex(for: stock)]
                )
                
                StockStatCard(
                    title: "Sector %",
                    value: "\(String(format: "%.1f%%", stock.percentage))",
                    color: stockColors[getStockColorIndex(for: stock)]
                )
                
                StockStatCard(
                    title: "Symbol",
                    value: stock.symbol,
                    color: stockColors[getStockColorIndex(for: stock)]
                )
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(stockColors[getStockColorIndex(for: stock)].opacity(0.05))
                .stroke(stockColors[getStockColorIndex(for: stock)].opacity(0.2), lineWidth: 1)
        )
    }
    
    @ViewBuilder
    private func stockRow(for stock: SectorStock, colorIndex: Int) -> some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.3)) {
                if selectedStock?.symbol == stock.symbol {
                    selectedStock = nil
                } else {
                    selectedStock = stock
                }
            }
        }) {
            HStack(spacing: 16) {
                // Stock Color Indicator
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(stockColors[colorIndex % stockColors.count].opacity(0.15))
                        .frame(width: 44, height: 44)
                    
                    Text(String(stock.symbol.prefix(2)))
                        .font(.caption.bold())
                        .foregroundColor(stockColors[colorIndex % stockColors.count])
                }
                
                // Stock Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(stock.symbol)
                        .font(.subheadline.bold())
                        .foregroundColor(.primary)
                    
                    Text(stock.name)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                
                Spacer()
                
                // Value and Percentage
                VStack(alignment: .trailing, spacing: 6) {
                    Text(stock.value.asCurrencyWith2Decimals())
                        .font(.subheadline.bold())
                        .foregroundColor(.primary)
                    
                    HStack(spacing: 8) {
                        Text("\(String(format: "%.1f%%", stock.percentage))")
                            .font(.caption.weight(.medium))
                            .foregroundColor(stockColors[colorIndex % stockColors.count])
                        
                        // Progress Bar
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Color(.systemGray5))
                                    .frame(height: 4)
                                
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(stockColors[colorIndex % stockColors.count])
                                    .frame(width: geometry.size.width * (stock.percentage / 100), height: 4)
                            }
                        }
                        .frame(width: 50, height: 4)
                    }
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(selectedStock?.symbol == stock.symbol ?
                          stockColors[colorIndex % stockColors.count].opacity(0.08) :
                          Color(.systemGray6).opacity(0.3))
                    .stroke(
                        selectedStock?.symbol == stock.symbol ?
                        stockColors[colorIndex % stockColors.count].opacity(0.3) :
                        Color.clear,
                        lineWidth: 1.5
                    )
            )
        }
        .buttonStyle(.plain)
        .scaleEffect(selectedStock?.symbol == stock.symbol ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: selectedStock?.symbol)
    }
    
    private func getStockColorIndex(for stock: SectorStock) -> Int {
        return sector.stocks.firstIndex(where: { $0.symbol == stock.symbol }) ?? 0
    }
    
    private var sectorIconName: String {
        switch sector.sector.lowercased() {
        case let s where s.contains("tech"):
            return "laptopcomputer"
        case let s where s.contains("health"):
            return "cross.case.fill"
        case let s where s.contains("finance"):
            return "banknote.fill"
        case let s where s.contains("energy"):
            return "bolt.fill"
        case let s where s.contains("consumer"):
            return "cart.fill"
        case let s where s.contains("industrial"):
            return "gearshape.fill"
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
}

// MARK: - Helper Views

struct MetricCard: View {
    let title: String
    let value: String
    let color: Color
    let icon: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
            
            Text(value)
                .font(.subheadline.bold())
                .foregroundColor(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            
            Text(title)
                .font(.caption2.weight(.medium))
                .foregroundColor(.secondary)
                .textCase(.uppercase)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: color.opacity(0.1), radius: 4, x: 0, y: 2)
        )
    }
}

struct StockStatCard: View {
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
