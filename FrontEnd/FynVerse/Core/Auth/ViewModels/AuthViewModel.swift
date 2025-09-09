import Foundation
import SwiftUI
import Firebase

// MARK: - AuthViewModel
@MainActor
final class AuthViewModel: ObservableObject {
    @Published var user : DBUser? = nil
    @Published var email = ""
    @Published var password = ""
    @AppStorage("isLoggedIn") var isLoggedIn: Bool = false
    @AppStorage("hasAskedForName") var hasAskedForName: Bool = false
    @Published var isLoading: Bool = false
    
    
    func signUp() async throws {
        guard !email.isEmpty, !password.isEmpty else { return }
        
        let authDataResult =  try await AuthService.shared.createUser(email: email, password: password)
        let user = DBUser(auth: authDataResult)
        try await UserManager.shared.createNewUser(user: user)
        isLoggedIn = true
    }
    
    func checkAuthStatus() {
        isLoggedIn = (try? AuthService.shared.getAuthenticatedUser()) != nil
    }
    
    func loadCurrentUser() async throws {
        self.isLoading = true
        defer { self.isLoading = false }
        
        let authDataResult = try AuthService.shared.getAuthenticatedUser()
        
        let fetchedUser = try await UserManager.shared.getUser(userID: authDataResult.uid)
        
        if let fetchedUser = fetchedUser {
            self.user = fetchedUser
        } else {
            let newUser = DBUser(auth: authDataResult)
            try await UserManager.shared.createNewUser(user: newUser)
            self.user = newUser // Test
        }
    }

    @MainActor
    func updateUserName(_ name: String) async throws {
        guard let uid = user?.userID else { return }
        
        // Update in Firestore
        try await Firebase.Firestore.firestore().collection("users").document(uid).updateData([
            "fullName": name
        ])
        
        // Update locally
        user?.fullName = name
        
        // Set the persistent flag after a successful update.
        hasAskedForName = true
    }



    //SettingsViewModel
    func logout() {
        do {
            try AuthService.shared.signOut()
            isLoggedIn = false
            hasAskedForName = false // Reset the flag on logout
        } catch {
            print("Logout error:", error)
        }
    }
    
    func resetPassword() async throws {
        let authUser = try AuthService.shared.getAuthenticatedUser()
        
        // Make sure the user actually has an email
        guard let email = authUser.email else {
            throw URLError(.badURL) // or create a custom error for clarity
        }
        
        // Send reset link
        try await AuthService.shared.resetPassword(email: email)
    }

    func updatePassword() async throws {
        try await AuthService.shared.updatePassword(password: "New Pass")
    }
    
    func delete() async throws{
        try await AuthService.shared.delete()
    }



    //AutgenticationViewModel
    func logIn() async throws {
        guard !email.isEmpty, !password.isEmpty else { return }
        
        _ = try await AuthService.shared.signInUser(email: email, password: password)
        isLoggedIn = true
    }
    
    //SignInWithGoogle
    func signInGoogle() async throws {
        let helper = SignInGoogleHelper()
        let tokens = try await helper.signIn()
        let authDataResult = try await AuthService.shared.signInWithGoogle(tokens: tokens)
        let user = DBUser(auth: authDataResult)
        try await UserManager.shared.createNewUser(user: user)
        isLoggedIn = true
    }

}
