//
//  ResetPasswordView.swift
//  FynVerse
//
//  Created by zubair ahmed on 17/08/25.
//

import SwiftUI

struct ResetPasswordView: View {
    @StateObject private var vm: AuthViewModel = AuthViewModel()
    @State private var message: String?
    @State private var isSuccess = false
    
    var body: some View {
        ZStack {
            Color.theme.background
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                Text("Reset Password")
                    .font(.title)
                    .fontWeight(.bold)
                    .padding(.top, 40)
                
                TextField("Enter your email...", text: $vm.email)
                    .padding()
                    .background(Color.white)
                    .cornerRadius(10)
                    .foregroundColor(.black)
                    .autocapitalization(.none)
                
                Button {
                    Task {
                        do {
                            try await AuthService.shared.resetPassword(email: vm.email)
                            message = "✅ Password reset email sent to \(vm.email)."
                            isSuccess = true
                        } catch {
                            message = "❌ Error: \(error.localizedDescription)"
                            isSuccess = false
                        }
                    }
                } label: {
                    Text("Send Reset Link")
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .font(.headline)
                        .cornerRadius(10)
                }
                
                if let message = message {
                    Text(message)
                        .foregroundColor(isSuccess ? .green : .red)
                        .multilineTextAlignment(.center)
                        .padding()
                }
                
                Spacer()
            }
            .padding()
        }
        .navigationTitle("Reset Password")
        .navigationBarTitleDisplayMode(.inline)
    }
}
