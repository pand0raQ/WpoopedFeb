import Foundation
import FirebaseFirestore
import SwiftData

/// A manager class that handles Firebase sharing functionality for the app
@MainActor
class FirebaseSharingManager {
    static let shared = FirebaseSharingManager()
    
    private let db: Firestore
    private let urlGenerator = SharingURLGenerator.shared
    
    private init() {
        self.db = Firestore.firestore()
    }
    
    /// Shares a Dog record with other users by creating a share document in Firestore
    /// - Parameters:
    ///   - dog: The Dog object to be shared
    ///   - email: The email of the user to share with
    /// - Returns: A sharing URL that can be sent to the recipient
    /// - Throws: Firestore errors if sharing fails
    func shareDog(_ dog: Dog, withEmail email: String) async throws -> URL {
        print("🔄 Starting share process for dog: \(dog.name ?? "Unknown")")
        
        // Check if share already exists
        if let shareRecordID = dog.shareRecordID {
            print("📤 Fetching existing share for dog")
            do {
                let shareDoc = try await db.collection("shares").document(shareRecordID).getDocument()
                if shareDoc.exists {
                    print("✅ Found existing share")
                    if let shareURL = dog.shareURL, let url = URL(string: shareURL) {
                        return url
                    } else {
                        return urlGenerator.generateSharingURL(shareID: shareRecordID)
                    }
                }
            } catch {
                print("⚠️ Error fetching existing share: \(error.localizedDescription)")
            }
        }
        
        // Create new share
        let shareID = UUID().uuidString
        let shareData: [String: Any] = [
            "dogID": dog.id?.uuidString ?? "",
            "dogName": dog.name ?? "Shared Dog",
            "sharedByEmail": AuthManager.shared.currentUser()?.email ?? "",
            "sharedWithEmail": email,
            "sharedAt": Date(),
            "isAccepted": false
        ]
        
        // Save share document
        try await db.collection("shares").document(shareID).setData(shareData)
        print("✅ Share document created successfully")
        
        // Update dog with share information
        dog.isShared = true
        dog.shareRecordID = shareID
        
        // Generate a sharing URL
        let sharingURL = urlGenerator.generateSharingURL(shareID: shareID)
        dog.shareURL = sharingURL.absoluteString
        
        // Update the dog in Firestore
        try await FirestoreManager.shared.updateDog(dog)
        print("✅ Dog updated with share information")
        
        return sharingURL
    }
    
    /// Gets share metadata information from a share ID
    /// - Parameter shareID: The share ID
    /// - Returns: A tuple containing the share metadata (dogName, ownerName)
    /// - Throws: Firestore errors if metadata fetch fails
    func getShareMetadata(shareID: String) async throws -> (dogName: String, ownerName: String) {
        print("🔍 Getting share metadata for ID: \(shareID)")
        
        let shareDoc = try await db.collection("shares").document(shareID).getDocument()
        
        guard let data = shareDoc.data(),
              let dogName = data["dogName"] as? String,
              let ownerName = data["sharedByEmail"] as? String else {
            throw FirestoreError.invalidShareData
        }
        
        return (dogName: dogName, ownerName: ownerName)
    }
    
    /// Accepts a shared dog
    /// - Parameters:
    ///   - shareID: The ID of the share to accept
    ///   - context: The SwiftData context
    /// - Throws: Firestore errors if share acceptance fails
    func acceptShare(shareID: String, context: ModelContext) async throws {
        print("🔄 Starting share acceptance process...")
        
        // Get the share document
        let shareDoc = try await db.collection("shares").document(shareID).getDocument()
        
        guard let shareData = shareDoc.data(),
              let dogID = shareData["dogID"] as? String,
              let sharedByEmail = shareData["sharedByEmail"] as? String else {
            throw FirestoreError.invalidShareData
        }
        
        print("👤 Share owner: \(sharedByEmail)")
        
        // Mark the share as accepted
        try await db.collection("shares").document(shareID).updateData([
            "isAccepted": true,
            "acceptedAt": Date()
        ])
        
        // Get the dog document
        let dogDoc = try await db.collection("dogs").document(dogID).getDocument()
        let dog = try await Dog.fromFirestoreDocument(dogDoc)
        
        // Mark the dog as a shared dog for this user
        dog.isShared = true
        dog.isShareAccepted = true
        dog.shareRecordID = shareID
        dog.shareOwnerName = sharedByEmail
        
        // Add the dog to the local context
        context.insert(dog)
        
        // Post notification that a share was accepted
        NotificationCenter.default.post(name: .shareAccepted, object: nil, userInfo: ["dog": dog])
        
        print("✅ Share accepted successfully")
    }
}

// MARK: - Notification Extension
extension Notification.Name {
    static let shareAccepted = Notification.Name("shareAccepted")
}
