import Foundation
import SwiftData
import CloudKit

@Model
final class Walk: CloudKitSyncable {
    var id: UUID?
    var date: Date?
    var walkType: WalkType?
    var recordID: String?
    var lastModified: Date?
    
    @Relationship(deleteRule: .cascade, inverse: \Dog.walks)
    var dog: Dog?
    
    init(walkType: WalkType, dog: Dog? = nil) {
        self.id = UUID()
        self.date = Date()
        self.walkType = walkType
        self.dog = dog
        self.recordID = id?.uuidString
        self.lastModified = date
    }
    
    // Add a default initializer for SwiftData
    init() {
        self.id = UUID()
        self.date = Date()
        self.walkType = nil
        self.recordID = nil
        self.lastModified = Date()
        self.dog = nil
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

// MARK: - CloudKit Support
extension Walk {
    static let recordType = "Walk"
    static let zoneID = Dog.zoneID
    
    nonisolated func toCKRecord() -> CKRecord {
        // For shared dogs, we need to use the shared database's DogsZone
        let zoneID = if let dog = dog, dog.isShared ?? false {
            CKRecordZone.ID(zoneName: "DogsZone", ownerName: "_95f15e1388a74c44496595cb77c50953")
        } else {
            Dog.zoneID
        }
        
        let recordID = CKRecord.ID(recordName: self.recordID ?? "", zoneID: zoneID)
        let record = CKRecord(recordType: Walk.recordType, recordID: recordID)
        
        if let date = date {
            record["date"] = date
        }
        record["walkType"] = walkType?.rawValue
        record["lastModified"] = lastModified
        record["id"] = id?.uuidString
        
        if let dog = dog {
            // Reference must use same zone as the dog
            let dogZoneID = (dog.isShared ?? false) ? 
                CKRecordZone.ID(zoneName: "DogsZone", ownerName: "_95f15e1388a74c44496595cb77c50953") :
                Dog.zoneID
            
            let dogReference = CKRecord.Reference(
                recordID: CKRecord.ID(recordName: dog.recordID ?? "", zoneID: dogZoneID),
                action: .deleteSelf
            )
            record["dogReference"] = dogReference
        }
        
        return record
    }
    
    static func fromCKRecord(_ record: CKRecord) throws -> Walk {
        guard let date = record["date"] as? Date,
              let walkTypeRaw = record["walkType"] as? Int,
              let walkType = WalkType(rawValue: walkTypeRaw) else {
            throw CloudKitManagerError.unexpectedRecordType
        }
        
        let walk = Walk(walkType: walkType)
        walk.recordID = record.recordID.recordName
        walk.lastModified = record["lastModified"] as? Date ?? Date()
        
        if let idString = record["id"] as? String,
           let uuid = UUID(uuidString: idString) {
            walk.id = uuid
        }
        
        return walk
    }
} 
