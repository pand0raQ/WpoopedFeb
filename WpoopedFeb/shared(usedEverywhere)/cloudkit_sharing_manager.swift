import CloudKit
import Foundation

/// A manager class that handles CloudKit sharing functionality for the app
@MainActor
class CloudKitSharingManager {
    static let shared = CloudKitSharingManager()
    
    private let container: CKContainer
    private let shareZoneName = "DogsZone"
    private let urlGenerator = SharingURLGenerator.shared
    
    private init() {
        self.container = CKContainer(identifier: CloudKitManager.containerIdentifier)
    }
    
    /// Shares a Dog record with other users by creating a CKShare
    /// - Parameter dog: The Dog object to be shared
    /// - Returns: A CKShare object that can be used to generate a sharing URL
    /// - Throws: CloudKit errors if sharing fails
    func shareDog(_ dog: Dog) async throws -> CKShare {
        print("🔄 Starting share process for dog: \(dog.name)")
        
        // Check if share already exists
        if let shareRecordID = dog.shareRecordID {
            print("📤 Fetching existing share for dog")
            let shareRecordID = CKRecord.ID(
                recordName: shareRecordID,
                zoneID: CKRecordZone.ID(zoneName: shareZoneName, ownerName: CKCurrentUserDefaultName)
            )
            do {
                let record = try await container.privateCloudDatabase.record(for: shareRecordID)
                if let share = record as? CKShare {
                    print("✅ Found existing share")
                    return share
                }
            } catch {
                print("⚠️ Error fetching existing share: \(error.localizedDescription)")
            }
        }
        
        // Ensure owner is set
        let currentUserId = AuthManager.shared.currentUser()?.id ?? ""
        if dog.ownerID.isEmpty {
            print("📝 Setting owner ID to current user: \(currentUserId)")
            dog.ownerID = currentUserId
        } else if dog.ownerID != currentUserId {
            print("❌ Cannot share a dog you don't own")
            throw CloudKitManagerError.shareFailed("Cannot share a dog you don't own")
        }
        
        // Create dog record
        let dogRecord = dog.toCKRecord()
        
        // Create share with proper configuration
        print("📝 Creating share record")
        let share = CKShare(rootRecord: dogRecord)
        
        // Configure share permissions and metadata
        share[CKShare.SystemFieldKey.title] = dog.name as CKRecordValue?
        share[CKShare.SystemFieldKey.shareType] = "com.wpooped.dog" as CKRecordValue?
        share.publicPermission = .readWrite
        
        // Set additional share metadata
        share["dogId"] = dog.id.uuidString as CKRecordValue?
        share["ownerID"] = dog.ownerID as CKRecordValue?
        
        // Set thumbnail if available
        if let imageData = dog.imageData {
            share[CKShare.SystemFieldKey.thumbnailImageData] = imageData as CKRecordValue?
        }
        
        // Update dog record with sharing fields
        dogRecord["isShared"] = 1 as CKRecordValue
        
        // Save both records atomically
        print("💾 Saving records atomically...")
        do {
            let (savedRecords, _) = try await container.privateCloudDatabase.modifyRecords(
                saving: [dogRecord, share],
                deleting: [],
                savePolicy: .changedKeys,
                atomically: true
            )
            
            guard let savedShare = savedRecords[share.recordID],
                  let share = try savedShare.get() as? CKShare else {
                throw CloudKitManagerError.shareFailed("Failed to save share record")
            }
            
            print("✅ Successfully saved share record")
            
            // Update the dog with share information
            dog.shareRecordID = share.recordID.recordName
            dog.isShared = true
            
            // Generate and set the share URL using the URL generator
            if let shareURL = try? await urlGenerator.generateShareURL(from: share) {
                dog.shareURL = shareURL.absoluteString
            }
            
            return share
        } catch {
            print("❌ Error saving share: \(error.localizedDescription)")
            throw error
        }
    }
    

}