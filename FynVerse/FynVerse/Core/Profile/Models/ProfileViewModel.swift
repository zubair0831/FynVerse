import SwiftUI


class ProfileViewModel: ObservableObject {
    @Published var profileImage: UIImage? = nil
    @Published var isAskingName = false
    @Published var tempName = ""
    
    @Published var userFullName: String = "—"
    @Published var investingSince: String = "—"
    
    private let authVM: AuthViewModel
    private let trxnVM: TransactionViewModel
    
    init(authVM: AuthViewModel, trxnVM: TransactionViewModel) {
        self.authVM = authVM
        self.trxnVM = trxnVM
    }

    
    var transactionsVM: TransactionViewModel { trxnVM }
    
    /// Load profile and check if name or image needs updating
    @MainActor
    func loadProfileData() async {
        do {
            try await authVM.loadCurrentUser()
            
            if let fullName = authVM.user?.fullName,
               !fullName.trimmingCharacters(in: .whitespaces).isEmpty {
                userFullName = fullName
            } else {
                userFullName = "—"
                if !authVM.hasAskedForName {
                    isAskingName = true
                }
            }
            
            if let date = authVM.user?.dateCreated {
                investingSince = "Investing Since \(date.formatted(.dateTime.month().year()))"
            }
            
            if let urlString = authVM.user?.photoURL,
               let url = URL(string: urlString) {
                let (data, response) = try await URLSession.shared.data(from: url)
                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200,
                   let uiImage = UIImage(data: data) {
                    profileImage = uiImage
                }
            }
        } catch {
            print("❌ Error loading profile: \(error)")
        }
    }
    @MainActor
    func saveName() async {
        let name = tempName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        do {
            try await authVM.updateUserName(name)
            userFullName = name
            isAskingName = false
        } catch {
            print("❌ Failed to save name: \(error)")
        }
    }
}
