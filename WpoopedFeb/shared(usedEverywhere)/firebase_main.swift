import Foundation
import FirebaseCore
import FirebaseFirestore
import FirebaseStorage
import FirebaseAuth
import Combine
import SwiftUI

// MARK: - Firebase Configuration Manager
// This class ensures Firebase is only initialized once
class FirebaseConfigurationManager {
    static let shared = FirebaseConfigurationManager()
    
    private var isConfigured = false
    private var firestore: Firestore
    
    private init() {
        print("📱 Initializing FirebaseConfigurationManager")
        
        // Configure Firebase if it hasn't been configured yet
        if FirebaseApp.app() == nil {
            print("🔥 Firebase not yet configured, configuring now")
            FirebaseApp.configure()
        } else {
            print("🔥 Firebase already configured, reusing existing configuration")
        }
        
        // Get default Firestore instance
        let firestoreInstance = Firestore.firestore()
        
        // Configure Firestore settings - must be done before any other Firestore operations
        // and only if we haven't already configured it
        if !isConfigured {
            do {
                let settings = firestoreInstance.settings
                settings.cacheSizeBytes = 10 * 1024 * 1024  // 10MB cache instead of default 100MB
                settings.isPersistenceEnabled = true  // Keep persistence enabled
                firestoreInstance.settings = settings
                isConfigured = true
                print("✅ Firestore settings configured successfully")
            } catch {
                print("⚠️ Failed to configure Firestore settings: \(error.localizedDescription)")
                // Continue with default settings if configuration fails
            }
        }
        
        self.firestore = firestoreInstance
        print("✅ Firebase configuration manager initialized")
    }
    
    func getFirestore() -> Firestore {
        return firestore
    }
    
    func getStorage() -> Storage {
        return Storage.storage()
    }
}

// MARK: - Firestore Manager Implementation
// Note: Notification extensions are defined in FirebaseNotifications.swift

@MainActor
class FirestoreManager: ObservableObject {
    static var shared = FirestoreManager()
    
    private let db: Firestore
    private let storage: Storage
    
    init() {
        print("📱 Initializing FirestoreManager")
        
        // Use the shared Firebase configuration manager
        let configManager = FirebaseConfigurationManager.shared
        self.db = configManager.getFirestore()
        self.storage = configManager.getStorage()
        
        print("✅ Firestore initialized with shared configuration")
        
        // Set up listeners for changes
        setupListeners()
    }
    
    private func setupListeners() {
        print("🔄 Setting up Firestore listeners")
        // We'll implement specific collection listeners when needed
    }
    
    // MARK: - Document Operations
    
    /// Saves a document to Firestore
    /// - Parameter data: Dictionary containing the data to save
    /// - Parameter collection: The collection to save to
    /// - Parameter documentID: Optional document ID (if nil, Firestore will generate one)
    /// - Returns: The document ID
    /// - Throws: Firestore errors if save fails
    private func saveDocument(_ data: [String: Any], collection: String, documentID: String? = nil) async throws -> String {
        print("💾 Saving document to Firestore collection: \(collection)")
        
        let collectionRef = db.collection(collection)
        let docRef: DocumentReference
        
        // Add timestamp for better synchronization
        var dataWithTimestamp = data
        dataWithTimestamp["_lastUpdated"] = FieldValue.serverTimestamp()
        
        if let documentID = documentID {
            docRef = collectionRef.document(documentID)
            
            // Use merge option to avoid overwriting existing data
            // This is faster and more reliable for concurrent updates
            try await docRef.setData(dataWithTimestamp, merge: true)
        } else {
            // For new documents, we don't need to merge
            docRef = try await collectionRef.addDocument(data: dataWithTimestamp)
        }
        
        print("✅ Document saved successfully with ID: \(docRef.documentID)")
        return docRef.documentID
    }
    
    /// Updates a document in Firestore
    /// - Parameter data: Dictionary containing the data to update
    /// - Parameter collection: The collection to update in
    /// - Parameter documentID: The document ID to update
    /// - Returns: The document ID
    /// - Throws: Firestore errors if update fails
    private func updateDocument(_ data: [String: Any], collection: String, documentID: String) async throws -> String {
        print("🔄 Updating document in Firestore: \(documentID)")
        
        let docRef = db.collection(collection).document(documentID)
        try await docRef.updateData(data)
        
        print("✅ Document updated successfully")
        return documentID
    }
    
    /// Deletes a document from Firestore
    /// - Parameter collection: The collection to delete from
    /// - Parameter documentID: The document ID to delete
    /// - Throws: Firestore errors if delete fails
    private func deleteDocument(collection: String, documentID: String) async throws {
        print("🗑️ Deleting document: \(documentID) from collection: \(collection)")
        try await db.collection(collection).document(documentID).delete()
        print("✅ Document deleted successfully")
    }
    
    // MARK: - Storage Operations
    
    /// Uploads an image to Firebase Storage
    /// - Parameter imageData: The image data to upload
    /// - Parameter path: The path in storage to upload to
    /// - Returns: The download URL for the uploaded image
    /// - Throws: Storage errors if upload fails
    func uploadImage(_ imageData: Data, path: String) async throws -> URL {
        print("📤 Uploading image to Firebase Storage: \(path)")
        
        let storageRef = storage.reference().child(path)
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        
        _ = try await storageRef.putDataAsync(imageData, metadata: metadata)
        let downloadURL = try await storageRef.downloadURL()
        
        print("✅ Image uploaded successfully, URL: \(downloadURL.absoluteString)")
        return downloadURL
    }
    
    /// Downloads an image from Firebase Storage
    /// - Parameter url: The URL of the image to download
    /// - Returns: The image data
    /// - Throws: Storage errors if download fails
    func downloadImage(from url: URL) async throws -> Data {
        print("📥 Downloading image from URL: \(url.absoluteString)")
        
        // If it's a Firebase Storage URL, use the Storage API
        if url.absoluteString.contains("firebasestorage.googleapis.com") {
            let storageRef = storage.reference(forURL: url.absoluteString)
            let maxSize: Int64 = 5 * 1024 * 1024 // 5MB
            let data = try await storageRef.data(maxSize: maxSize)
            print("✅ Image downloaded successfully")
            return data
        } else {
            // Otherwise use URLSession
            let (data, _) = try await URLSession.shared.data(from: url)
            print("✅ Image downloaded successfully")
            return data
        }
    }
    
    // MARK: - Dog Operations
    
    /// Saves a dog to Firestore
    /// - Parameter dog: The dog to save
    /// - Returns: The document ID
    /// - Throws: Firestore errors if save fails
    func saveDog(_ dog: Dog) async throws -> String {
        print("🔄 Saving dog to Firestore: \(dog.name ?? "")")
        
        var data = dog.toFirestoreData()
        
        // Handle image upload if needed
        if let imageData = dog.imageData {
            let imagePath = "dogs/\(dog.id?.uuidString ?? UUID().uuidString).jpg"
            let downloadURL = try await uploadImage(imageData, path: imagePath)
            data["imageURL"] = downloadURL.absoluteString
        }
        
        let documentID = try await saveDocument(data, collection: "dogs", documentID: dog.id?.uuidString)
        
        // Update the dog's record ID if it was newly created
        if dog.recordID == nil {
            dog.recordID = documentID
        }
        
        return documentID
    }
    
    /// Updates a dog in Firestore
    /// - Parameter dog: The dog to update
    /// - Returns: The document ID
    /// - Throws: Firestore errors if update fails
    func updateDog(_ dog: Dog) async throws -> String {
        print("🔄 Updating dog in Firestore: \(dog.name ?? "")")
        
        guard let id = dog.id?.uuidString else {
            throw FirestoreError.invalidDocumentID
        }
        
        var data = dog.toFirestoreData()
        
        // Handle image upload if needed
        if let imageData = dog.imageData {
            let imagePath = "dogs/\(id).jpg"
            let downloadURL = try await uploadImage(imageData, path: imagePath)
            data["imageURL"] = downloadURL.absoluteString
        }
        
        return try await updateDocument(data, collection: "dogs", documentID: id)
    }
    
    /// Deletes a dog from Firestore
    /// - Parameter dog: The dog to delete
    /// - Throws: Firestore errors if delete fails
    func deleteDog(_ dog: Dog) async throws {
        print("🗑️ Deleting dog from Firestore: \(dog.name ?? "")")
        
        guard let id = dog.id?.uuidString else {
            throw FirestoreError.invalidDocumentID
        }
        
        // Delete the dog's image if it exists
        if dog.imageData != nil {
            let imagePath = "dogs/\(id).jpg"
            try await storage.reference().child(imagePath).delete()
        }
        
        // Delete all walks associated with this dog
        let walksSnapshot = try await db.collection("walks")
            .whereField("dogID", isEqualTo: id)
            .getDocuments()
        
        for document in walksSnapshot.documents {
            try await db.collection("walks").document(document.documentID).delete()
        }
        
        // Delete the dog document
        try await deleteDocument(collection: "dogs", documentID: id)
    }
    
    /// Fetches all dogs from Firestore
    /// - Returns: Array of Dog objects
    /// - Throws: Firestore errors if fetch fails
    func fetchDogs() async throws -> [Dog] {
        print("🔍 Fetching dogs from Firestore")
        
        // Print Firebase authentication status
        printFirebaseAuthStatus()
        
        // Ensure we're authenticated with Firebase
        let isAuthenticated = await ensureFirebaseAuth()
        if !isAuthenticated {
            print("⚠️ Not authenticated with Firebase, attempting to fetch dogs anyway")
        }
        
        // Get the current user ID
        let currentUserID = Auth.auth().currentUser?.uid ?? AuthManager.shared.currentUser()?.id ?? ""
        print("🔍 Using user ID for Firestore query: \(currentUserID)")
        
        // Try to fetch dogs owned by the current user
        do {
            // First try to get dogs where the owner ID matches the Firebase UID
            let dogsCollection = db.collection("dogs")
            var query: Query = dogsCollection
            
            // If we have a user ID, filter by owner
            if !currentUserID.isEmpty {
                query = dogsCollection.whereField("ownerID", isEqualTo: currentUserID)
            }
            
            let snapshot = try await query.getDocuments()
            print("📊 Found \(snapshot.documents.count) dogs in Firestore")
            
            var dogs: [Dog] = []
            
            for document in snapshot.documents {
                do {
                    let dog = try await Dog.fromFirestoreDocument(document)
                    dogs.append(dog)
                    print("✅ Successfully converted document to Dog: \(dog.name ?? "")")
                } catch {
                    print("❌ Failed to convert document to Dog: \(error)")
                }
            }
            
            // If we found dogs, return them
            if !dogs.isEmpty {
                return dogs
            }
            
            // If we didn't find any dogs with the Firebase UID, try with the Apple ID
            if let appleID = AuthManager.shared.currentUser()?.id, appleID != currentUserID {
                print("🔍 No dogs found with Firebase UID, trying with Apple ID: \(appleID)")
                
                let appleSnapshot = try await db.collection("dogs")
                    .whereField("ownerID", isEqualTo: appleID)
                    .getDocuments()
                
                print("📊 Found \(appleSnapshot.documents.count) dogs with Apple ID")
                
                for document in appleSnapshot.documents {
                    do {
                        let dog = try await Dog.fromFirestoreDocument(document)
                        dogs.append(dog)
                        print("✅ Successfully converted document to Dog: \(dog.name ?? "")")
                    } catch {
                        print("❌ Failed to convert document to Dog: \(error)")
                    }
                }
            }
            
            return dogs
        } catch let error as NSError {
            print("❌ Error fetching dogs: \(error.localizedDescription)")
            print("❌ Error domain: \(error.domain), code: \(error.code)")
            
            if error.domain == FirestoreErrorDomain && 
               (error.code == 7 || error.localizedDescription.contains("Missing or insufficient permissions")) {
                print("❌ Permission error detected. Make sure Firebase security rules are updated.")
                
                // Try a different approach - get all dogs without filtering by owner
                print("🔍 Attempting to fetch all dogs without filtering by owner")
                do {
                    let allDogsSnapshot = try await db.collection("dogs").getDocuments()
                    print("📊 Found \(allDogsSnapshot.documents.count) total dogs in Firestore")
                    
                    // This is just for debugging - we'll still throw the error
                } catch {
                    print("❌ Still failed to fetch dogs: \(error.localizedDescription)")
                }
            }
            
            throw error
        }
    }
    
    // MARK: - Walk Operations
    
    /// Saves a walk to Firestore
    /// - Parameter walk: The walk to save
    /// - Returns: The document ID
    /// - Throws: Firestore errors if save fails
    func saveWalk(_ walk: Walk) async throws -> String {
        print("💾 Saving walk to Firestore")
        
        guard let dogID = walk.dog?.id?.uuidString else {
            throw FirestoreError.invalidDocumentID
        }
        
        // Check if this is a shared dog
        let isShared = walk.dog?.isShared ?? false
        
        // For existing records, check if the document exists
        if let existingRecordID = walk.recordID {
            do {
                let docRef = db.collection("walks").document(existingRecordID)
                let docSnapshot = try await docRef.getDocument()
                
                if docSnapshot.exists {
                    print("✅ Document exists, updating it")
                    return try await updateWalk(walk)
                } else {
                    print("⚠️ Document with ID \(existingRecordID) doesn't exist, creating a new one")
                    // Clear the record ID so a new document will be created
                    walk.recordID = nil
                }
            } catch {
                print("⚠️ Error checking document existence: \(error.localizedDescription)")
                // Clear the record ID so a new document will be created
                walk.recordID = nil
            }
        }
        
        // Create a new document with optimized data
        var data = walk.toFirestoreData()
        
        // Use server timestamp for better synchronization
        data["serverTimestamp"] = FieldValue.serverTimestamp()
        
        // Add priority field for shared dogs to ensure faster processing
        if isShared {
            data["priority"] = "high"
        }
        
        // Use the walk's UUID as the document ID for consistency
        let documentID = try await saveDocument(data, collection: "walks", documentID: walk.id?.uuidString)
        
        // Update the walk's record ID
        walk.recordID = documentID
        
        // Post notification that data has changed to trigger UI updates
        // This is kept for backward compatibility, but real-time listeners are preferred
        NotificationCenter.default.post(
            name: .firestoreDataChanged,
            object: nil,
            userInfo: ["walkID": documentID, "dogID": dogID, "priority": isShared ? "high" : "normal"]
        )
        
        print("✅ Walk saved to Firestore with ID: \(documentID)")
        
        return documentID
    }
    
    /// Updates a walk in Firestore
    /// - Parameter walk: The walk to update
    /// - Returns: The document ID
    /// - Throws: Firestore errors if update fails
    func updateWalk(_ walk: Walk) async throws -> String {
        print("🔄 Updating walk in Firestore")
        
        guard let id = walk.id?.uuidString else {
            throw FirestoreError.invalidDocumentID
        }
        
        let data = walk.toFirestoreData()
        let documentID = try await updateDocument(data, collection: "walks", documentID: id)
        
        // Post notification that data has changed to trigger UI updates
        // This is kept for backward compatibility, but real-time listeners are preferred
        if let dog = walk.dog, let dogID = dog.id?.uuidString {
            NotificationCenter.default.post(
                name: .firestoreDataChanged,
                object: nil,
                userInfo: ["walkID": documentID, "dogID": dogID]
            )
        }
        
        return documentID
    }
    
    /// Deletes a walk from Firestore
    /// - Parameter walk: The walk to delete
    /// - Throws: Firestore errors if delete fails
    func deleteWalk(_ walk: Walk) async throws {
        print("🗑️ Deleting walk from Firestore")
        
        guard let id = walk.id?.uuidString else {
            throw FirestoreError.invalidDocumentID
        }
        
        try await deleteDocument(collection: "walks", documentID: id)
    }
    
    /// Fetches walks for a specific dog from Firestore
    /// - Parameter dog: The dog to fetch walks for
    /// - Returns: Array of Walk objects
    /// - Throws: Firestore errors if fetch fails
    func fetchWalks(for dog: Dog) async throws -> [Walk] {
        print("🔍 Fetching walks for dog: \(dog.name ?? "")")
        
        guard let dogID = dog.id?.uuidString else {
            throw FirestoreError.invalidDocumentID
        }
        
        // For shared dogs, we might need to fetch more recent data
        let isShared = dog.isShared ?? false
        print("🔍 Dog is shared: \(isShared)")
        
        // Get the most recent walk date if available
        let mostRecentWalkDate = dog.walks?.first?.date ?? Date.distantPast
        print("🔍 Most recent walk date: \(mostRecentWalkDate)")
        
        // Query for walks, potentially limiting to newer walks
        var query = db.collection("walks")
            .whereField("dogID", isEqualTo: dogID)
            .order(by: "date", descending: true)
        
        // If this is a shared dog and we have recent walks, only fetch newer walks
        // This optimization reduces data transfer and prevents duplicates
        if isShared && mostRecentWalkDate > Date.distantPast {
            // Add a small buffer (1 second) to account for potential timestamp precision issues
            let bufferDate = mostRecentWalkDate.addingTimeInterval(-1)
            query = query.whereField("date", isGreaterThan: bufferDate)
            print("🔍 Optimized query to fetch only walks newer than: \(bufferDate)")
        }
        
        let snapshot = try await query.getDocuments()
        print("📊 Found \(snapshot.documents.count) walks for dog")
        
        var walks: [Walk] = []
        
        for document in snapshot.documents {
            do {
                let walk = try await Walk.fromFirestoreDocument(document)
                walk.dog = dog
                walks.append(walk)
            } catch {
                print("❌ Failed to convert document to Walk: \(error)")
            }
        }
        
        return walks
    }
    
    // MARK: - Sharing Operations
    
    /// Shares a dog with another user
    /// - Parameters:
    ///   - dog: The dog to share
    ///   - email: The email of the user to share with
    /// - Returns: A sharing URL
    /// - Throws: Firestore errors if sharing fails
    func shareDog(_ dog: Dog, withEmail email: String) async throws -> URL {
        print("🔄 Sharing dog with user: \(email)")
        
        guard let dogID = dog.id?.uuidString else {
            throw FirestoreError.invalidDocumentID
        }
        
        // Create a sharing document in Firestore
        let shareID = UUID().uuidString
        let shareData: [String: Any] = [
            "dogID": dogID,
            "sharedByEmail": AuthManager.shared.currentUser()?.email ?? "",
            "sharedWithEmail": email,
            "sharedAt": Date(),
            "dogName": dog.name ?? "Unknown Dog",
            "isAccepted": false
        ]
        
        try await saveDocument(shareData, collection: "shares", documentID: shareID)
        
        // Update the dog to mark it as shared
        dog.isShared = true
        dog.shareRecordID = shareID
        
        // Generate a sharing URL
        let sharingURL = URL(string: "wpooped://share?id=\(shareID)")!
        dog.shareURL = sharingURL.absoluteString
        
        // Update the dog in Firestore
        try await updateDog(dog)
        
        return sharingURL
    }
    
    /// Accepts a shared dog
    /// - Parameter shareID: The ID of the share to accept
    /// - Throws: Firestore errors if acceptance fails
    func acceptShare(shareID: String) async throws -> Dog {
        print("🔄 Accepting share with ID: \(shareID)")
        
        // Get the share document
        let shareDoc = try await db.collection("shares").document(shareID).getDocument()
        
        guard let shareData = shareDoc.data(),
              let dogID = shareData["dogID"] as? String,
              let sharedByEmail = shareData["sharedByEmail"] as? String else {
            throw FirestoreError.invalidShareData
        }
        
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
        
        // Post notification that a share was accepted - ensure this runs on the main actor
        await MainActor.run {
            NotificationCenter.default.post(name: .shareAccepted, object: nil, userInfo: ["dog": dog])
        }
        
        return dog
    }
}

extension FirestoreManager {
    // Helper method to ensure Firebase is authenticated before Firestore operations
    func ensureFirebaseAuth() async -> Bool {
        // Check if already authenticated
        if let user = Auth.auth().currentUser {
            print("✅ Already authenticated with Firebase: \(user.uid)")
            return true
        }
        
        print("🔄 No Firebase user, attempting authentication")
        
        // First try to force auth state update
        AuthDebugger.shared.forceUpdateAuthState()
        
        // Wait a moment for auth to process
        do {
            try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        } catch {
            // Ignore sleep errors
        }
        
        // Check again
        if let user = Auth.auth().currentUser {
            print("✅ Authentication successful after force update: \(user.uid)")
            return true
        }
        
        // If still not authenticated, try anonymous sign in
        print("🔄 Attempting anonymous sign in as a fallback")
        do {
            let authResult = try await Auth.auth().signInAnonymously()
            let user = authResult.user
            print("✅ Successfully signed in anonymously to Firebase with UID: \(user.uid)")
            
            // If we have a user in AuthManager, update the Firestore document
            if let userData = AuthManager.shared.currentUser() {
                print("🔄 Linking anonymous user with Apple ID: \(userData.id)")
                
                // Update the user document in Firestore
                let db = Firestore.firestore()
                try await db.collection("users").document(user.uid).setData([
                    "id": user.uid,
                    "appleUserID": userData.id,
                    "email": userData.email,
                    "displayName": userData.displayName ?? "",
                    "createdAt": userData.createdAt,
                    "lastLogin": Date()
                ])
                
                print("✅ Successfully linked anonymous user with Apple ID")
                
                // Update the stored user data with Firebase UID
                DispatchQueue.main.async {
                    AuthManager.shared.currentUserData?.id = user.uid
                    
                    // Persist the updated user data
                    if let updatedUserData = AuthManager.shared.currentUserData,
                       let encoded = try? JSONEncoder().encode(updatedUserData) {
                        UserDefaults.standard.set(encoded, forKey: "userData")
                        print("✅ Updated stored user data with Firebase UID")
                    }
                }
            }
            
            return true
        } catch {
            print("❌ Failed to sign in anonymously: \(error.localizedDescription)")
            return false
        }
    }
    
    // Debug method to print Firebase authentication status
    func printFirebaseAuthStatus() {
        if let firebaseUser = Auth.auth().currentUser {
            print("✅ Firebase Authentication Status:")
            print("  - UID: \(firebaseUser.uid)")
            print("  - Email: \(firebaseUser.email ?? "none")")
            print("  - Display Name: \(firebaseUser.displayName ?? "none")")
            print("  - Provider IDs: \(firebaseUser.providerData.map { $0.providerID })")
            print("  - Is Anonymous: \(firebaseUser.isAnonymous)")
            
            // Check if the user ID matches the one in AuthManager
            if let authUser = AuthManager.shared.currentUser() {
                print("  - AuthManager User ID: \(authUser.id)")
                print("  - ID Match: \(authUser.id == firebaseUser.uid ? "Yes" : "No")")
            } else {
                print("  - No user in AuthManager")
            }
        } else {
            print("❌ No Firebase user authenticated")
            
            // Check if we have a user in AuthManager
            if let authUser = AuthManager.shared.currentUser() {
                print("⚠️ User in AuthManager but not in Firebase:")
                print("  - ID: \(authUser.id)")
                print("  - Email: \(authUser.email)")
            } else {
                print("❌ No user in AuthManager either")
            }
        }
    }
}

// MARK: - End of FirestoreManager Implementation
// Note: FirestoreError is defined in FirestoreError.swift
