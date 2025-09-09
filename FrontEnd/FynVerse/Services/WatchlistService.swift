
//
//  WatchlistService.swift
//  FynVerse
//

import Foundation
import FirebaseFirestore


struct WatchlistService {
    private let db = Firestore.firestore()
    
    func fetchUserWatchlists(userID: String) async throws -> [UserWatchlist] {
        let snapshot = try await db.collection("users")
            .document(userID)
            .collection("watchlists")
            .getDocuments()
        
        return snapshot.documents.compactMap { try? $0.data(as: UserWatchlist.self) }
    }
    
    func addWatchlist(userID: String, name: String) async throws -> UserWatchlist {
        let newWatchlist = UserWatchlist(name: name, stockSymbols: [])
        let docRef = try db.collection("users")
            .document(userID)
            .collection("watchlists")
            .addDocument(from: newWatchlist)
        
        var added = newWatchlist
        added.id = docRef.documentID
        return added
    }
    
    func updateWatchlist(userID: String, watchlist: UserWatchlist) throws {
        guard let id = watchlist.id else { return }
        try db.collection("users")
            .document(userID)
            .collection("watchlists")
            .document(id)
            .setData(from: watchlist, merge: false)
    }
    
    func deleteWatchlist(userID: String, watchlistID: String) async throws {
        try await db.collection("users")
            .document(userID)
            .collection("watchlists")
            .document(watchlistID)
            .delete()
    }
}
