import Foundation
import FirebaseFirestore


class PortfolioHistoryService {
    private let db = Firestore.firestore()
    private let collectionName = "portfolioHistory"
    
    // MARK: - Save Daily Portfolio Snapshot
    func saveDailyPortfolioSnapshot(
        userID: String,
        totalInvestment: Double,
        portfolioValue: Double,
        totalGainLoss: Double
    ) async throws {
        let today = Date()
        let dateString = PortfolioHistoryModel.dateFormatter.string(from: today)
        
        // Check if today's record already exists
        let todaysRecord = try await fetchTodaysRecord(userID: userID, date: dateString)
        
        let historyModel = PortfolioHistoryModel(
            date: today,
            totalInvestment: totalInvestment,
            portfolioValue: portfolioValue,
            totalGainLoss: totalGainLoss,
            userID: userID
        )
        
        let userCollection = db.collection("users").document(userID).collection(collectionName)
        
        if let existingRecord = todaysRecord {
            // Update existing record
            try await userCollection
                .document(existingRecord.id)
                .setData(try Firestore.Encoder().encode(historyModel))
        } else {
            // Create new record
            try await userCollection
                .document(historyModel.id)
                .setData(try Firestore.Encoder().encode(historyModel))
        }
    }
    
    // MARK: - Fetch Portfolio History
    func fetchPortfolioHistory(userID: String, days: Int = 365) async throws -> [PortfolioHistoryModel] {
        let startDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        let startDateString = PortfolioHistoryModel.dateFormatter.string(from: startDate)
        
        let snapshot = try await db.collection("users")
            .document(userID)
            .collection(collectionName)
            .whereField("date", isGreaterThanOrEqualTo: startDateString)
            .order(by: "date", descending: false)
            .getDocuments()
        
        return snapshot.documents.compactMap { document in
            try? document.data(as: PortfolioHistoryModel.self)
        }
    }
    
    // MARK: - Private Helper Methods
    private func fetchTodaysRecord(userID: String, date: String) async throws -> PortfolioHistoryModel? {
        let snapshot = try await db.collection("users")
            .document(userID)
            .collection(collectionName)
            .whereField("date", isEqualTo: date)
            .limit(to: 1)
            .getDocuments()
        
        return snapshot.documents.first.flatMap { document in
            try? document.data(as: PortfolioHistoryModel.self)
        }
    }
    
    // MARK: - Delete Old Records (Optional cleanup)
    func deleteOldRecords(userID: String, olderThanDays: Int = 730) async throws {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -olderThanDays, to: Date()) ?? Date()
        let cutoffDateString = PortfolioHistoryModel.dateFormatter.string(from: cutoffDate)
        
        let snapshot = try await db.collection("users")
            .document(userID)
            .collection(collectionName)
            .whereField("date", isLessThan: cutoffDateString)
            .getDocuments()
        
        let batch = db.batch()
        for document in snapshot.documents {
            batch.deleteDocument(document.reference)
        }
        
        try await batch.commit()
    }
}
