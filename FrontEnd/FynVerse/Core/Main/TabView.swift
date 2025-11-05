import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var vm: HomeViewModel
    @ObservedObject var authvm: AuthViewModel
    @ObservedObject var Pvm: PortfolioViewModel
    @ObservedObject var transactionVM: TransactionViewModel
    var body: some View {
        NavigationStack {
            TabView {
                HomeView(authvm: authvm)
                    .tabItem { Label("Explore", systemImage: "globe") }

                PortfolioView( vm: Pvm, authvm: authvm)
                    .tabItem { Label("My Portfolio", systemImage: "briefcase.circle.fill") }

                ProfileView(transactionVM: transactionVM, homevm: vm)
                    .tabItem { Label("Profile", systemImage: "person.fill") }

                CompleteSearchBar(homeVM: vm, authvm: authvm)
                    .tabItem { Label("Search", systemImage: "magnifyingglass") }
            }
            .tabViewStyle(.automatic)
            .tabBarMinimizeBehavior(.onScrollDown)

        }
    }
}

   
