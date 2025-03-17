import Foundation
import SwiftData
import FirebaseFirestore

@Model
final class Walk: FirestoreSyncable {
    var id: UUID?
    var date: Date?
    var walkType: WalkType?
    var recordID: String?
    var lastModified: Date?
    
    @Relationship(deleteRule: .cascade, inverse: \Dog.walks)
    var dog: Dog?
    
    init(walkType: WalkType, dog: Dog? = nil, shouldSaveToFirestore: Bool = true) {
        // Always generate a new UUID for each walk to ensure uniqueness
        let walkId = UUID()
        self.id = walkId
        self.date = Date()
        self.walkType = walkType
        self.dog = dog
        self.recordID = walkId.uuidString
        self.lastModified = date
        
        if shouldSaveToFirestore {
            Task {
                await saveToFirestore()
            }
        }
    }
    
    // Add a default initializer for SwiftData
    init() {
        let walkId = UUID()
        self.id = walkId
        self.date = Date()
        self.walkType = nil
        self.recordID = walkId.uuidString
        self.lastModified = Date()
        self.dog = nil
    }
    
    @MainActor
    func saveToFirestore() async {
        do {
            let documentID = try await FirestoreManager.shared.saveWalk(self)
            print("✅ Walk saved to Firestore with ID: \(documentID)")
        } catch {
            print("❌ Failed to save walk to Firestore: \(error.localizedDescription)")
        }
    }
}

enum WalkType: Int, Codable, CaseIterable {
    case walk
    case walkAndPoop
    
    var displayName: String {
        switch self {
        case .walk: return "Walk"
        case .walkAndPoop: return "Walk + Poop"
        }
    }
    
    var iconName: String {
        switch self {
        case .walk: return "figure.walk"
        case .walkAndPoop: return "figure.walk.motion"
        }
    }
}

// MARK: - Firestore Support
extension Walk {
    func toFirestoreData() -> [String: Any] {
        var data: [String: Any] = [
            "walkType": walkType?.rawValue ?? 0,
            "lastModified": lastModified ?? Date(),
            "date": date ?? Date(),
            "id": id?.uuidString ?? ""
        ]
        
        // Add dog reference if available
        if let dog = dog, let dogID = dog.id?.uuidString {
            data["dogID"] = dogID
        }
        
        return data
    }
    
    static func fromFirestoreDocument(_ document: DocumentSnapshot) async throws -> Walk {
        guard let data = document.data(),
              let walkTypeRaw = data["walkType"] as? Int,
              let walkType = WalkType(rawValue: walkTypeRaw) else {
            throw FirestoreError.unexpectedDocumentType
        }
        
        // Create walk without auto-saving to Firestore to prevent loops
        let walk = Walk(walkType: walkType, shouldSaveToFirestore: false)
        
        // Use the document ID as the record ID
        walk.recordID = document.documentID
        walk.lastModified = (data["lastModified"] as? Timestamp)?.dateValue() ?? Date()
        walk.date = (data["date"] as? Timestamp)?.dateValue() ?? Date()
        
        // Ensure we use the original ID from Firestore if available
        if let idString = data["id"] as? String,
           let uuid = UUID(uuidString: idString) {
            walk.id = uuid
        }
        
        return walk
    }
} 
