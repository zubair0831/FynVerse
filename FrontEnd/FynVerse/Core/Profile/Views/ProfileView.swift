import SwiftUI

struct ProfileView: View {
    @ObservedObject var transactionVM: TransactionViewModel
    @ObservedObject var homevm: HomeViewModel
    @StateObject var vm = ProfileViewModel(
        authVM: AuthViewModel(),
        trxnVM: TransactionViewModel()
    )
    @StateObject private var fundsManager = FundsManager.shared
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.theme.background.ignoresSafeArea()
                
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 28) {
                        
                        // MARK: Header
                        HStack(spacing: 8) {
                            Image(systemName: "person.circle.fill")
                                .font(.largeTitle)
                                .foregroundStyle(Color.theme.accent)
                            
                            Text("My Profile")
                                .font(.largeTitle.bold())
                                .foregroundColor(Color.theme.accent)
                        }
                        .padding(.top, 16)
                        
                        // MARK: Profile Card
                        profileCard
                        
                        // MARK: Funds View
                        FundsView()
                        
                        // MARK: Navigation Links
                        navigationLinksSection
                        
                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal)
                }
                .task {
                    await vm.loadProfileData()
                    await transactionVM.fetchTransactions()
                    fundsManager.calculateAvailableFunds(from: transactionVM.transactions)
                }
                .alert("Enter your full name", isPresented: $vm.isAskingName) {
                    TextField("Full Name", text: $vm.tempName)
                    Button("Save") {
                        Task { await vm.saveName() }
                    }
                }
                .onChange(of: transactionVM.transactions) { oldValue, newValue in
                    fundsManager.calculateAvailableFunds(from: newValue)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    // MARK: - Profile Card
    private var profileCard: some View {
        HStack(spacing: 16) {
            Group {
                if let image = vm.profileImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    ZStack {
                        Circle()
                            .fill(Color.theme.accent.opacity(0.15))
                        
                        Image(systemName: "person.fill")
                            .resizable()
                            .scaledToFit()
                            .foregroundColor(Color.theme.accent)
                            .padding(20)
                    }
                }
            }
            .frame(width: 70, height: 70)
            .clipShape(Circle())
            .overlay(
                Circle()
                    .stroke(Color.theme.accent.opacity(0.2), lineWidth: 2)
            )
            
            VStack(alignment: .leading, spacing: 6) {
                Text(vm.userFullName)
                    .font(.title2.weight(.semibold))
                    .foregroundColor(Color.theme.accent)
                
                HStack(spacing: 6) {
                    Image(systemName: "calendar")
                        .font(.caption)
                        .foregroundStyle(Color.theme.secondary)
                    
                    Text(vm.investingSince)
                        .font(.subheadline)
                        .foregroundColor(Color.theme.secondary)
                }
            }
            Spacer()
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.theme.cardBackground)
                .shadow(color: Color.theme.cardShadow, radius: 8, x: 0, y: 2)
        )
    }
    
    // MARK: - Navigation Links Section
    private var navigationLinksSection: some View {
        VStack(spacing: 12) {
            NavigationLink {
                SettingsView()
            } label: {
                ProfileNavCell(
                    icon: "gearshape.fill",
                    title: "Settings",
                    color: Color.theme.info
                )
            }
            
            NavigationLink {
                TransactionView()
            } label: {
                ProfileNavCell(
                    icon: "arrow.left.arrow.right.circle.fill",
                    title: "Transactions",
                    color: Color.theme.accent
                )
            }
            
            NavigationLink {
                PnLReport(vm: transactionVM)
            } label: {
                ProfileNavCell(
                    icon: "chart.line.uptrend.xyaxis",
                    title: "Profit/Loss Report",
                    color: fundsManager.fundsColor
                )
            }
            
            NavigationLink {
                EnhancedFynVerseChatView(
                    authViewModel: vm.authVM,
                    homeViewModel: homevm,
                    profileViewModel: vm
                )
            } label: {
                ProfileNavCell(
                    icon: "questionmark.circle.fill",
                    title: "AI Assistant",
                    color: Color.theme.warning
                )
            }

        }
    }
}

// MARK: - Updated FundsView
struct FundsView: View {
    @StateObject private var fundsManager = FundsManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(fundsManager.fundsColor.opacity(0.15))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: "indianrupeesign.circle.fill")
                        .foregroundColor(fundsManager.fundsColor)
                        .font(.title2)
                }
                
                Text("Available Funds")
                    .font(.headline)
                    .foregroundColor(Color.theme.accent)
                
                Spacer()
            }
            
            // Amount Display
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("₹")
                    .font(.title.bold())
                    .foregroundColor(fundsManager.fundsColor)
                
                Text(formatCurrency(fundsManager.availableFunds))
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(fundsManager.fundsColor)
                
                Spacer()
            }
            
            // Stats Row
            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Initial")
                        .font(.caption2)
                        .foregroundColor(Color.theme.secondary)
                    
                    Text("₹10,00,000")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(Color.theme.accent)
                }
                
                Divider()
                    .frame(height: 30)
                    .background(Color.theme.divider)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Used")
                        .font(.caption2)
                        .foregroundColor(Color.theme.secondary)
                    
                    let usedAmount = fundsManager.getUsedAmount()
                    Text("₹\(formatCurrency(usedAmount))")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(Color.theme.red)
                }
                
                Spacer()
            }
            
            // Progress Bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.theme.divider.opacity(0.3))
                        .frame(height: 10)
                    
                    RoundedRectangle(cornerRadius: 8)
                        .fill(
                            LinearGradient(
                                colors: [
                                    fundsManager.fundsColor,
                                    fundsManager.fundsColor.opacity(0.7)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(
                            width: max(0, geometry.size.width * (fundsManager.availableFunds / 1_000_000)),
                            height: 10
                        )
                        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: fundsManager.availableFunds)
                }
            }
            .frame(height: 10)
            
            // Percentage Display
            HStack {
                Text("\(Int((fundsManager.availableFunds / 1_000_000) * 100))% Available")
                    .font(.caption)
                    .foregroundColor(Color.theme.secondary)
                
                Spacer()
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.theme.cardBackground)
                .shadow(color: Color.theme.cardShadow, radius: 8, x: 0, y: 2)
        )
    }
    
    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 0
        formatter.locale = Locale(identifier: "en_IN")
        
        return formatter.string(from: NSNumber(value: amount)) ?? "0"
    }
}

// MARK: - ProfileNavCell (Updated)
struct ProfileNavCell: View {
    let icon: String
    let title: String
    var color: Color = Color.theme.accent
    
    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 40, height: 40)
                
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(color)
            }
            
            Text(title)
                .font(.headline)
                .foregroundColor(Color.theme.accent)
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Color.theme.secondary.opacity(0.5))
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.theme.cardBackground)
                .shadow(color: Color.theme.cardShadow, radius: 4, x: 0, y: 2)
        )
    }
}
