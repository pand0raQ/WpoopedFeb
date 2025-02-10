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
        fetchUserData()
    }
    
    func fetchUserData() {
        userDetails = authManager.currentUser()
    }
    
    func signOut() {
        authManager.signOut()
    }
    
    func deleteAllUserData() async {
        do {
            // Delete all local data
            try await deleteLocalData()
            // Sign out
            authManager.signOut()
        } catch {
            alertItem = AlertItem(
                title: "Error",
                message: "Failed to delete user data: \(error.localizedDescription)"
            )
        }
    }
    
    private func deleteLocalData() async throws {
        // Delete all dogs from CloudKit first
        let dogsDescriptor = FetchDescriptor<Dog>()
        let dogs = try modelContext.fetch(dogsDescriptor)
        for dog in dogs {
            if !(dog.isShared ?? false) {  // Handle optional Bool with nil-coalescing
                try? await CloudKitManager.shared.delete(dog.toCKRecord())
            }
        }
        
        // Then delete from local storage
        for dog in dogs {
            modelContext.delete(dog)
        }
        
        // Clear UserDefaults
        if let bundleID = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bundleID)
        }
    }
} 