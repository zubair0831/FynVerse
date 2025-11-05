import SwiftUI

struct CompleteSearchBar: View {
    @StateObject private var vm: CompleteSearchBarViewModel
    @ObservedObject var authvm: AuthViewModel
    
    init(homeVM: HomeViewModel, authvm: AuthViewModel) {
        _vm = StateObject(wrappedValue: CompleteSearchBarViewModel(homeVM: homeVM))
        self.authvm = authvm
    }
    
    var body: some View {
        ZStack {
            Color.theme.background.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Search Bar with modern styling
                searchBarSection
                
                // Results List
                searchResultsSection
            }
        }
        .onAppear { vm.onAppear() }
    }
    
    // MARK: - Search Bar Section
    private var searchBarSection: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                // Search Icon
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(Color.theme.accent)
                
                // Text Field
                TextField("Search by name or symbol...", text: $vm.localSearchText)
                    .font(.system(size: 16))
                    .foregroundStyle(Color.theme.primaryText)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.characters)
                
                // Clear Button
                if !vm.localSearchText.isEmpty {
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            vm.localSearchText = ""
                        }
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(Color.theme.secondary)
                    }
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.theme.cardBackground)
                    .shadow(color: Color.theme.cardShadow, radius: 8, x: 0, y: 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        vm.localSearchText.isEmpty ? Color.clear : Color.theme.accent.opacity(0.3),
                        lineWidth: 1.5
                    )
            )
            
            // Search hints (optional)
            if vm.localSearchText.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "lightbulb.fill")
                        .font(.caption)
                        .foregroundStyle(Color.theme.secondary.opacity(0.7))
                    
                    Text("Try searching: RELIANCE, TCS, INFY")
                        .font(.caption)
                        .foregroundStyle(Color.theme.secondary.opacity(0.7))
                    
                    Spacer()
                }
                .padding(.horizontal, 4)
                .transition(.opacity)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 12)
    }
    
    // MARK: - Search Results Section
    private var searchResultsSection: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 0) {
                if vm.localSearchText.isEmpty {
                    recentSearchesView
                } else {
                    searchResultsView
                }
            }
            .padding(.top, 8)
        }
    }
    
    // MARK: - Recent Searches View
    private var recentSearchesView: some View {
        VStack(alignment: .leading, spacing: 16) {
            if !vm.recentStocks.isEmpty {
                HStack {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.theme.accent)
                    
                    Text("Recent Searches")
                        .font(.headline)
                        .foregroundStyle(Color.theme.accent)
                    
                    Spacer()
                    
                    Button(action: {
                        // Add clear all functionality if needed
                    }) {
                        Text("Clear All")
                            .font(.caption)
                            .foregroundStyle(Color.theme.secondary)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                
                ForEach(vm.recentStocks) { stock in
                    NavigationLink(destination: DetailView(stock: stock, DBStock: nil, authViewModel: authvm)) {
                        StockRowView(stock: stock, authvm: authvm)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                }
            } else {
                emptyRecentSearchesView
            }
        }
    }
    
    // MARK: - Empty Recent Searches
    private var emptyRecentSearchesView: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 50))
                .foregroundStyle(Color.theme.secondary.opacity(0.4))
                .padding(.top, 60)
            
            Text("No Recent Searches")
                .font(.headline)
                .foregroundStyle(Color.theme.primaryText)
            
            Text("Start searching for stocks to see them here")
                .font(.subheadline)
                .foregroundStyle(Color.theme.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
    
    // MARK: - Search Results View
    private var searchResultsView: some View {
        VStack(spacing: 0) {
            if vm.filteredStocks.isEmpty {
                noResultsView
            } else {
                // Results header
                HStack {
                    Text("\(vm.filteredStocks.count) result\(vm.filteredStocks.count == 1 ? "" : "s")")
                        .font(.subheadline)
                        .foregroundStyle(Color.theme.secondary)
                    
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
                
                // Results list
                ForEach(vm.filteredStocks) { stock in
                    NavigationLink(
                        destination: DetailView(stock: stock, DBStock: nil, authViewModel: authvm)
                    ) {
                        StockRowView(stock: stock, authvm: authvm)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                    .simultaneousGesture(TapGesture().onEnded {
                        vm.saveRecentSearch(stock: stock)
                    })
                }
            }
        }
    }
    
    // MARK: - No Results View
    private var noResultsView: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.magnifyingglass")
                .font(.system(size: 50))
                .foregroundStyle(Color.theme.secondary.opacity(0.4))
                .padding(.top, 60)
            
            Text("No Results Found")
                .font(.headline)
                .foregroundStyle(Color.theme.primaryText)
            
            Text("Try searching with a different keyword")
                .font(.subheadline)
                .foregroundStyle(Color.theme.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            // Suggestion chips (optional)
            VStack(alignment: .leading, spacing: 8) {
                Text("Popular Stocks")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.theme.secondary)
                    .padding(.top, 8)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(["RELIANCE", "TCS", "INFY", "HDFC", "ITC"], id: \.self) { symbol in
                            Button(action: {
                                vm.localSearchText = symbol
                            }) {
                                Text(symbol)
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundStyle(Color.theme.accent)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Color.theme.accent.opacity(0.1))
                                    )
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}

// MARK: - Custom Button Style (if not already defined)
struct SearchButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}
