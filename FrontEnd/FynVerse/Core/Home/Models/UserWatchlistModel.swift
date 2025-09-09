import Foundation
import FirebaseFirestore // For @DocumentID

struct UserWatchlist: Identifiable, Codable, Hashable {
    @DocumentID var id: String? = UUID().uuidString
    var name: String
    var stockSymbols: [String]

    static func == (lhs: UserWatchlist, rhs: UserWatchlist) -> Bool {
        lhs.id == rhs.id && lhs.name == rhs.name && lhs.stockSymbols == rhs.stockSymbols
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(name)
        hasher.combine(stockSymbols)
    }
}
