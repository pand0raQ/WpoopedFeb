import Foundation
import SwiftData
import UIKit
import CloudKit

protocol CloudKitSyncable {
    func toCKRecord() -> CKRecord
    static func fromCKRecord(_ record: CKRecord) throws -> Self
}

@Model
final class Dog {
    @Attribute(.unique) var id: UUID
    var name: String
    var imageData: Data?
    var createdAt: Date
    var ownerID: String
    var isShared: Bool
    var shareRecordID: String?
    var recordID: String
    var lastModified: Date
    
    init(name: String, ownerID: String = AuthManager.shared.currentUser()?.id ?? "") {
        print("📱 Creating new Dog: \(name)")
        let uuid = UUID()
        self.id = uuid
        self.name = name
        self.createdAt = Date()
        self.ownerID = ownerID
        self.isShared = false
        self.recordID = uuid.uuidString
        self.lastModified = Date()
        self.imageData = nil
        print("✅ Dog created with ID: \(uuid.uuidString)")
        
        // Save to CloudKit
        Task {
            await saveToCloudKit()
        }
    }
    
    var image: UIImage? {
        guard let imageData else { return nil }
        return UIImage(data: imageData)
    }
    
    @MainActor
    func saveToCloudKit() async {
        print("🔄 Starting CloudKit save for dog: \(name)")
        do {
            let savedRecord = try await CloudKitManager.shared.save(self)
            print("✅ Dog saved to CloudKit successfully: \(savedRecord.recordID.recordName)")
        } catch {
            print("❌ Failed to save dog to CloudKit: \(error.localizedDescription)")
        }
    }
}

extension Dog: CloudKitSyncable {
    static let recordType = "Dog"
    static let zoneID = CKRecordZone.ID(zoneName: "DogsZone", ownerName: CKCurrentUserDefaultName)
    
    @MainActor func toCKRecord() -> CKRecord {
        print("🔄 Converting Dog to CKRecord: \(name)")
        let recordID = CKRecord.ID(recordName: self.recordID, zoneID: Dog.zoneID)
        let record = CKRecord(recordType: Dog.recordType, recordID: recordID)
        
        print("📝 Setting record fields:")
        record["name"] = name
        print("- name: \(name)")
        record["ownerID"] = ownerID
        print("- ownerID: \(ownerID)")
        record["isShared"] = isShared
        print("- isShared: \(isShared)")
        record["lastModified"] = lastModified
        print("- lastModified: \(lastModified)")
        record["createdAt"] = createdAt
        print("- createdAt: \(createdAt)")
        record["id"] = id.uuidString
        print("- id: \(id.uuidString)")
        
        if let imageData = imageData {
            print("🖼️ Processing image data")
            let asset = CloudKitManager.createAsset(from: imageData, filename: "\(id).jpg")
            record["imageData"] = asset
            print("✅ Image asset created and set")
        }
        
        if let shareRecordID = shareRecordID {
            print("🔗 Setting shareRecordID: \(shareRecordID)")
            record["shareRecordID"] = shareRecordID
        }
        
        print("✅ CKRecord creation completed")
        return record
    }
    
    static func fromCKRecord(_ record: CKRecord) throws -> Dog {
        print("🔄 Converting CKRecord to Dog")
        print("📝 Reading record fields:")
        
        guard let name = record["name"] as? String,
              let ownerID = record["ownerID"] as? String else {
            print("❌ Missing required fields (name or ownerID)")
            throw CloudKitManagerError.unexpectedRecordType
        }
        
        print("- name: \(name)")
        print("- ownerID: \(ownerID)")
        
        let dog = Dog(name: name, ownerID: ownerID)
        dog.recordID = record.recordID.recordName
        print("- recordID: \(dog.recordID)")
        
        dog.isShared = record["isShared"] as? Bool ?? false
        print("- isShared: \(dog.isShared)")
        
        if let shareRecordID = record["shareRecordID"] as? String {
            dog.shareRecordID = shareRecordID
            print("- shareRecordID: \(shareRecordID)")
        }
        
        dog.lastModified = record["lastModified"] as? Date ?? Date()
        print("- lastModified: \(dog.lastModified)")
        
        dog.createdAt = record["createdAt"] as? Date ?? Date()
        print("- createdAt: \(dog.createdAt)")
        
        if let idString = record["id"] as? String,
           let uuid = UUID(uuidString: idString) {
            dog.id = uuid
            print("- id: \(uuid.uuidString)")
        }
        
        if let asset = record["imageData"] as? CKAsset,
           let url = asset.fileURL,
           let data = try? Data(contentsOf: url) {
            dog.imageData = data
            print("✅ Image data loaded successfully")
        }
        
        print("✅ Dog object created successfully")
        return dog
    }
}
