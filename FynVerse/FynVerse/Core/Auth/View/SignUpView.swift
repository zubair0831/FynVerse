import SwiftUI

// MARK: - SignUpView
struct SignUpView: View {
    // We now receive the AuthViewModel from the parent view.
    @StateObject var vm: AuthViewModel
    var current: String
    
    // We also need access to the parent's NavigationPath
    @Binding var path: NavigationPath
    
    var body: some View {
        ZStack {
            Color(red: 127/255, green: 255/255, blue: 212/255)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Text(current == "SignUp" ? "Create an Account" : "Welcome Back")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.black)
                    .padding(.top, 40)

                TextField("Email...", text: $vm.email)
                    .padding()
                    .background(Color.white)
                    .cornerRadius(10)
                    .foregroundColor(.black)
                    .autocapitalization(.none)

                SecureField("Password...", text: $vm.password)
                    .padding()
                    .background(Color.white)
                    .cornerRadius(10)
                    .foregroundColor(.black)

                // Login / Signup Button
                Button {
                    Task {
                        vm.isLoading = true
                        do {
                            if current == "SignUp" {
                                try await vm.signUp()
                            } else {
                                try await vm.logIn()
                            }
                        } catch {
                            print("❌ Auth error: \(error)")
                        }
                        vm.isLoading = false
                    }
                } label: {
                    if vm.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.gray)
                            .cornerRadius(10)
                    } else {
                        Text(current)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .font(.headline)
                            .cornerRadius(10)
                            .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                    }
                }

                // Reset Password Option
                if current == "LogIn" {
                    Button("Forgot Password?") {
                        path.append(AuthDestination.resetPassword)
                    }
                    .foregroundColor(.black)
                    .font(.subheadline)
                    .padding(.top, 10)
                }

                Spacer()
            }
            .padding()
        }
        .navigationTitle(current)
        .navigationBarTitleDisplayMode(.inline)
    }
}

