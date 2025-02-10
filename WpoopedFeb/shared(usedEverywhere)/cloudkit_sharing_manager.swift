import CloudKit
import Foundation
import SwiftData

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
        print("🔄 Starting share process for dog: \(dog.name ?? "Unknown")")
        
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
        if dog.ownerID?.isEmpty ?? true {
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
        if let id = dog.id {
            share["dogId"] = id.uuidString as CKRecordValue?
        }
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
    
    /// Fetches share metadata from a URL
    /// - Parameter url: The sharing URL
    /// - Returns: The share metadata
    /// - Throws: CloudKit errors if metadata fetch fails
    private func fetchShareMetadata(from url: URL) async throws -> CKShare.Metadata {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<CKShare.Metadata, Error>) in
            container.fetchShareMetadata(with: url) { metadata, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let metadata = metadata else {
                    continuation.resume(throwing: CloudKitManagerError.shareFailed("No metadata found"))
                    return
                }
                
                continuation.resume(returning: metadata)
            }
        }
    }
    
    /// Gets share metadata information from a URL
    /// - Parameter url: The sharing URL
    /// - Returns: A tuple containing the share metadata (dogName, ownerName)
    /// - Throws: CloudKit errors if metadata fetch fails
    func getShareMetadata(from url: URL) async throws -> (dogName: String, ownerName: String) {
        let metadata = try await fetchShareMetadata(from: url)
        let dogName = metadata.share[CKShare.SystemFieldKey.title] as? String ?? "Unknown Dog"
        let ownerName = metadata.share.owner.userIdentity.nameComponents?.formatted() ?? "Unknown Owner"
        return (dogName: dogName, ownerName: ownerName)
    }
    
    /// Accepts a shared dog from a URL
    /// - Parameters:
    ///   - url: The sharing URL
    ///   - context: The SwiftData context
    /// - Throws: CloudKit errors if share acceptance fails
    func acceptShare(from url: URL, context: ModelContext) async throws {
        print("🔄 Starting share acceptance process...")
        
        let metadata = try await fetchShareMetadata(from: url)
        print("✅ Got share metadata")
        
        let acceptResult = try await container.accept([metadata])
        print("✅ Share accepted in CloudKit with result: \(acceptResult.count) shares")
        
        // Get the root record ID from metadata
        let rootRecordID = metadata.rootRecordID
        print("📝 Root Record ID: \(rootRecordID.recordName)")
        
        // Fetch the shared dog record from the shared database
        let sharedDatabase = container.sharedCloudDatabase
        do {
            let record = try await sharedDatabase.record(for: rootRecordID)
            guard let dog = try? Dog.fromCKRecord(record) else {
                throw CloudKitManagerError.shareFailed("Could not create Dog from record")
            }
            
            // Update dog with sharing information
            dog.shareRecordID = rootRecordID.recordName
            dog.isShareAccepted = true
            dog.isShared = true
            
            // Save to local context
            context.insert(dog)
            try context.save()
            
            print("✅ Successfully saved shared dog to local context")
        } catch {
            print("❌ Error fetching shared record: \(error.localizedDescription)")
            throw CloudKitManagerError.shareFailed("Failed to fetch shared record: \(error.localizedDescription)")
        }

        NotificationCenter.default.post(name: .shareAccepted, object: nil)
        print("🎉 Share acceptance completed successfully")
    }
}

// MARK: - Notification Extension
extension Notification.Name {
    static let shareAccepted = Notification.Name("shareAccepted")
}