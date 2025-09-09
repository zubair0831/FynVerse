
import Foundation

// MARK: - Main Response
struct StocksNewsResponse: Codable {
    let symbol: String
    let news: [NewsItem]
}

// MARK: - News Item
struct NewsItem: Codable, Identifiable {
    let id: String
    let content: NewsContent
}

// MARK: - News Content
struct NewsContent: Codable {
    let id: String
    let contentType: String
    let title: String
    let description: String?
    let summary: String
    let pubDate: String
    let displayTime: String
    let isHosted: Bool
    let bypassModal: Bool
    let previewUrl: String?
    let thumbnail: NewsThumbnail?
    let provider: NewsProvider
    let canonicalUrl: NewsURL?
    let clickThroughUrl: NewsURL?
    let metadata: NewsMetadata?
    let finance: NewsFinance?
    let storyline: String?
    
    // Computed property for formatted date
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
        
        if let date = formatter.date(from: pubDate) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .medium
            displayFormatter.timeStyle = .short
            return displayFormatter.string(from: date)
        }
        return pubDate
    }
    
    // Computed property for relative time
    var relativeTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
        
        if let date = formatter.date(from: pubDate) {
            let now = Date()
            let timeInterval = now.timeIntervalSince(date)
            
            let hours = Int(timeInterval / 3600)
            let days = Int(timeInterval / 86400)
            
            if days > 0 {
                return "\(days)d ago"
            } else if hours > 0 {
                return "\(hours)h ago"
            } else {
                let minutes = Int(timeInterval / 60)
                return "\(max(1, minutes))m ago"
            }
        }
        return "Recently"
    }
}

// MARK: - Supporting Structures
struct NewsThumbnail: Codable {
    let originalUrl: String?
    let originalWidth: Int?
    let originalHeight: Int?
    let caption: String?
    let resolutions: [ThumbnailResolution]?
}

struct ThumbnailResolution: Codable {
    let url: String
    let width: Int
    let height: Int
    let tag: String
}

struct NewsProvider: Codable {
    let displayName: String
    let url: String?
}

struct NewsURL: Codable {
    let url: String
    let site: String?
    let region: String?
    let lang: String?
}

struct NewsMetadata: Codable {
    let editorsPick: Bool?
}

struct NewsFinance: Codable {
    let premiumFinance: PremiumFinanceInfo?
}

struct PremiumFinanceInfo: Codable {
    let isPremiumNews: Bool?
    let isPremiumFreeNews: Bool?
}
