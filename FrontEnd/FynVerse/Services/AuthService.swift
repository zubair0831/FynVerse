//
//  AuthService.swift
//  FynVerse
//
//  Created by zubair ahmed on 13/07/25.
//

import Foundation
import FirebaseAuth

struct AuthDataResultModel{
    let uid:String
    let email:String?
    let photoUrl:String?
    
    init(user:User) {
        self.uid = user.uid
        self.email = user.email
        self.photoUrl = user.photoURL?.absoluteString
    }
}

final class AuthService{
    static let shared = AuthService()
    
    private init(){}
    

    func getAuthenticatedUser() throws -> AuthDataResultModel {
        guard let user = Auth.auth().currentUser else {
            throw URLError(.badURL)
        }
        return AuthDataResultModel(user: user)
    }
    func signOut() throws{
       try  Auth.auth().signOut()
    }
   
    

    
    
}
//Google
extension AuthService {
    @discardableResult
    func signInWithGoogle(tokens: GoogleSignInResultModel) async throws -> AuthDataResultModel {
        let credential = GoogleAuthProvider.credential(withIDToken: tokens.idToken, accessToken: tokens.accessToken)
        return try await signIn(credential: credential)
    }
    
    @discardableResult
    func signIn(credential: AuthCredential) async throws -> AuthDataResultModel {
        let result = try await Auth.auth().signIn(with: credential)
        return AuthDataResultModel(user: result.user)
    }
}

extension AuthService {
    func createUser(email:String,password:String) async throws -> AuthDataResultModel{
        let authDataResult =  try await Auth.auth().createUser(withEmail: email, password: password)
        
        return AuthDataResultModel(user: authDataResult.user)
    }
    
    func signInUser(email:String,password:String) async throws -> AuthDataResultModel{
        let authDataResult =  try await Auth.auth().signIn(withEmail: email, password: password)
        
        return AuthDataResultModel(user: authDataResult.user)
    }
    
    func resetPassword(email:String) async throws{
        try await Auth.auth().sendPasswordReset(withEmail: email)
        
    }
    func updatePassword(password:String)async throws{
        guard let user = Auth.auth().currentUser else{
            throw URLError(.badServerResponse)
        }
        try await user.updatePassword(to: password)
    }
    func delete () async throws {
        guard let user = Auth.auth().currentUser else{
            throw URLError(.badURL)
        }
        try await user.delete()
    }
}

