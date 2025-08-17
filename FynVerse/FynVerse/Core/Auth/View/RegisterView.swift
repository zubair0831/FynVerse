import SwiftUI
import GoogleSignInSwift
enum AuthDestination: Hashable {
    case signUp
    case logIn
    case home
    case resetPassword
}
struct RegisterView: View {
    // This is the single source of truth for the authentication state.
    @StateObject private var vm: AuthViewModel = AuthViewModel()
    
    // The NavigationPath holds the state of our navigation stack.
    @State private var path = NavigationPath()

    var body: some View {
        // NavigationStack is the new way to manage navigation.
        // It uses a data-driven approach with the 'path' variable.
        NavigationStack(path: $path) {
            ZStack {
                Color.theme.background
                    .ignoresSafeArea()

                VStack(spacing: 24) {
                    Text("Welcome to FynVerse")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.black)
                        .padding(.top, 40)

                    Spacer()

                    VStack(spacing: 16) {
                        // Sign Up Button
                        Button {
                            // Append the 'signUp' case to the path to trigger navigation.
                            path.append(AuthDestination.signUp)
                        } label: {
                            Text("Sign Up with Email")
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(Color.white)
                                .foregroundColor(Color.blue)
                                .font(.headline)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .shadow(color: .black.opacity(0.2), radius: 5, x: 0, y: 2)
                        }

                        // Log In Button
                        Button {
                            // Append the 'logIn' case to the path to trigger navigation.
                            path.append(AuthDestination.logIn)
                        } label: {
                            Text("Log In with Email")
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(Color.white)
                                .foregroundColor(Color.blue)
                                .font(.headline)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .shadow(color: .black.opacity(0.2), radius: 5, x: 0, y: 2)
                        }

                        Text("Or")
                            .foregroundColor(.white.opacity(0.8))
                            .font(.subheadline)
                            .padding(.top, 8)

                        GoogleSignInButton(
                            viewModel: GoogleSignInButtonViewModel(
                                scheme: .dark,
                                style: .standard,
                                state: .normal
                            )
                        ) {
                            Task {
                                do {
                                    try await vm.signInGoogle()
                                    print("✅ Google Sign-In Success")
                                } catch {
                                    print("❌ Google Sign-In failed: \(error.localizedDescription)")
                                }
                            }
                        }
                        .frame(height: 50)
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)

                    Spacer()
                }
                .padding()
            }
            .navigationTitle("FynVerse")
            .navigationBarTitleDisplayMode(.inline)
            // This is the new way to handle navigation. For each possible type of data
            // (in this case, AuthDestination), we define a destination view.
            .navigationDestination(for: AuthDestination.self) { destination in
                switch destination {
                case .signUp:
                    // Pass the single AuthViewModel instance down to the SignUpView
                    SignUpView(vm: vm, current: "SignUp", path: $path)
                case .logIn:
                    // Pass the single AuthViewModel instance down to the SignUpView
                    SignUpView(vm: vm, current: "LogIn", path: $path)
                case .home:
                    HomeView(authvm: vm)
                case .resetPassword:
                    // Pass the single AuthViewModel instance down to the ResetPasswordView
                    ResetPasswordView()
                }
            }
            // The updated `onChange` syntax. We no longer use `perform:`.
            // The closure now provides both the old value and the new value.
            .onChange(of: vm.isLoggedIn) { oldValue, newValue in
                if newValue {
                    // Navigate to the HomeView by setting the path
                    path.append(AuthDestination.home)
                }
            }
        }
    }
}
