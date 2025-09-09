import SwiftUI

enum SettingsDestination: Hashable {
    case resetPassword
}
//Test

@MainActor
struct SettingsView: View {
    @AppStorage("isLoggedIn") private var isLoggedIn: Bool = false
    @StateObject var vm: AuthViewModel = AuthViewModel()
    @State private var path: [SettingsDestination] = []
    
    var body: some View {
        NavigationStack(path: $path) {   
            ZStack {
                // Background Color
                Color.theme.background.ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 32) {
                        
                        Button(action: {
                            vm.logout()
                        }) {
                            Label("Log Out", systemImage: "rectangle.portrait.and.arrow.right")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.red)
                        .controlSize(.large)

                        Button(action: {
                            path.append(.resetPassword) // ✅ works now
                        }) {
                            Label("Update Password", systemImage: "key.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        
                        Button(role: .destructive) {
                            Task { try? await vm.updatePassword() }
                        } label: {
                            Label("Delete Account", systemImage: "trash.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                    }
                    .padding()
                }
            }
            .navigationDestination(for: SettingsDestination.self) { destination in
                switch destination {
                case .resetPassword:
                    ResetPasswordView()
                }
            }
        }
    }
}

#Preview {
    SettingsView()
}
