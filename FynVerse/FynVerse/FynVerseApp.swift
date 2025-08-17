import SwiftUI
import Firebase

@main
struct FynVerseApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    
    @AppStorage("isLoggedIn") var isLoggedIn: Bool = false
    @StateObject var authViewModel: AuthViewModel
    @StateObject private var vm: HomeViewModel
    
    init() {
        // Step 1: Create the AuthViewModel instance.
        let authVM = AuthViewModel()
        
        // Step 2: Initialize the property wrappers.
        _authViewModel = StateObject(wrappedValue: authVM)
        _vm = StateObject(wrappedValue: HomeViewModel(authViewModel: authVM))
    }

    var body: some Scene {
        WindowGroup {
            VStack {
                if isLoggedIn {
                    NavigationStack {
                        SplashScreenView(vm: authViewModel) // ✅ FIX: use `authViewModel`
                    }
                } else {
                    RegisterView()
                }
            }
            .environmentObject(vm)
            .environmentObject(authViewModel)
            .task {
                try? await authViewModel.loadCurrentUser()
            }
        }
    }
}

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil
    ) -> Bool {
        FirebaseApp.configure()
        return true
    }
}
