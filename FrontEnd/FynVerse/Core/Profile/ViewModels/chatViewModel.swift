import Foundation
import GoogleGenerativeAI

@MainActor
class FynVerseContextualChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var inputText: String = ""
    @Published var isLoading: Bool = false
    
    // Portfolio data for RAG
    @Published var portfolioStocks: [DBPortfolioStock] = []
    @Published var portfolioHistory: [PortfolioHistoryModel] = []
    @Published var totalInvestment: Double = 0
    @Published var portfolioValue: Double = 0
    @Published var totalGainLoss: Double = 0
    
    // Stock comprehensive data cache
    private var stockComprehensiveCache: [String: StockComprehensiveModel] = [:]
    
    private let apiKey: String? = ProcessInfo.processInfo.environment["GOOGLE_API_KEY"]
    private let portfolioService = PortfolioService()
    private let portfolioHistoryService = PortfolioHistoryService()
    
    // Dependencies
    private let authViewModel: AuthViewModel
    private let homeViewModel: HomeViewModel
    private let profileViewModel: ProfileViewModel
    
    init(authViewModel: AuthViewModel, homeViewModel: HomeViewModel, profileViewModel: ProfileViewModel) {
        self.authViewModel = authViewModel
        self.homeViewModel = homeViewModel
        self.profileViewModel = profileViewModel
    }
    
    // MARK: - Load User Portfolio Data
    func loadUserPortfolioData() async {
        guard let user = authViewModel.user else { return }
        
        do {
            // Fetch current portfolio
            portfolioStocks = try await portfolioService.fetchPortfolioStocks(for: user.userID)
            
            let summary = portfolioService.calculatePortfolioSummary(
                portfolioStocks: portfolioStocks,
                allStocks: homeViewModel.allStocks
            )
            totalInvestment = summary.investment
            portfolioValue = summary.value
            totalGainLoss = summary.gainLoss
            
            // Fetch portfolio history (last 365 days)
            portfolioHistory = try await portfolioHistoryService.fetchPortfolioHistory(
                userID: user.userID,
                days: 365
            )
            
            // Fetch comprehensive data for all portfolio stocks
            await fetchComprehensiveDataForPortfolio()
            
            print("✅ Loaded portfolio data: \(portfolioStocks.count) stocks, \(portfolioHistory.count) history entries")
        } catch {
            print("❌ Failed to load portfolio data:", error.localizedDescription)
        }
    }
    
    // MARK: - Fetch Comprehensive Stock Data
    private func fetchComprehensiveDataForPortfolio() async {
        for stock in portfolioStocks {
            await fetchStockComprehensive(symbol: stock.stockSymbol)
        }
    }
    
    private func fetchStockComprehensive(symbol: String) async {
        // Check cache first
        if stockComprehensiveCache[symbol] != nil {
            return
        }
        
        let urlString = "http://192.168.1.9:8000/stock/\(symbol)/comprehensive"
        guard let url = URL(string: urlString) else { return }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let decoder = JSONDecoder()
            let response = try decoder.decode(StockComprehensiveModel.self, from: data)
            stockComprehensiveCache[symbol] = response
        } catch {
            print("❌ Failed to fetch comprehensive data for \(symbol):", error.localizedDescription)
        }
    }
    
    // MARK: - Helper to get stock comprehensive data
    private func getStockComprehensive(symbol: String) -> StockComprehensiveModel? {
        return stockComprehensiveCache[symbol]
    }
    
    // MARK: - Build Personalized Context
    private func buildPersonalizedContext() -> String {
        var context = """
        ## USER'S PORTFOLIO DATA:
        """
        
        // User info
        if let userName = authViewModel.user?.fullName, !userName.isEmpty {
            context += "\n**User Name:** \(userName)"
        }
        
        if !profileViewModel.investingSince.contains("—") {
            context += "\n**\(profileViewModel.investingSince)**"
        }
        
        // Portfolio summary
        if totalInvestment > 0 {
            let gainLossPercentage = (totalGainLoss / totalInvestment) * 100
            context += """
            
            
            **Portfolio Summary:**
            • Total Investment: ₹\(String(format: "%.2f", totalInvestment))
            • Current Value: ₹\(String(format: "%.2f", portfolioValue))
            • Total Gain/Loss: ₹\(String(format: "%.2f", totalGainLoss)) (\(String(format: "%.2f", gainLossPercentage))%)
            • Number of Holdings: \(portfolioStocks.count)
            """
        }
        
        // Individual holdings
        if !portfolioStocks.isEmpty {
            context += "\n\n**Current Holdings:**"
            for stock in portfolioStocks {
                if let stockModel = homeViewModel.returnStockModel(symbol: stock.stockSymbol) {
                    let currentPrice = stockModel.Last_Price
                    let currentValue = currentPrice * Double(stock.quantity)
                    let investedValue = stock.avgBuyPrice * Double(stock.quantity)
                    let gainLoss = currentValue - investedValue
                    let gainLossPercent = (gainLoss / investedValue) * 100
                    
                    context += """
                    
                    • \(stock.stockSymbol): \(stock.quantity) shares @ avg ₹\(String(format: "%.2f", stock.avgBuyPrice))
                      Current: ₹\(String(format: "%.2f", currentPrice)) | Value: ₹\(String(format: "%.2f", currentValue))
                      P/L: ₹\(String(format: "%.2f", gainLoss)) (\(String(format: "%.2f", gainLossPercent))%)
                    """
                    
                    // Add comprehensive data if available
                    if let comprehensive = getStockComprehensive(symbol: stock.stockSymbol) {
                        var fundamentals: [String] = []
                        
                        if let basic = comprehensive.basic {
                            if let sector = basic.sector {
                                fundamentals.append("Sector: \(sector)")
                            }
                            if let industry = basic.industry {
                                fundamentals.append("Industry: \(industry)")
                            }
                        }
                        
                        if let valuation = comprehensive.valuation {
                            if let pe = valuation.pe {
                                fundamentals.append("P/E: \(String(format: "%.2f", pe))")
                            }
                            if let pb = valuation.priceToBook {
                                fundamentals.append("P/B: \(String(format: "%.2f", pb))")
                            }
                            if let forwardPE = valuation.forwardPE {
                                fundamentals.append("Forward P/E: \(String(format: "%.2f", forwardPE))")
                            }
                        }
                        
                        if let financial = comprehensive.financial {
                            if let profitMargin = financial.profitMargin {
                                fundamentals.append("Profit Margin: \(String(format: "%.2f", profitMargin * 100))%")
                            }
                            if let dividendYield = financial.dividendYield {
                                fundamentals.append("Div Yield: \(String(format: "%.2f", dividendYield * 100))%")
                            }
                        }
                        
                        if let balanceSheet = comprehensive.balanceSheet {
                            if let debtToEquity = balanceSheet.debtToEquity {
                                fundamentals.append("D/E: \(String(format: "%.2f", debtToEquity))")
                            }
                        }
                        
                        if !fundamentals.isEmpty {
                            context += "\n      " + fundamentals.joined(separator: " | ")
                        }
                    }
                }
            }
        }
        
        // Portfolio history insights
        if portfolioHistory.count >= 2 {
            let firstEntry = portfolioHistory.first!
            let latestEntry = portfolioHistory.last!
            
            if let firstDate = firstEntry.dateAsDate,
               let latestDate = latestEntry.dateAsDate {
                
                let timePeriodDays = Calendar.current.dateComponents([.day], from: firstDate, to: latestDate).day ?? 0
                
                if timePeriodDays > 0 {
                    let valueChange = latestEntry.portfolioValue - firstEntry.portfolioValue
                    let percentChange = (valueChange / firstEntry.portfolioValue) * 100
                    
                    context += """
                    
                    
                    **Historical Performance (\(timePeriodDays) days):**
                    • Starting Value: ₹\(String(format: "%.2f", firstEntry.portfolioValue))
                    • Current Value: ₹\(String(format: "%.2f", latestEntry.portfolioValue))
                    • Change: ₹\(String(format: "%.2f", valueChange)) (\(String(format: "%.2f", percentChange))%)
                    """
                }
            }
        }

        // Sector diversification
        var sectorGroups: [String: [DBPortfolioStock]] = [:]
        
        for stock in portfolioStocks {
            var sector = "Unknown"
            
            // Try to get sector from comprehensive data first
            if let comprehensive = getStockComprehensive(symbol: stock.stockSymbol),
               let basic = comprehensive.basic,
               let sectorName = basic.sector {
                sector = sectorName
            }
            if sectorGroups[sector] != nil {
                sectorGroups[sector]?.append(stock)
            } else {
                sectorGroups[sector] = [stock]
            }
        }
        
        if !sectorGroups.isEmpty {
            context += "\n\n**Sector Distribution:**"
            for (sector, stocks) in sectorGroups.sorted(by: { $0.value.count > $1.value.count }) {
                let sectorValue = stocks.reduce(0.0) { sum, stock in
                    guard let stockModel = homeViewModel.returnStockModel(symbol: stock.stockSymbol) else { return sum }
                    return sum + (stockModel.Last_Price * Double(stock.quantity))
                }
                let sectorPercent = portfolioValue > 0 ? (sectorValue / portfolioValue) * 100 : 0
                context += "\n• \(sector): \(stocks.count) stocks (\(String(format: "%.1f", sectorPercent))% of portfolio)"
            }
        }
        
        return context
    }
    
    // MARK: - FynVerse App Context (Knowledge Base)
    private let appContext = """
    You are FynVerse AI Assistant, an expert financial advisor integrated into the FynVerse stock market analysis app.
    
    ## APP CAPABILITIES & FEATURES:
    
    ### 1. STOCK ANALYSIS & TRACKING
    - Real-time price tracking for Indian stocks (NSE)
    - Comprehensive stock data including:
      • Technical indicators (MA20, MA50, MA200, RSI)
      • Fundamental metrics (P/E ratio, P/B ratio, debt-to-equity)
      • 52-week high/low ranges
      • Returns (1-week, 1-month, 3-month, 6-month)
      • Volatility and Beta metrics
    
    ### 2. RESEARCH-BASED P/E VALUATION
    - Advanced PEG-adjusted P/E analysis
    - Sector-specific growth rate considerations:
      • Technology: 12.5% CAGR
      • Renewable Energy: 20% CAGR
      • Electric Vehicles: 25% CAGR
      • Fintech: 18% CAGR
      • Financial Services: 10% CAGR
      • Healthcare: 11% CAGR
    - Scores stocks A-F based on P/E justification by growth + fundamentals
    - High P/E is acceptable when justified by strong growth
    
    ### 3. PORTFOLIO ANALYSIS
    - Comprehensive portfolio scoring (0-100) with letter grades (A-F)
    - Five key metrics:
      • Diversification Score (25% weight) - sector distribution
      • P/E Rating Score (20% weight) - research-based valuation
      • Risk Management Score (25% weight) - beta and concentration
      • Allocation Quality (15% weight) - position sizing
      • Market Cap Mix (15% weight) - large/mid/small cap distribution
    
    ### 4. ML-ENHANCED ANALYSIS
    - Predictive risk scoring using Random Forest
    - Anomaly detection for unusual portfolio structures
    - Future volatility predictions
    
    ### 5. MARKET CAP CATEGORIZATION
    - Large Cap: ≥₹20,000 Cr
    - Mid Cap: ₹5,000-20,000 Cr
    - Small Cap: <₹5,000 Cr
    - Recommended mix: 60-70% Large, 15-30% Mid, 5-15% Small
    
    ### 6. KEY PORTFOLIO RECOMMENDATIONS
    - Optimal holdings: 8-15 stocks
    - No sector should exceed 40% of portfolio
    - Max single stock position: 25-35%
    - Target beta: 0.8-1.2 for moderate risk
    
    ## YOUR ROLE:
    - Provide PERSONALIZED financial insights based on the user's actual portfolio data
    - Reference specific stocks they own and their performance
    - Give actionable advice tailored to their holdings
    - Explain complex metrics in simple terms
    - Guide users on portfolio optimization based on their actual positions
    - Interpret P/E ratios in context of sector growth
    - Warn users appropriately about risks in THEIR portfolio
    - Always remind users this is educational, not financial advice
    
    ## RESPONSE STYLE:
    - Address the user by name when known
    - Reference their specific holdings naturally in conversation
    - Use emojis sparingly (📊 💰 ⚠️ ✅) for key points
    - Break complex topics into digestible points
    - Reference specific FynVerse features when relevant
    - Ask clarifying questions when needed
    
    ## IMPORTANT DISCLAIMERS:
    - Always end investment advice with: "This is for informational purposes only. Consult a qualified financial advisor before investing."
    - For high-risk suggestions, add warnings about market volatility
    - Never guarantee returns or specific outcomes
    """
    
    // MARK: - Enhanced Prompt Engineering with RAG
    private func buildContextualPrompt(userQuery: String) -> String {
        let conversationHistory = messages.suffix(4).map { msg in
            "\(msg.isUser ? "User" : "Assistant"): \(msg.text)"
        }.joined(separator: "\n")
        
        let personalizedContext = buildPersonalizedContext()
        
        return """
        \(appContext)
        
        \(personalizedContext)
        
        ## CONVERSATION CONTEXT:
        \(conversationHistory.isEmpty ? "New conversation" : conversationHistory)
        
        ## CURRENT USER QUERY:
        \(userQuery)
        
        ## INSTRUCTIONS:
        1. Use the user's actual portfolio data to provide personalized insights
        2. Reference their specific holdings when relevant (e.g., "Your RELIANCE position is...")
        3. Give tailored advice based on their sector distribution and risk profile
        4. If they ask about their portfolio, analyze their actual holdings
        5. Compare their performance to market benchmarks when applicable
        6. Suggest improvements based on their current positions
        7. Keep response concise (2-4 paragraphs max) unless detailed analysis needed
        8. Always be helpful, accurate, and user-focused
        
        Respond naturally as FynVerse AI Assistant with personalized insights:
        """
    }
    
    // MARK: - Intent Detection for Smart Routing
    private func detectIntent(_ query: String) -> QueryIntent {
        let lowercased = query.lowercased()
        
        // My portfolio queries
        if lowercased.contains("my portfolio") || lowercased.contains("my stocks") ||
           lowercased.contains("my holdings") || lowercased.contains("my investments") {
            return .myPortfolio
        }
        
        // Portfolio-related queries
        if lowercased.contains("portfolio") || lowercased.contains("diversif") ||
           lowercased.contains("allocation") {
            return .portfolio
        }
        
        // Stock analysis queries
        if lowercased.contains("stock") || lowercased.contains("share") ||
           lowercased.contains("company") || lowercased.contains("ticker") {
            return .stockAnalysis
        }
        
        // P/E ratio and valuation queries
        if lowercased.contains("p/e") || lowercased.contains("pe ratio") ||
           lowercased.contains("valuation") || lowercased.contains("overvalued") ||
           lowercased.contains("expensive") {
            return .valuation
        }
        
        // Risk-related queries
        if lowercased.contains("risk") || lowercased.contains("volatile") ||
           lowercased.contains("beta") || lowercased.contains("safe") {
            return .risk
        }
        
        // Performance queries
        if lowercased.contains("performance") || lowercased.contains("returns") ||
           lowercased.contains("gain") || lowercased.contains("loss") ||
           lowercased.contains("profit") {
            return .performance
        }
        
        // Market cap queries
        if lowercased.contains("market cap") || lowercased.contains("large cap") ||
           lowercased.contains("small cap") || lowercased.contains("mid cap") {
            return .marketCap
        }
        
        // How-to / feature explanation
        if lowercased.contains("how to") || lowercased.contains("how do i") ||
           lowercased.contains("what is") || lowercased.contains("explain") {
            return .howTo
        }
        
        return .general
    }
    
    // MARK: - Send Message with Context
    func sendMessage() {
        guard !inputText.isEmpty else { return }
        
        let userMessage = inputText
        messages.append(ChatMessage(text: userMessage, isUser: true))
        inputText = ""
        
        Task {
            isLoading = true
            let intent = detectIntent(userMessage)
            let response = await getContextualResponse(query: userMessage, intent: intent)
            messages.append(ChatMessage(text: response, isUser: false))
            isLoading = false
        }
    }
    
    // MARK: - Contextual Response with Enhanced Prompting
    private func getContextualResponse(query: String, intent: QueryIntent) async -> String {
        guard let apiKey = apiKey, !apiKey.isEmpty else {
            return "⚠️ Error: API Key is not configured. Please check your environment settings."
        }
        
        do {
            let generativeModel = GenerativeModel(name: "gemini-2.0-flash", apiKey: apiKey)
            
            // Build context-aware prompt with portfolio data
            let enhancedPrompt = buildContextualPrompt(userQuery: query)
            
            // Generate response
            let response = try await generativeModel.generateContent(enhancedPrompt)
            
            guard let responseText = response.text else {
                return "I apologize, but I couldn't generate a response. Please try rephrasing your question."
            }
            
            // Add intent-specific enhancements
            return enhanceResponse(responseText, for: intent)
            
        } catch {
            print("❌ Error generating content: \(error)")
            return "Sorry, I encountered an error: \(error.localizedDescription). Please try again."
        }
    }
    
    // MARK: - Response Enhancement Based on Intent
    private func enhanceResponse(_ response: String, for intent: QueryIntent) -> String {
        var enhanced = response
        
        // Add relevant quick actions or suggestions
        switch intent {
        case .myPortfolio, .portfolio:
            if !enhanced.contains("Analyze") && !enhanced.contains("analyze") {
                enhanced += "\n\n💡 Tip: Use FynVerse's Portfolio Analyzer to get a detailed score and personalized recommendations!"
            }
            
        case .stockAnalysis:
            if !enhanced.contains("stock analysis") && !enhanced.lowercased().contains("comprehensive") {
                enhanced += "\n\n📊 You can view comprehensive stock analysis with technical indicators and fundamentals in FynVerse."
            }
            
        case .valuation:
            if !enhanced.contains("PEG") {
                enhanced += "\n\n🔍 FynVerse uses PEG-adjusted P/E analysis - high P/E can be justified by strong growth!"
            }
            
        case .risk:
            enhanced += "\n\n⚠️ Remember: FynVerse provides ML-based risk predictions to help you make informed decisions."
            
        case .performance:
            if portfolioHistory.count > 7 {
                enhanced += "\n\n📈 Check your portfolio history chart for visual performance tracking!"
            }
            
        default:
            break
        }
        
        return enhanced
    }
    
    // MARK: - Predefined Quick Responses for Common Queries
    func handleQuickQuery(_ query: QuickQuery) {
        let response: String
        
        switch query {
        case .portfolioAnalysis:
            response = """
            📊 **FynVerse Portfolio Analysis Explained**
            
            Your portfolio gets a comprehensive score (0-100) based on:
            
            1️⃣ **Diversification (25%)** - Are you spread across sectors?
            2️⃣ **P/E Rating (20%)** - Are valuations justified by growth?
            3️⃣ **Risk Management (25%)** - Beta and position sizing
            4️⃣ **Allocation Quality (15%)** - Balance across holdings
            5️⃣ **Market Cap Mix (15%)** - Large/Mid/Small cap distribution
            
            Grade A (80+) = Excellent portfolio structure ✅
            Grade B (70-79) = Good, minor improvements needed
            Grade C (60-69) = Average, consider rebalancing
            Grade D/F (<60) = Needs significant changes ⚠️
            
            Tap "Analyze Portfolio" to see your score!
            """
            
        case .peRatio:
            response = """
            📈 **Understanding P/E Ratios in FynVerse**
            
            We use **research-based PEG-adjusted P/E analysis**:
            
            **High P/E is OK when:**
            ✅ Strong earnings growth (>15%)
            ✅ High sector growth rate (e.g., EVs: 25% CAGR)
            ✅ Strong fundamentals (ROE >15%, good margins)
            ✅ PEG ratio < 2.0
            
            **Warning signs:**
            ⚠️ PEG ratio > 3.0
            ⚠️ Declining revenue despite high P/E
            ⚠️ Negative profit margins
            
            Example: A tech stock with P/E 40 and 20% growth = Fair (PEG 2.0)
            But a utility stock with P/E 40 and 7% growth = Overvalued (PEG 5.7)
            
            FynVerse considers sector context automatically!
            """
            
        case .riskManagement:
            response = """
            🛡️ **Risk Management in FynVerse**
            
            **Key Metrics We Track:**
            
            1. **Beta** - Market sensitivity
               • <0.8 = Conservative
               • 0.8-1.2 = Moderate (ideal)
               • >1.2 = Aggressive
            
            2. **Position Sizing**
               • Max 25-35% in single stock
               • Max 40% in one sector
            
            3. **Volatility** - 60-day annualized
            
            4. **ML Risk Prediction** - Future volatility forecast
            
            5. **Anomaly Detection** - Unusual portfolio patterns
            
            💡 Diversification is your best defense against market swings!
            """
            
        case .appFeatures:
            response = """
            🚀 **FynVerse Key Features**
            
            📊 **Real-Time Tracking**
            • Indian stocks (NSE) live prices
            • Historical data tracking
            
            🔍 **Stock Analysis**
            • Technical: MA, RSI, 52-week ranges
            • Fundamentals: P/E, P/B, Debt/Equity, ROE
            • Sector-aware valuation scoring
            
            💼 **Portfolio Tools**
            • 5-factor scoring system
            • ML-based risk prediction
            • Personalized AI recommendations
            
            🤖 **AI-Powered**
            • Anomaly detection
            • Predictive analytics
            • Context-aware P/E assessment
            • Personalized chat assistant
            
            📱 **Easy to Use**
            • Clean interface
            • Instant insights
            • Educational guidance
            
            What would you like to explore?
            """
        }
        
        messages.append(ChatMessage(text: response, isUser: false))
    }
}

// MARK: - Supporting Enums
enum QueryIntent {
    case myPortfolio
    case portfolio
    case stockAnalysis
    case valuation
    case risk
    case performance
    case marketCap
    case howTo
    case general
}

enum QuickQuery {
    case portfolioAnalysis
    case peRatio
    case riskManagement
    case appFeatures
}
