import SwiftUI

struct ProfileView: View {

    @StateObject var vm = ProfileViewModel(
        authVM: AuthViewModel(),
        trxnVM: TransactionViewModel()
    )

    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.theme.background.ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 28) {
                        
                        // MARK: Header
                        Text("My Profile")
                            .font(.largeTitle.bold())
                            .foregroundColor(Color.theme.accent)
                            .padding(.top, 16)
                        
                        // MARK: Profile Card
                        HStack(spacing: 16) {
                            Group {
                                if let image = vm.profileImage {
                                    Image(uiImage: image)
                                        .resizable()
                                        .scaledToFill()
                                } else {
                                    Image(systemName: "person.crop.circle.fill")
                                        .resizable()
                                        .scaledToFit()
                                        .foregroundColor(.gray)
                                }
                            }
                            .frame(width: 70, height: 70)
                            .clipShape(Circle())
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(vm.userFullName)
                                    .font(.title2.weight(.semibold))
                                    .foregroundColor(Color.theme.accent)
                                
                                Text(vm.investingSince)
                                    .font(.subheadline)
                                    .foregroundColor(Color.theme.secondary)
                            }
                            Spacer()
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color.theme.cardBackground)
                                .shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
                        
                        // MARK: Navigation Links
                        VStack(spacing: 16) {
                            NavigationLink {
                                SettingsView()
                            } label: {
                                ProfileNavCell(icon: "gearshape", title: "Settings")
                            }
                            NavigationLink {
                                TransactionView()
                            } label: {
                                ProfileNavCell(icon: "arrow.left.arrow.right", title: "Transactions")
                            }
                            NavigationLink {
                                PnLReport(vm: vm.transactionsVM)
                            } label: {
                                ProfileNavCell(icon: "chart.line.uptrend.xyaxis", title: "Profit/loss report")
                            }
                            NavigationLink {
                                ChatView()
                            } label: {
                                ProfileNavCell(icon: "questionmark.circle", title: "Help & Support")
                            }
                        }
                        
                        Spacer()
                    }
                    .padding(.horizontal)
                }
                .task {
                    await vm.loadProfileData()
                }
                .alert("Enter your full name", isPresented: $vm.isAskingName) {
                    TextField("Full Name", text: $vm.tempName)
                    Button("Save") {
                        Task { await vm.saveName() }
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - ProfileNavCell
struct ProfileNavCell: View {
    let icon: String
    let title: String
    var body: some View {
        HStack {
            Image(systemName: icon)
            Text(title)
        }
        .font(.headline)
        .foregroundColor(Color.theme.accent)
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.theme.cardBackground)
                .shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)
        )
        .clipShape(RoundedRectangle(cornerRadius: 15))
    }
}
