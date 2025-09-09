import SwiftUI
struct InfoCell: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(Color.theme.secondary)
                .lineLimit(1)
            Text(value)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(Color.theme.accent)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.theme.secondary.opacity(0.1))
        .cornerRadius(12)
    }
}
