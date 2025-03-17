import Foundation
import FirebaseFirestore
import FirebaseAuth
import SwiftUI

// Enum for Firestore error types
enum FirestoreErrorType {
    case permissionDenied
    case networkError
    case documentNotFound
    case unknown
    
    var userFriendlyMessage: String {
        switch self {
        case .permissionDenied:
            return "Permission denied. Please check your Firebase security rules."
        case .networkError:
            return "Network error. Please check your internet connection and try again."
        case .documentNotFound:
            return "Document not found. The data you're looking for may have been deleted."
        case .unknown:
            return "An unknown error occurred. Please try again later."
        }
    }
}

// Class to handle Firestore errors
class FirestoreErrorHandler {
    static func getErrorType(from error: Error) -> FirestoreErrorType {
        let nsError = error as NSError
        
        if nsError.domain == FirestoreErrorDomain {
            if nsError.localizedDescription.contains("permission") || 
               nsError.localizedDescription.contains("Missing or insufficient permissions") {
                return .permissionDenied
            } else if nsError.localizedDescription.contains("network") || 
                      nsError.localizedDescription.contains("connection") {
                return .networkError
            } else if nsError.localizedDescription.contains("not found") || 
                      nsError.localizedDescription.contains("No document to update") {
                return .documentNotFound
            }
        }
        
        return .unknown
    }
    
    static func handleError(_ error: Error) -> String {
        let errorType = getErrorType(from: error)
        print("🔄 Firestore error: \(error.localizedDescription)")
        print("🔄 Error type: \(errorType)")
        return errorType.userFriendlyMessage
    }
}

// Extension to handle Firestore errors gracefully
extension FirestoreManager {
    // Create sample dogs for offline mode
    func createSampleDogs() -> [Dog] {
        print("🔄 Creating sample dogs for offline mode")
        
        let currentUserID = AuthManager.shared.currentUser()?.id ?? "offline-user"
        
        // Create a fixed set of sample dogs with consistent IDs to prevent duplicates
        let sampleDog1 = Dog(name: "Sample Dog 1", ownerID: currentUserID, shouldSaveToFirestore: false)
        let sampleDog2 = Dog(name: "Sample Dog 2", ownerID: currentUserID, shouldSaveToFirestore: false)
        
        // Set fixed UUIDs for sample dogs to prevent duplicates
        sampleDog1.id = UUID(uuidString: "00000000-0000-0000-0000-000000000001")
        sampleDog2.id = UUID(uuidString: "00000000-0000-0000-0000-000000000002")
        
        return [sampleDog1, sampleDog2]
    }
    
    // Fetch dogs with fallback to sample data
    func fetchDogsWithFallback() async -> [Dog] {
        do {
            return try await fetchDogs()
        } catch let error as NSError {
            // Check if this is a permissions error
            if error.domain == FirestoreErrorDomain && 
               (error.code == 7 || // PERMISSION_DENIED
                error.localizedDescription.contains("Missing or insufficient permissions")) {
                
                print("⚠️ Firestore permission error: \(error.localizedDescription)")
                print("⚠️ Using sample dogs due to permission error. Please update your Firebase security rules.")
                
                // Show instructions for updating Firebase rules
                DispatchQueue.main.async {
                    NotificationCenter.default.post(
                        name: .firestorePermissionError,
                        object: nil,
                        userInfo: ["error": error]
                    )
                }
                
                return createSampleDogs()
            } else {
                print("⚠️ Using sample dogs due to error: \(error.localizedDescription)")
                return createSampleDogs()
            }
        }
    }
    
    // Helper method to check if the user is properly authenticated with Firebase
    func checkFirebaseAuthentication() -> Bool {
        if let _ = Auth.auth().currentUser {
            return true
        }
        return false
    }
    
    // Helper method to retry a Firestore operation with Firebase reauthentication
    func retryWithReauthentication<T>(operation: @escaping () async throws -> T) async throws -> T {
        do {
            return try await operation()
        } catch let error as NSError where error.domain == FirestoreErrorDomain && 
                                          (error.code == 7 || 
                                           error.localizedDescription.contains("Missing or insufficient permissions")) {
            // Try to reauthenticate with Firebase
            if let user = AuthManager.shared.currentUser() {
                print("🔄 Attempting to reauthenticate with Firebase before retrying operation")
                
                // Force auth state update
                AuthDebugger.shared.forceUpdateAuthState()
                
                // Wait a moment for auth to process
                try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                
                // Try the operation again
                return try await operation()
            } else {
                throw error
            }
        }
    }
}

// Add notification name for Firestore permission errors
extension Notification.Name {
    static let firestorePermissionError = Notification.Name("firestorePermissionError")
} 