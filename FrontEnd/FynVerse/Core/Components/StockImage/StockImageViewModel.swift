import Foundation
import SwiftUI
import FirebaseFirestore

@MainActor
final class StockImageViewModel: ObservableObject {
    let stock: StockModel
    private let manager = ImageDataService.shared

    @Published var image: UIImage? = nil
    @Published var isLoading: Bool = false
    @Published var logoURL: String? = nil

    init(stock: StockModel) {
        self.stock = stock
    }

    func getStockImage() async {
        isLoading = true
        defer { isLoading = false }

        // Step 1: Try Fetching URL from Firestore Cache
        if let cachedURL = await fetchStockImageUrlFromFirestore(symbol: stock.SYMBOL) {
            logoURL = cachedURL
            
        } else {
            // Step 2: Fetch from API
            do {
                logoURL = try await manager.fetchFirstLogoImage(for: stock.SYMBOL)
                if let fetchedURL = logoURL {
                    
                    await uploadStocksImageUrl(fetchedURL)
                } else {
                    
                    return
                }
            } catch {
                
                return
            }
        }

        // Step 3: Download Image from URL
        guard let validURL = logoURL else {
            
            return
        }

        do {
            image = try await manager.fetchImage(from: validURL)
            
        } catch {
            
        }
    }

    func uploadStocksImageUrl(_ imageUrl: String) async {
        let db = Firestore.firestore()
        do {
            let data = ["url": imageUrl]
            try await db.collection("stocksImageCache")
                .document(stock.SYMBOL)
                .setData(data, merge: false)
            
        } catch {
            
        }
    }

    func fetchStockImageUrlFromFirestore(symbol: String) async -> String? {
        let db = Firestore.firestore()
        do {
            let document = try await db.collection("stocksImageCache").document(symbol).getDocument()
            if let data = document.data(),
               let url = data["url"] as? String {
                return url
            } else {
                
                return nil
            }
        } catch {
            
            return nil
        }
    }
}
