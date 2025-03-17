import SwiftUI
import SwiftData

@MainActor
class ProfileViewModel: ObservableObject {
    private let authManager = AuthManager.shared
    private let modelContext: ModelContext
    
    @Published var userDetails: User?
    @Published var alertItem: AlertItem?
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        fetchUserData()
    }
    
    func fetchUserData() {
        userDetails = authManager.currentUser()
    }
    
    func signOut() {
        do {
            try authManager.signOut()
        } catch {
            alertItem = AlertItem(
                title: "Error",
                message: "Failed to sign out: \(error.localizedDescription)"
            )
        }
    }
    
    func deleteAllUserData() async {
        do {
            // Delete all local data
            try await deleteLocalData()
            // Sign out
            try authManager.signOut()
        } catch {
            alertItem = AlertItem(
                title: "Error",
                message: "Failed to delete user data: \(error.localizedDescription)"
            )
        }
    }
    
    private func deleteLocalData() async throws {
        // Delete all dogs from Firestore first
        let dogsDescriptor = FetchDescriptor<Dog>()
        let dogs = try modelContext.fetch(dogsDescriptor)
        for dog in dogs {
            if !(dog.isShared ?? false) {  // Handle optional Bool with nil-coalescing
                do {
                    try await FirestoreManager.shared.deleteDog(dog)
                } catch {
                    print("Error deleting dog from Firestore: \(error.localizedDescription)")
                    // Continue with other dogs even if one fails
                }
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