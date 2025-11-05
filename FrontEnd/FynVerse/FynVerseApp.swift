import SwiftUI
import Firebase


@main
struct FynVerseApp: App {
    @StateObject var tvm = TransactionViewModel()   // <- FIX
    
    init() {
        // Configure Firebase when the app initializes
        FirebaseApp.configure()
    }
   
    var body: some Scene {
        WindowGroup {
            ContentView(tvm: tvm)
        }
    }
}


struct ContentView: View {
    @State private var isInitialized = false
    @ObservedObject var tvm: TransactionViewModel
    
    var body: some View {
        Group {
            if isInitialized {
                MainAppView(tvm: tvm)
            } else {
                ProgressView("Loading...")
                    .onAppear {
                        // Small delay to ensure Firebase is fully configured
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            isInitialized = true
                        }
                    }
            }
        }
    }
}

struct MainAppView: View {
    @StateObject private var authViewModel = AuthViewModel()
    @AppStorage("isLoggedIn") private var isLoggedIn: Bool = false
    @ObservedObject var tvm: TransactionViewModel
    
    var body: some View {
        VStack {
            if authViewModel.isLoggedIn {
                NavigationStack {
                    AuthenticatedContentView( tvm: tvm)
                }
            } else {
                RegisterView()
            }
        }
        .environmentObject(authViewModel)
        .task {
            await loadUser()
        }
    }
    
    private func loadUser() async {
        do {
            try await authViewModel.loadCurrentUser()
        } catch {
            print("Failed to load current user: \(error)")
        }
    }
}

struct AuthenticatedContentView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @ObservedObject var tvm: TransactionViewModel
    
    var body: some View {
        ViewModelContainer( tvm: tvm)
    }
}

struct ViewModelContainer: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @ObservedObject var tvm: TransactionViewModel
    
    var body: some View {
        // Create ViewModels here where we know Firebase is ready
        // and authViewModel is available
        ViewModelContent(authViewModel: authViewModel, tvm: tvm)
    }
}

struct ViewModelContent: View {
    let authViewModel: AuthViewModel
    @StateObject private var homeViewModel: HomeViewModel
    @StateObject private var portfolioViewModel: PortfolioViewModel
    @ObservedObject var tvm: TransactionViewModel
    
    init(authViewModel: AuthViewModel, tvm: TransactionViewModel) {
        self.authViewModel = authViewModel
        self.tvm = tvm
        
        let home = HomeViewModel(authViewModel: authViewModel)
        _homeViewModel = StateObject(wrappedValue: home)
        _portfolioViewModel = StateObject(
            wrappedValue: PortfolioViewModel(authViewModel: authViewModel, homeViewModel: home)
        )
    }
    
    var body: some View {
        SplashScreenView(vm: authViewModel, Pvm: portfolioViewModel, tvm: tvm)
            .environmentObject(homeViewModel)
            .environmentObject(portfolioViewModel)
    }
}
