
import SwiftUI
struct SearchBarView: View {
    @Binding var searchText: String // Added binding for text input
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Color.theme.secondary)
            
            TextField("Search by name or symbol...", text: $searchText) // Text field for input
                .foregroundColor(Color.theme.accent) // Use primaryText for input
                .autocorrectionDisabled()
            
            // Clear button only visible if text is not empty
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Color.theme.secondary)
                }
            }
        }
        .font(.subheadline)
        .padding(.vertical, 12)
        .padding(.horizontal)
        .background(
            Capsule()
                .fill(Color.theme.cardBackground)
                .shadow(color: .black.opacity(0.08), radius: 6, x: 0, y: 2)
            )
    }
}
