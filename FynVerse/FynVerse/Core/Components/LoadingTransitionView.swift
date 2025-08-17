import SwiftUI

struct LoadingTransitionView: View {
    @State private var isActive = false
    @ObservedObject var authvm: AuthViewModel
    
    var body: some View {
        if isActive {
            MainTabView( authvm: authvm) // Your main app view
        } else {
            VStack {
                Spacer()
                
                // App logo
                Image("AppLogo") // Make sure "AppLogo" matches your Assets name
                    .resizable()
                    .scaledToFit()
                    .frame(width: 120, height: 120)
                    .cornerRadius(24)
                
                Spacer()
                
                ProgressView("Loading...")
                    .progressViewStyle(CircularProgressViewStyle(tint: .green))
                    .font(.headline)
                    .padding(.bottom, 50)
            }
            .onAppear {
                // Delay before showing main app
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    withAnimation {
                        isActive = true
                    }
                }
            }
        }
    }
}
