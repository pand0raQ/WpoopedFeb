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
        
        // Create new share
        let dogRecord = dog.toCKRecord()
        let share = CKShare(rootRecord: dogRecord)
        share.publicPermission = .readWrite
        share[CKShare.SystemFieldKey.title] = dog.name ?? "Shared Dog"
        
        // Save both records atomically
        do {
            print("💾 Saving share and dog record...")
            let (savedRecords, _) = try await container.privateCloudDatabase.modifyRecords(
                saving: [dogRecord, share],
                deleting: [],
                savePolicy: .allKeys,
                atomically: true
            )
            
            // Verify both records were saved
            guard let savedDogRecord = try savedRecords[dogRecord.recordID]?.get(),
                  let savedShare = try savedRecords[share.recordID]?.get() as? CKShare else {
                throw CloudKitManagerError.shareFailed("Failed to save share or dog record")
            }
            
            print("✅ Share and dog record saved successfully")
            
            // After saving the share, fetch and store metadata for the owner
            do {
                guard let shareURL = savedShare.url else {
                    throw CloudKitManagerError.shareFailed("Share URL not available")
                }
                
                // Fetch metadata for the owner
                let metadata = try await fetchShareMetadata(from: shareURL)
                print("✅ Owner fetched share metadata successfully")
                
                // Update dog with metadata
                dog.shareRecordID = metadata.share.recordID.recordName
                dog.shareURL = shareURL.absoluteString
                dog.isShared = true
                
                // The shared database won't exist until the share is accepted
                print("⚠️ Shared database not yet available - waiting for share acceptance")
                
                // Explicitly fetch the shared zones for the owner (will be empty until accepted)
                do {
                    let sharedZones = try await container.sharedCloudDatabase.allRecordZones()
                    print("Owner's shared zones after sharing:", sharedZones)
                } catch {
                    print("⚠️ Error fetching shared zones (expected until share is accepted): \(error.localizedDescription)")
                }
                
                return savedShare
            } catch {
                print("❌ Error fetching share metadata for owner: \(error.localizedDescription)")
                throw error
            }
        } catch {
            print("❌ Error saving share: \(error.localizedDescription)")
            if let ckError = error as? CKError {
                print("🔍 CloudKit error details:")
                print("  - Error code: \(ckError.code.rawValue)")
                print("  - Description: \(ckError.localizedDescription)")
            }
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