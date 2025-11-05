import SwiftUI

struct ShareholdingChartView: View {
    let shareholding: ShareholdingPattern
    
    private var shareholdingData: [(String, Double, Color)] {
        var data: [(String, Double, Color)] = []
        
        // Extract percentage values - convert decimal to percentage for FII/institutional
        let promoterPercent = extractPercentage(from: shareholding.promoterHoldingPercent, isDecimal: true)
        let fiiPercent = extractPercentage(from: shareholding.fiiHoldingPercent, isDecimal: true)
        
        // Calculate retail as remainder (100 - promoter - fii/dii)
        let totalKnown = promoterPercent + fiiPercent
        let retailPercent = max(0, 100 - totalKnown)
        
        if promoterPercent > 0 {
            data.append(("Promoter", promoterPercent, .blue))
        }
        if fiiPercent > 0 {
            data.append(("FII/DII", fiiPercent, .green))
        }
        if retailPercent > 0 {
            data.append(("Retail", retailPercent, .orange))
        }
        
        // If we still don't have data, fallback to the general institutional data
        if data.isEmpty {
            let insiderPercent = extractPercentage(from: shareholding.heldPercentInsiders, isDecimal: true)
            let institutionalPercent = extractPercentage(from: shareholding.heldPercentInstitutions, isDecimal: true)
            
            if insiderPercent > 0 {
                data.append(("Insiders", insiderPercent, .blue))
            }
            if institutionalPercent > 0 {
                data.append(("Institutions", institutionalPercent, .green))
            }
            
            // Calculate remaining as others
            let totalKnownFallback = insiderPercent + institutionalPercent
            if totalKnownFallback < 100 {
                data.append(("Others", 100 - totalKnownFallback, .gray))
            }
        }
        
        return data
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Shareholding Pattern")
                .font(.headline)
                .foregroundColor(Color.theme.accent)
            
            if !shareholdingData.isEmpty {
                // Horizontal bar chart
                VStack(spacing: 8) {
                    HStack(spacing: 0) {
                        ForEach(Array(shareholdingData.enumerated()), id: \.offset) { index, item in
                            Rectangle()
                                .fill(item.2)
                                .frame(width: CGFloat(item.1) * 2.5) // Scale factor for visibility
                                .frame(height: 20)
                        }
                        Spacer()
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    
                    // Legend
                    HStack {
                        ForEach(Array(shareholdingData.enumerated()), id: \.offset) { index, item in
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(item.2)
                                    .frame(width: 8, height: 8)
                                Text("\(item.0): \(String(format: "%.1f", item.1))%")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            if index < shareholdingData.count - 1 {
                                Spacer()
                            }
                        }
                    }
                }
                
                // Additional shareholding details
                if let sharesOutstanding = shareholding.sharesOutstanding, sharesOutstanding != "N/A" {
                    HStack {
                        Text("Total Shares:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(formatShares(sharesOutstanding))
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                }
                
                if let floatShares = shareholding.floatShares, floatShares != "N/A" {
                    HStack {
                        Text("Float Shares:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(formatShares(floatShares))
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                }
            } else {
                Text("Shareholding data not available")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .italic()
            }
        }
        .padding()
        .background(Color.theme.secondary.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private func extractPercentage(from string: String?, isDecimal: Bool = false) -> Double {
        guard let string = string, string != "N/A" else { return 0 }
        
        // Remove % symbol and convert to double
        let cleanedString = string.replacingOccurrences(of: "%", with: "")
        guard let value = Double(cleanedString) else { return 0 }
        
        // If the value is in decimal format (0-1), convert to percentage
        if isDecimal {
            return value * 100
        }
        
        return value
    }
    
    private func formatShares(_ shares: String) -> String {
        guard let sharesValue = Double(shares) else { return shares }
        
        let crore: Double = 10_000_000
        if sharesValue >= crore {
            return String(format: "%.2f Cr", sharesValue / crore)
        } else if sharesValue >= 1_000_000 {
            return String(format: "%.2f M", sharesValue / 1_000_000)
        } else if sharesValue >= 1_000 {
            return String(format: "%.2f K", sharesValue / 1_000)
        } else {
            return String(format: "%.0f", sharesValue)
        }
    }
}
