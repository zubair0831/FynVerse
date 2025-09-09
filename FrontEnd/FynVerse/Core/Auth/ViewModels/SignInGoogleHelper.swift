//
//  SignInGoogleHelper.swift
//  FynVerse
//
//  Created by zubair ahmed on 01/08/25.
//

import Foundation
import GoogleSignIn



final class SignInGoogleHelper{
    @MainActor
    func signIn() async throws -> GoogleSignInResultModel{
        // 1. Get root view controller
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            print("❌ Could not find root view controller")
            throw URLError(.cannotFindHost)
        }
        
        // 2. Start Google Sign-In flow
        let gidSignInResult = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController)
        
        // 3. Extract tokens
        guard let idToken = gidSignInResult.user.idToken?.tokenString else {
            throw URLError(.userAuthenticationRequired)
        }
        let accessToken = gidSignInResult.user.accessToken.tokenString
        
        // 4. Wrap tokens in your model
        let tokens = GoogleSignInResultModel(idToken: idToken, accessToken: accessToken)
        return tokens
    }
}
