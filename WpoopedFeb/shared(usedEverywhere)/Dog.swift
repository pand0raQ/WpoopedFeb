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
    
    @Transient
    private var _assetRecord: CKAsset?
    
    var assetRecord: CKAsset? {
        get { _assetRecord }
        set { _assetRecord = newValue }
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
    
    init(name: String, ownerID: String = AuthManager.shared.currentUser()?.id ?? "", shouldSaveToCloudKit: Bool = true) {
        self.id = UUID()
        self.name = name
        self.createdAt = Date()
        self.ownerID = ownerID
        self.isShared = false
        self.recordID = id?.uuidString
        self.lastModified = Date()
        self.imageData = nil
        self.shareURL = nil
        
        if shouldSaveToCloudKit {
            Task {
                await saveToCloudKit()
            }
        }
    }
    
    var image: UIImage? {
        guard let imageData else { return nil }
        return UIImage(data: imageData)
    }
    
    @MainActor
    func saveToCloudKit() async {
        do {
            // Create asset if needed
            if let imageData = imageData {
                assetRecord = CloudKitManager.createAsset(from: imageData, filename: "\(id ?? UUID()).jpg")
            }
            
            let savedRecord = try await CloudKitManager.shared.save(self)
            print("✅ Dog '\(name ?? "")' saved to CloudKit: \(savedRecord.recordID.recordName)")
        } catch {
            print("❌ Failed to save dog '\(name ?? "")' to CloudKit: \(error.localizedDescription)")
        }
    }
}

extension Dog: CloudKitSyncable {
    static let recordType = "Dog"
    static let zoneID = CKRecordZone.ID(zoneName: "DogsZone", ownerName: CKCurrentUserDefaultName)
    
    nonisolated func toCKRecord() -> CKRecord {
        let recordID = CKRecord.ID(recordName: self.recordID ?? "", zoneID: Dog.zoneID)
        let record = CKRecord(recordType: Dog.recordType, recordID: recordID)
        
        // Set basic fields
        record["name"] = name
        record["ownerID"] = ownerID
        record["isShared"] = isShared
        record["lastModified"] = lastModified
        record["createdAt"] = createdAt
        record["id"] = id?.uuidString
        record["isShareAccepted"] = isShareAccepted
        
        // Set optional fields
        if let shareURL = shareURL {
            record["shareURL"] = shareURL
        }
        
        if let assetRecord = assetRecord {
            record["imageData"] = assetRecord
        }
        
        if let shareRecordID = shareRecordID {
            record["shareRecordID"] = shareRecordID
        }
        
        return record
    }
    
    static func fromCKRecord(_ record: CKRecord) throws -> Dog {
        guard let name = record["name"] as? String,
              let ownerID = record["ownerID"] as? String else {
            throw CloudKitManagerError.unexpectedRecordType
        }
        
        // Create dog without auto-saving to CloudKit
        let dog = Dog(name: name, ownerID: ownerID, shouldSaveToCloudKit: false)
        dog.recordID = record.recordID.recordName
        
        // Set sharing fields
        if let shareRecordID = record["shareRecordID"] as? String {
            dog.shareRecordID = shareRecordID
            if let shareURL = record["shareURL"] as? String {
                dog.shareURL = shareURL
                dog.isShared = true
            }
        }
        
        // Set other fields
        dog.isShareAccepted = record["isShareAccepted"] as? Bool ?? false
        dog.lastModified = record["lastModified"] as? Date ?? Date()
        dog.createdAt = record["createdAt"] as? Date ?? Date()
        
        if let idString = record["id"] as? String,
           let uuid = UUID(uuidString: idString) {
            dog.id = uuid
        }
        
        // Load assets
        if let asset = record["imageData"] as? CKAsset,
           let url = asset.fileURL,
           let data = try? Data(contentsOf: url) {
            dog.imageData = data
        }
        
        return dog
    }
}
