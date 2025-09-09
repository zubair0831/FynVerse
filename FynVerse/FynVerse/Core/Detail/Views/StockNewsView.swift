
import SwiftUI

struct StockNewsView: View {
    @StateObject private var viewModel = NewsViewModel()
    let symbol: String
    
    var body: some View {
        VStack(spacing: 0) {
            if viewModel.isLoading {
                loadingView
            } else if viewModel.hasError {
                errorView
            } else if viewModel.newsItems.isEmpty {
                emptyStateView
            } else {
                newsListView
            }
        }
        .task {
            await viewModel.fetchNews(symbol: symbol)
        }
        .refreshable {
            await viewModel.fetchNews(symbol: symbol)
        }
    }
    
    // MARK: - Loading View
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: Color.theme.accent))
                .scaleEffect(1.2)
            
            Text("Fetching latest news...")
                .font(.subheadline)
                .foregroundColor(Color.theme.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.theme.background)
    }
    
    // MARK: - Error View
    private var errorView: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 50))
                .foregroundColor(.orange)
            
            Text("Unable to load news")
                .font(.headline)
                .foregroundColor(Color.theme.accent)
            
            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.subheadline)
                    .foregroundColor(Color.theme.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            Button("Try Again") {
                viewModel.retryFetch(symbol: symbol)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.theme.accent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.theme.background)
    }
    
    // MARK: - Empty State View
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "newspaper")
                .font(.system(size: 50))
                .foregroundColor(Color.theme.secondary)
            
            Text("No News Available")
                .font(.headline)
                .foregroundColor(Color.theme.accent)
            
            Text("There are currently no news articles available for \(symbol)")
                .font(.subheadline)
                .foregroundColor(Color.theme.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button("Refresh") {
                viewModel.retryFetch(symbol: symbol)
            }
            .buttonStyle(.bordered)
            .tint(Color.theme.accent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.theme.background)
    }
    
    // MARK: - News List View
    private var newsListView: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(viewModel.newsItems) { newsItem in
                    NewsCardView(newsItem: newsItem)
                        .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
        .background(Color.theme.background)
    }
}

// MARK: - Individual News Card
struct NewsCardView: View {
    let newsItem: NewsItem
    @State private var showingFullSummary = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with provider and time
            HStack {
                Text(newsItem.content.provider.displayName)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(Color.theme.accent)
                
                Spacer()
                
                Text(newsItem.content.relativeTime)
                    .font(.caption)
                    .foregroundColor(Color.theme.secondary)
            }
            
            // Title
            Text(newsItem.content.title)
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(Color.theme.accent)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
            
            // Thumbnail if available
            if let thumbnail = newsItem.content.thumbnail,
               let resolution = thumbnail.resolutions?.first,
               let imageURL = URL(string: resolution.url) {
                
                AsyncImage(url: imageURL) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .overlay(
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: Color.theme.accent))
                        )
                }
                .frame(height: 120)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            
            // Summary
            if !newsItem.content.summary.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text(showingFullSummary ? newsItem.content.summary : String(newsItem.content.summary.prefix(200)))
                        .font(.subheadline)
                        .foregroundColor(Color.theme.secondary)
                        .multilineTextAlignment(.leading)
                    
                    if newsItem.content.summary.count > 200 {
                        Button(showingFullSummary ? "Show Less" : "Read More") {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                showingFullSummary.toggle()
                            }
                        }
                        .font(.caption)
                        .foregroundColor(Color.theme.accent)
                    }
                }
            }
            
            // Action buttons
            HStack {
                if let canonicalURL = newsItem.content.canonicalUrl,
                   let url = URL(string: canonicalURL.url) {
                    Link(destination: url) {
                        HStack(spacing: 4) {
                            Image(systemName: "safari")
                            Text("Read Full Article")
                        }
                        .font(.caption)
                        .foregroundColor(.blue)
                    }
                }
                
                Spacer()
                
                Button(action: {
                    shareNewsItem(newsItem)
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "square.and.arrow.up")
                        Text("Share")
                    }
                    .font(.caption)
                    .foregroundColor(Color.theme.accent)
                }
            }
        }
        .padding()
        .background(Color.theme.background)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.theme.secondary.opacity(0.2), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
    
    private func shareNewsItem(_ newsItem: NewsItem) {
        guard let url = newsItem.content.canonicalUrl?.url else { return }
        
        let activityVC = UIActivityViewController(
            activityItems: [newsItem.content.title, URL(string: url)!],
            applicationActivities: nil
        )
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            rootViewController.present(activityVC, animated: true)
        }
    }
}
