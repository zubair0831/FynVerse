import SwiftUI

struct EnhancedFynVerseChatView: View {
    @StateObject private var vm: FynVerseContextualChatViewModel
    @State private var showQuickActions = false
    
    init(authViewModel: AuthViewModel, homeViewModel: HomeViewModel, profileViewModel: ProfileViewModel) {
        _vm = StateObject(wrappedValue: FynVerseContextualChatViewModel(
            authViewModel: authViewModel,
            homeViewModel: homeViewModel,
            profileViewModel: profileViewModel
        ))
    }
    
    var body: some View {
        ZStack {
            Color.theme.background
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header with FynVerse branding
                headerView
                
                // Messages area
                if vm.messages.isEmpty {
                    welcomeView
                } else {
                    messagesScrollView
                }
                
                // Quick action chips (when no messages)
                if vm.messages.isEmpty {
                    quickActionChips
                }
                
                Divider()
                    .background(Color.theme.divider)
                    .padding(.horizontal)
                    .padding(.bottom, 6)
                
                // Input area
                inputBar
            }
        }
        .task {
            // Load portfolio data when view appears
            await vm.loadUserPortfolioData()
        }
    }
    
    // MARK: - Header View
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("FynVerse AI")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(Color.theme.primaryText)
                
                Text("Your Personal Financial Assistant")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(Color.theme.secondary)
            }
            
            Spacer()
            
            // Info button
            Button {
                vm.handleQuickQuery(.appFeatures)
            } label: {
                Image(systemName: "info.circle.fill")
                    .font(.system(size: 22))
                    .foregroundColor(Color.theme.accent)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(Color.theme.cardBackground)
        .shadow(color: Color.theme.cardShadow.opacity(0.1), radius: 2, x: 0, y: 1)
    }
    
    // MARK: - Welcome View
    private var welcomeView: some View {
        VStack(spacing: 20) {
            Spacer()
            
            // AI Icon
            ZStack {
                Circle()
                    .fill(Color.theme.cardGradient1)
                    .frame(width: 80, height: 80)
                    .shadow(color: Color.theme.accent.opacity(0.3), radius: 10, x: 0, y: 4)
                
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 40, weight: .medium))
                    .foregroundColor(.white)
            }
            
            Text("Hi! I'm your FynVerse AI Assistant")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(Color.theme.primaryText)
                .multilineTextAlignment(.center)
            
            Text("I have access to your portfolio and can provide personalized insights about your stocks, performance, and investment strategy!")
                .font(.system(size: 15, weight: .regular))
                .foregroundColor(Color.theme.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)
            
            // Show portfolio summary if available
            if vm.totalInvestment > 0 {
                VStack(spacing: 8) {
                    Text("Your Portfolio at a Glance")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color.theme.secondary)
                    
                    HStack(spacing: 20) {
                        VStack {
                            Text("₹\(formatNumber(vm.portfolioValue))")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(Color.theme.primaryText)
                            Text("Value")
                                .font(.system(size: 11))
                                .foregroundColor(Color.theme.secondary)
                        }
                        
                        VStack {
                            Text("\(vm.portfolioStocks.count)")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(Color.theme.primaryText)
                            Text("Holdings")
                                .font(.system(size: 11))
                                .foregroundColor(Color.theme.secondary)
                        }
                        
                        VStack {
                            let percentage = vm.totalInvestment > 0 ? (vm.totalGainLoss / vm.totalInvestment) * 100 : 0
                            Text("\(percentage >= 0 ? "+" : "")\(String(format: "%.1f", percentage))%")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(percentage >= 0 ? .green : .red)
                            Text("Returns")
                                .font(.system(size: 11))
                                .foregroundColor(Color.theme.secondary)
                        }
                    }
                    .padding()
                    .background(Color.theme.cardBackground)
                    .cornerRadius(12)
                }
                .padding(.horizontal, 30)
            }
            
            Spacer()
        }
    }
    
    // MARK: - Messages Scroll View
    private var messagesScrollView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(vm.messages) { msg in
                        MessageBubble(message: msg)
                            .id(msg.id)
                    }
                    
                    // Loading indicator
                    if vm.isLoading {
                        LoadingIndicator()
                            .id("loading")
                    }
                }
                .padding(.top, 10)
                .padding(.bottom, 20)
            }
            .onChange(of: vm.messages.count) { _, _ in
                if let lastMessage = vm.messages.last {
                    withAnimation {
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
            }
            .onChange(of: vm.isLoading) { _, newValue in
                if newValue {
                    withAnimation {
                        proxy.scrollTo("loading", anchor: .bottom)
                    }
                }
            }
        }
    }
    
    // MARK: - Quick Action Chips
    private var quickActionChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                QuickActionChip(
                    icon: "chart.bar.doc.horizontal.fill",
                    text: "Portfolio Analysis",
                    action: { vm.handleQuickQuery(.portfolioAnalysis) }
                )
                
                QuickActionChip(
                    icon: "percent",
                    text: "P/E Ratios",
                    action: { vm.handleQuickQuery(.peRatio) }
                )
                
                QuickActionChip(
                    icon: "shield.lefthalf.filled",
                    text: "Risk Management",
                    action: { vm.handleQuickQuery(.riskManagement) }
                )
                
                QuickActionChip(
                    icon: "sparkles",
                    text: "Features",
                    action: { vm.handleQuickQuery(.appFeatures) }
                )
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
        }
    }
    
    // MARK: - Input Bar
    private var inputBar: some View {
        HStack(spacing: 10) {
            TextField("Ask about your portfolio, stocks, or FynVerse features...", text: $vm.inputText)
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
                .background(Color.theme.cardBackground)
                .cornerRadius(12)
                .foregroundColor(Color.theme.primaryText)
                .font(.system(size: 15))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.theme.divider, lineWidth: 1)
                )
                .disabled(vm.isLoading)
            
            Button {
                vm.sendMessage()
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 36, weight: .medium))
                    .foregroundColor(vm.inputText.trimmingCharacters(in: .whitespaces).isEmpty || vm.isLoading ? Color.theme.secondary : Color.theme.accent)
            }
            .disabled(vm.inputText.trimmingCharacters(in: .whitespaces).isEmpty || vm.isLoading)
            .animation(.easeInOut(duration: 0.2), value: vm.inputText.isEmpty)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(Color.theme.background.opacity(0.95))
    }
    
    // MARK: - Helper Functions
    private func formatNumber(_ value: Double) -> String {
        if value >= 10000000 {
            return String(format: "%.2fCr", value / 10000000)
        } else if value >= 100000 {
            return String(format: "%.2fL", value / 100000)
        } else if value >= 1000 {
            return String(format: "%.2fK", value / 1000)
        } else {
            return String(format: "%.2f", value)
        }
    }
}

// MARK: - Message Bubble Component
struct MessageBubble: View {
    let message: ChatMessage
    
    var body: some View {
        HStack {
            if message.isUser { Spacer() }
            
            VStack(alignment: message.isUser ? .trailing : .leading, spacing: 4) {
                Text(message.text)
                    .font(.system(size: 15, weight: .regular))
                    .padding(.vertical, 12)
                    .padding(.horizontal, 16)
                    .background(
                        Group {
                            if message.isUser {
                                 Color.theme.cardGradient2
                            } else {
                                Color.theme.cardBackground
                            }
                        }
                    )
                    .foregroundColor(message.isUser ? .white : Color.theme.primaryText)
                    .cornerRadius(16)
                    .shadow(color: Color.theme.cardShadow.opacity(0.15), radius: 4, x: 0, y: 2)
            }
            .frame(maxWidth: UIScreen.main.bounds.width * 0.75, alignment: message.isUser ? .trailing : .leading)
            
            if !message.isUser { Spacer() }
        }
        .padding(.horizontal)
        .transition(.move(edge: message.isUser ? .trailing : .leading).combined(with: .opacity))
    }
}

// MARK: - Loading Indicator Component
struct LoadingIndicator: View {
    @State private var animationPhase: Int = 0
    
    var body: some View {
        HStack(spacing: 0) {
            HStack(spacing: 8) {
                ForEach(0..<3) { index in
                    Circle()
                        .fill(Color.theme.accent)
                        .frame(width: 8, height: 8)
                        .scaleEffect(animationPhase == index ? 1.2 : 0.8)
                        .opacity(animationPhase == index ? 1.0 : 0.5)
                        .animation(
                            .easeInOut(duration: 0.6)
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.2),
                            value: animationPhase
                        )
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 20)
            .background(Color.theme.cardBackground)
            .cornerRadius(16)
            .shadow(color: Color.theme.cardShadow.opacity(0.15), radius: 4, x: 0, y: 2)
            
            Spacer()
        }
        .padding(.horizontal)
        .onAppear {
            Timer.scheduledTimer(withTimeInterval: 0.6, repeats: true) { _ in
                animationPhase = (animationPhase + 1) % 3
            }
        }
    }
}

// MARK: - Quick Action Chip Component
struct QuickActionChip: View {
    let icon: String
    let text: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                
                Text(text)
                    .font(.system(size: 14, weight: .medium))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.theme.cardBackground)
            .foregroundColor(Color.theme.accent)
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.theme.accent.opacity(0.3), lineWidth: 1)
            )
            .shadow(color: Color.theme.cardShadow.opacity(0.1), radius: 3, x: 0, y: 2)
        }
    }
}
