import SwiftUI

struct PortfolioSummaryView: View {
    @EnvironmentObject var vm: HomeViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 24) { // Increased spacing for a cleaner look
            // Current Value & Total Gain/Loss (Combined for better visual hierarchy)
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Current Value")
                        .font(.subheadline)
                        .foregroundColor(Color.theme.secondary)
                    
                    Text(vm.portfolioValue.asCurrencyWith2Decimals())
                        .font(.largeTitle.bold()) // Made the main value more prominent
                        .foregroundColor(Color.theme.accent)
                }

            }

            Divider()
                .background(Color(.separator)) // Using system separator color for better integration

            // Total Investment
            HStack{
                VStack(alignment: .leading, spacing: 4) {
                    Text("Total Investment")
                        .font(.caption)
                        .foregroundColor(Color.theme.secondary)
                    
                    Text(vm.totalInvestment.asCurrencyWith2Decimals())
                        .font(.subheadline.bold())
                        .foregroundColor(Color.theme.accent)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    HStack(alignment: .firstTextBaseline) { // Use HStack with alignment for better layout
                        Text("Gain/Loss:")
                            .font(.caption)
                            .foregroundStyle(Color.theme.secondary)
                            .padding()
                        // Display the gain/loss and percentage in a single, well-formatted Text view
                        if vm.totalInvestment != 0 {
                            let pnlPercentage = (vm.totalGainLoss / vm.totalInvestment) * 100
                            let gainLossText = vm.totalGainLoss.asCurrencyWith2Decimals()
                            let pnlString = String(format: "%.2f%%", pnlPercentage)
                            VStack{
                                Text("\(gainLossText)")
                                Text( "(\(pnlString))")
                            }
                            .font(.headline.bold())
                            .foregroundColor(vm.totalGainLoss >= 0 ? Color.theme.green : Color.theme.red)

                        } else {
                            Text(vm.totalGainLoss.asCurrencyWith2Decimals())
                                .font(.headline.bold())
                                .foregroundColor(vm.totalGainLoss >= 0 ? Color.theme.green : Color.theme.red)
                        }
                    }
                }
            }
        }
        .padding(20) // Increased padding
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.theme.cardBackground)
                .shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)
        )

        .cornerRadius(20) // More rounded corners
        .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5) // Softer, more pronounced shadow
        .padding(.horizontal)
    }
}
