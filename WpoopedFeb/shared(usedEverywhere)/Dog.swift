import Foundation
import SwiftData
import UIKit

// Import Firebase modules with error handling
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#else
#error("FirebaseFirestore module not found. Please check your Firebase setup.")
#endif

#if canImport(FirebaseStorage)
import FirebaseStorage
#else
#error("FirebaseStorage module not found. Please check your Firebase setup.")
#endif

#if canImport(FirebaseAuth)
import FirebaseAuth
#else
#error("FirebaseAuth module not found. Please check your Firebase setup.")
#endif

protocol FirestoreSyncable {
    func toFirestoreData() -> [String: Any]
    static func fromFirestoreDocument(_ document: DocumentSnapshot) async throws -> Self
}

@Model
final class Dog: FirestoreSyncable {
    var id: UUID?
    var name: String?
    var imageData: Data?
    var createdAt: Date?
    var ownerID: String?
    var isShared: Bool?
    var shareRecordID: String?
    var shareURL: String?
    var recordID: String?
    var lastModified: Date?
    var isShareAccepted: Bool = false
    var shareOwnerName: String?
    
    @Relationship(deleteRule: .cascade)
    var walks: [Walk]? = []
    
    @Transient
    private var _imageURL: String?
    
    var imageURL: String? {
        get { _imageURL }
        set { _imageURL = newValue }
    }
    
    // QR code stored in UserDefaults with proper key management
    private static func qrCodeKey(for id: UUID) -> String {
        return "qr_code_\(id.uuidString)"
    }
    
    var qrCodeData: Data? {
        get {
            return UserDefaults.standard.data(forKey: Self.qrCodeKey(for: id ?? UUID()))
        }
        set {
            if let newValue = newValue {
                UserDefaults.standard.set(newValue, forKey: Self.qrCodeKey(for: id ?? UUID()))
            } else {
                UserDefaults.standard.removeObject(forKey: Self.qrCodeKey(for: id ?? UUID()))
            }
        }
    }
    
    init(name: String, ownerID: String = AuthManager.shared.currentUser()?.id ?? "", shouldSaveToFirestore: Bool = true) {
        self.id = UUID()
        self.name = name
        self.createdAt = Date()
        
        // Use Firebase UID if available, otherwise use Apple ID
        if let firebaseUID = Auth.auth().currentUser?.uid {
            self.ownerID = firebaseUID
            print("✅ Using Firebase UID for dog owner: \(firebaseUID)")
        } else {
            self.ownerID = ownerID
            print("⚠️ No Firebase UID available, using provided owner ID: \(ownerID)")
        }
        
        self.isShared = false
        self.recordID = id?.uuidString
        self.lastModified = Date()
        self.imageData = nil
        self.shareURL = nil
        
        if shouldSaveToFirestore {
            Task {
                await saveToFirestore()
            }
        }
    }
    
    var image: UIImage? {
        guard let imageData else { return nil }
        return UIImage(data: imageData)
    }
    
    @MainActor
    func saveToFirestore() async {
        do {
            let documentID = try await FirestoreManager.shared.saveDog(self)
            print("✅ Dog '\(name ?? "")' saved to Firestore with ID: \(documentID)")
        } catch {
            print("❌ Failed to save dog '\(name ?? "")' to Firestore: \(error.localizedDescription)")
        }
    }
}

extension Dog {
    func toFirestoreData() -> [String: Any] {
        var data: [String: Any] = [
            "name": name ?? "",
            "ownerID": ownerID ?? "",
            "isShared": isShared ?? false,
            "lastModified": lastModified ?? Date(),
            "createdAt": createdAt ?? Date(),
            "id": id?.uuidString ?? "",
            "isShareAccepted": isShareAccepted
        ]
        
        // Add optional fields
        if let shareURL = shareURL {
            data["shareURL"] = shareURL
        }
        
        if let shareRecordID = shareRecordID {
            data["shareRecordID"] = shareRecordID
        }
        
        if let shareOwnerName = shareOwnerName {
            data["shareOwnerName"] = shareOwnerName
        }
        
        if let imageURL = imageURL {
            data["imageURL"] = imageURL
        }
        
        return data
    }
    
    static func fromFirestoreDocument(_ document: DocumentSnapshot) async throws -> Dog {
        guard let data = document.data(),
              let name = data["name"] as? String,
              let ownerID = data["ownerID"] as? String else {
            throw FirestoreError.unexpectedDocumentType
        }
        
        // Create dog without auto-saving to Firestore
        let dog = Dog(name: name, ownerID: ownerID, shouldSaveToFirestore: false)
        dog.recordID = document.documentID
        
        // Set sharing fields
        if let shareRecordID = data["shareRecordID"] as? String {
            dog.shareRecordID = shareRecordID
            if let shareURL = data["shareURL"] as? String {
                dog.shareURL = shareURL
                dog.isShared = true
            }
        }
        
        // Set other fields
        dog.isShareAccepted = data["isShareAccepted"] as? Bool ?? false
        dog.lastModified = (data["lastModified"] as? Timestamp)?.dateValue() ?? Date()
        dog.createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
        
        if let idString = data["id"] as? String, let uuid = UUID(uuidString: idString) {
            dog.id = uuid
        }
        
        // Handle image URL if present
        if let imageURL = data["imageURL"] as? String {
            dog.imageURL = imageURL
            
            // Download the image data
            do {
                let url = URL(string: imageURL)!
                dog.imageData = try await FirestoreManager.shared.downloadImage(from: url)
            } catch {
                print("❌ Failed to download image data: \(error.localizedDescription)")
            }
        }
        dog.shareOwnerName = data["shareOwnerName"] as? String
        
        return dog
    }
}
