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
    var shareURL: String?
    var recordID: String
    var lastModified: Date
    var isShareAccepted: Bool = false
    
    @Transient
    private var _assetRecord: CKAsset?
    
    var assetRecord: CKAsset? {
        get { _assetRecord }
        set { _assetRecord = newValue }
    }
    
    // QR code stored in UserDefaults
    var qrCodeData: Data? {
        get {
            return UserDefaults.standard.data(forKey: "qr_code_\(id.uuidString)")
        }
        set {
            if let newValue = newValue {
                UserDefaults.standard.set(newValue, forKey: "qr_code_\(id.uuidString)")
            } else {
                UserDefaults.standard.removeObject(forKey: "qr_code_\(id.uuidString)")
            }
        }
    }
    
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
        self.shareURL = nil
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
            // Create asset if needed
            if let imageData = imageData {
                if let asset = CloudKitManager.createAsset(from: imageData, filename: "\(id).jpg") {
                    assetRecord = asset
                }
            }
            
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
    
    nonisolated func toCKRecord() -> CKRecord {
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
        record["isShareAccepted"] = isShareAccepted
        print("- isShareAccepted: \(isShareAccepted)")
        
        if let shareURL = shareURL {
            record["shareURL"] = shareURL
            print("- shareURL: \(shareURL)")
        }
        
        // Use pre-created asset if available
        if let assetRecord = assetRecord {
            print("🖼️ Using pre-created asset")
            record["imageData"] = assetRecord
            print("✅ Image asset set")
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
        
        // Only set isShared if we have a valid shareRecordID and shareURL
        if let shareRecordID = record["shareRecordID"] as? String {
            dog.shareRecordID = shareRecordID
            print("- shareRecordID: \(shareRecordID)")
            
            if let shareURL = record["shareURL"] as? String {
                dog.shareURL = shareURL
                print("- shareURL: \(shareURL)")
                dog.isShared = true
            }
        } else {
            dog.isShared = false
        }
        print("- isShared: \(dog.isShared)")
        
        dog.isShareAccepted = record["isShareAccepted"] as? Bool ?? false
        print("- isShareAccepted: \(dog.isShareAccepted)")
        
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
        
        if let qrCodeAsset = record["qrCodeData"] as? CKAsset,
           let qrCodeURL = qrCodeAsset.fileURL,
           let qrCodeData = try? Data(contentsOf: qrCodeURL) {
            dog.qrCodeData = qrCodeData
            print("✅ QR code data loaded successfully")
        }
        
        print("✅ Dog object created successfully")
        return dog
    }
}
