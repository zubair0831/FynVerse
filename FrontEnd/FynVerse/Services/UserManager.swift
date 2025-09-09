import Foundation
import FirebaseFirestore


// MARK: - PLACEHOLDER STRUCT
// This is a placeholder to make the code compile.
// Replace this with your actual AuthDataResultModel from your authentication setup.


// MARK: - DATA MODELS
struct DBPortfolioStock: Codable, Identifiable {
    @DocumentID var id: String?
    let stockSymbol: String
    let quantity: Int
    let avgBuyPrice: Double
    let lastUpdated: Timestamp
    
    enum CodingKeys: String, CodingKey {
        case id
        case stockSymbol = "stock_symbol"
        case quantity
        case avgBuyPrice = "avg_buy_price"
        case lastUpdated = "last_updated"
    }
}

struct DBTransaction: Codable, Identifiable,Hashable {
    @DocumentID var id: String?
    let stockSymbol: String
    let transactionType: String
    let quantity: Int
    let pricePerShare: Double
    let timestamp: Timestamp
    
    enum CodingKeys: String, CodingKey {
        case id
        case stockSymbol = "stock_symbol"
        case transactionType = "transaction_type"
        case quantity
        case pricePerShare = "price_per_share"
        case timestamp
    }
}

struct DBUser: Codable {
    var userID: String
    var fullName: String? 
    let email: String?
    let photoURL: String?
    let dateCreatedTimestamp: Timestamp?
    var dateCreated: Date? {
        dateCreatedTimestamp?.dateValue()
    }
    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case email
        case photoURL = "photo_url"
        case fullName = "fullName"  
        case dateCreatedTimestamp = "date_created_timestamp"
    }
    
    init(auth: AuthDataResultModel) {
        self.userID = auth.uid
        self.email = auth.email
        self.photoURL = auth.photoUrl
        self.dateCreatedTimestamp = Timestamp(date: Date())
    }
}

// MARK: - FIRESTORE MANAGER
final class UserManager {
    static let shared = UserManager()
    private init() {}
    
    private func userDocument(userID: String) -> DocumentReference {
        return Firestore.firestore().collection("users").document(userID)
    }

    func createNewUser(user: DBUser) async throws {
        do {
            try userDocument(userID: user.userID)
                .setData(from: user, merge: true)
        } catch {
            throw error
        }
    }

    func getUser(userID: String) async throws -> DBUser? {
        do {
            let documentSnapshot = try await userDocument(userID: userID).getDocument()
            guard documentSnapshot.exists else { return nil }
            let user = try documentSnapshot.data(as: DBUser.self)
            return user
        } catch {
            throw error
        }
    }

    // This function has been updated to use the older, synchronous `runTransaction` closure.
    // The async/await version may not be available in your current SDK setup.
    func performBuyTransaction(
        userID: String,
        stockSymbol: String,
        quantity: Int,
        pricePerShare: Double
    ) async throws {
        // The closure now takes a transaction and an NSErrorPointer.
        // The return type is Any?
       _ = try await Firestore.firestore().runTransaction { (transaction, errorPointer) -> Any? in
            do {
                let userDocRef = Firestore.firestore().collection("users").document(userID)
                let portfolioDocRef = userDocRef.collection("portfolio").document(stockSymbol)
                
                let portfolioDoc = try transaction.getDocument(portfolioDocRef)
                
                var newQuantity: Int
                var newAvgBuyPrice: Double
                
                if portfolioDoc.exists {
                    let oldPortfolio = try portfolioDoc.data(as: DBPortfolioStock.self)
                    newQuantity = oldPortfolio.quantity + quantity
                    
                    let oldTotalValue = oldPortfolio.avgBuyPrice * Double(oldPortfolio.quantity)
                    let newPurchaseValue = pricePerShare * Double(quantity)
                    let newTotalValue = oldTotalValue + newPurchaseValue
                    newAvgBuyPrice = newTotalValue / Double(newQuantity)
                } else {
                    newQuantity = quantity
                    newAvgBuyPrice = pricePerShare
                }
                
                let updatedPortfolio = DBPortfolioStock(
                    stockSymbol: stockSymbol,
                    quantity: newQuantity,
                    avgBuyPrice: newAvgBuyPrice,
                    lastUpdated: Timestamp()
                )
                
                try transaction.setData(from: updatedPortfolio, forDocument: portfolioDocRef)
                
                let newTransaction = DBTransaction(
                    stockSymbol: stockSymbol,
                    transactionType: "BUY",
                    quantity: quantity,
                    pricePerShare: pricePerShare,
                    timestamp: Timestamp()
                )
                
                let newTransactionDocRef = userDocRef.collection("transactions").document()
                try transaction.setData(from: newTransaction, forDocument: newTransactionDocRef)
                
                return nil // Return nil on success
            } catch let error as NSError {
                errorPointer?.pointee = error // Set the error pointer
                return nil
            }
        }
    }
    
    // This function has also been updated to use the older, synchronous `runTransaction` closure.
    func performSellTransaction(
        userID: String,
        stockSymbol: String,
        quantity: Int,
        pricePerShare: Double
    ) async throws {
        // The closure now takes a transaction and an NSErrorPointer.
        // The return type is Any?
       _ = try await Firestore.firestore().runTransaction { (transaction, errorPointer) -> Any? in
            do {
                let userDocRef = Firestore.firestore().collection("users").document(userID)
                let portfolioDocRef = userDocRef.collection("portfolio").document(stockSymbol)
                
                let portfolioDoc = try transaction.getDocument(portfolioDocRef)
                
                guard portfolioDoc.exists else {
                    let error = NSError(domain: "AppErrorDomain", code: 404, userInfo: [NSLocalizedDescriptionKey: "Stock not found in portfolio."])
                    errorPointer?.pointee = error
                    return nil
                }
                
                let oldPortfolio = try portfolioDoc.data(as: DBPortfolioStock.self)
                
                guard oldPortfolio.quantity >= quantity else {
                    let error = NSError(domain: "AppErrorDomain", code: 400, userInfo: [NSLocalizedDescriptionKey: "Not enough shares to sell."])
                    errorPointer?.pointee = error
                    return nil
                }
                
                let newQuantity = oldPortfolio.quantity - quantity
                
                if newQuantity == 0 {
                    transaction.deleteDocument(portfolioDocRef)
                } else {
                    let updatedPortfolio = DBPortfolioStock(
                        stockSymbol: stockSymbol,
                        quantity: newQuantity,
                        avgBuyPrice: oldPortfolio.avgBuyPrice,
                        lastUpdated: Timestamp()
                    )
                    try transaction.setData(from: updatedPortfolio, forDocument: portfolioDocRef)
                }
                
                let newTransaction = DBTransaction(
                    stockSymbol: stockSymbol,
                    transactionType: "SELL",
                    quantity: quantity,
                    pricePerShare: pricePerShare,
                    timestamp: Timestamp()
                )
                let newTransactionDocRef = userDocRef.collection("transactions").document()
                try transaction.setData(from: newTransaction, forDocument: newTransactionDocRef)
                
                return nil // Return nil on success
            } catch let error as NSError {
                errorPointer?.pointee = error // Set the error pointer
                return nil
            }
        }
    }
    
    func getUserPortfolio(userID: String) async throws -> [DBPortfolioStock] {
        let snapshot = try await userDocument(userID: userID)
            .collection("portfolio")
            .getDocuments()
            
        return snapshot.documents.compactMap { document in
            try? document.data(as: DBPortfolioStock.self)
        }
    }
    
    func getUserTransactions(userID: String) async throws -> [DBTransaction] {
        let snapshot = try await userDocument(userID: userID)
            .collection("transactions")
            .getDocuments()
            
        return snapshot.documents.compactMap { document in
            try? document.data(as: DBTransaction.self)
        }
    }
}
