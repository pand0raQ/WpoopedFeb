import SwiftUI
import SwiftData

@MainActor
class ProfileViewModel: ObservableObject {
    private let authManager = AuthManager.shared
    private let modelContext: ModelContext
    
    @Published var userDetails: AuthManager.UserData?
    @Published var alertItem: AlertItem?
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        Task {
            await fetchUserData()
        }
    }
    
    func fetchUserData() async {
        userDetails = authManager.currentUser()
    }
    
    func signOut() {
        Task {
            await authManager.signOut()
        }
    }
    
    func deleteAllUserData() async {
        do {
            // Delete all local data
            try await deleteLocalData()
            // Sign out
            await authManager.signOut()
        } catch {
            alertItem = AlertItem(
                title: "Error",
                message: "Failed to delete user data: \(error.localizedDescription)"
            )
        }
    }
    
    private func deleteLocalData() async throws {
        // Delete all dogs
        let dogsDescriptor = FetchDescriptor<Dog>()
        let dogs = try modelContext.fetch(dogsDescriptor)
        for dog in dogs {
            modelContext.delete(dog)
        }
        
        // Clear UserDefaults
        if let bundleID = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bundleID)
        }
    }
} 