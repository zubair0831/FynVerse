import SwiftUI

struct SplashScreenView: View {
    @State private var isActive = false
    @State private var logoScale: CGFloat = 0.8
    @State private var logoOpacity: Double = 0.0
    @State private var textOpacity: Double = 0.0
    @State private var footerOpacity: Double = 0.0
    @ObservedObject var vm:AuthViewModel
    
    var body: some View {
        ZStack {
            // Background Gradient for premium look
            Color.theme.background
            .ignoresSafeArea()
            
            VStack(spacing: 20) {
                Spacer()
                
                GeometryReader { geometry in
                    VStack(spacing: 20) {
                        // Big centered logo
                        Image("AppLogo")
                            .resizable()
                            .scaledToFit()
                            .scaleEffect(logoScale)
                            .opacity(logoOpacity)
                            .onAppear {
                                withAnimation(.easeOut(duration: 1.0)) {
                                    logoScale = 1.0
                                    logoOpacity = 1.0
                                }
                            }
                            .frame(maxWidth: geometry.size.width * 0.65)
                        
                        // App name
                        Text("FynVerse")
                            .font(.system(size: 40, weight: .bold))
                            .foregroundColor(Color.theme.accent)

                            .opacity(textOpacity)
                            .onAppear {
                                withAnimation(.easeIn(duration: 1.0).delay(0.3)) {
                                    textOpacity = 1.0
                                }
                            }
                        
                        // Tagline
                        Text("Empowering Your Investment Journey")
                            .font(.headline)
                            .foregroundColor(Color.theme.secondary)

                            .multilineTextAlignment(.center)
                            .opacity(textOpacity)
                    }
                    .frame(width: geometry.size.width, height: geometry.size.height, alignment: .center)
                }
                .frame(height: 350)
                
                Spacer()
                
                // Footer Info
                VStack(spacing: 5) {
                    Text("FynVerse Pvt. Ltd.")
                        .font(.footnote)
                        .foregroundColor(Color.theme.accent)
                    Text("📧 fynverse@gmail.com")
                        .font(.footnote)
                        .foregroundColor(Color.theme.accent)
                }
                .opacity(footerOpacity)
                .onAppear {
                    withAnimation(.easeIn(duration: 1.0).delay(1.0)) {
                        footerOpacity = 1.0
                    }
                }
                .padding(.bottom, 40)
            }
            .padding(.horizontal)
        }
        .onAppear {
            // Navigate after 2.5 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                withAnimation {
                    isActive = true
                }
            }
        }
        .fullScreenCover(isPresented: $isActive) {
            MainTabView( authvm: vm)
        }
    }
}
