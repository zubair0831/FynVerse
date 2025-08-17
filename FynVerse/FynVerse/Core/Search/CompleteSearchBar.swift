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

            VStack {
                // Search Bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(Color.theme.secondary)

                    TextField("Search by name or symbol...", text: $vm.localSearchText)
                        .autocorrectionDisabled()
                        .overlay(
                            Group {
                                if !vm.localSearchText.isEmpty {
                                    Image(systemName: "xmark.circle.fill")
                                        .padding(.trailing, 8)
                                        .onTapGesture { vm.localSearchText = "" }
                                }
                            },
                            alignment: .trailing
                        )
                }
                .padding()

                // Results List
                ScrollView {
                    LazyVStack {
                        if vm.localSearchText.isEmpty {
                            Text("Recent Searches")
                                .font(.headline)
                                .padding(.top, 4)

                            ForEach(vm.recentStocks) { stock in
                                NavigationLink(destination: DetailView(stock: stock, DBStock: nil, authViewModel: authvm)) {
                                    StockRowView(stock: stock, portfolioStock: nil)
                                }
                            }
                        } else {
                            ForEach(vm.filteredStocks) { stock in
                                NavigationLink(
                                    destination: DetailView(stock: stock, DBStock: nil, authViewModel: authvm)
                                ) {
                                    StockRowView(stock: stock, portfolioStock: nil)
                                }
                                .simultaneousGesture(TapGesture().onEnded {
                                    vm.saveRecentSearch(stock: stock)
                                })
                            }
                        }
                    }
                }
            }
        }
        .onAppear { vm.onAppear() }
    }
}
