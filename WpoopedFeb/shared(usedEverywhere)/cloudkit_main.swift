import CloudKit
import Combine
import SwiftUI

@MainActor
class CloudKitManager: ObservableObject {
    static let containerIdentifier = "iCloud.bumblebee.WpoopedFeb"
    static var shared = CloudKitManager()
    
    private let container: CKContainer
    private let privateDatabase: CKDatabase
    
    init(container: CKContainer? = nil) {
        print("📱 Initializing CloudKitManager")
        self.container = container ?? CKContainer(identifier: CloudKitManager.containerIdentifier)
        self.privateDatabase = self.container.privateCloudDatabase
        print("✅ CloudKit container initialized with ID: \(CloudKitManager.containerIdentifier)")
        
        Task {
            do {
                try await configureContainer()
            } catch {
                print("❌ Failed to configure container: \(error)")
            }
        }
    }
    
    private func configureContainer() async throws {
        print("🔄 Starting CloudKit container configuration")
        
        do {
            print("👤 Checking account status...")
            let accountStatus = try await container.accountStatus()
            print("📊 Account status: \(accountStatus.rawValue)")
            
            if accountStatus == .available {
                print("✅ iCloud account is properly configured")
                // Create the custom zone if it doesn't exist
                try await createCustomZoneIfNeeded()
            } else {
                print("❌ iCloud account is not available: \(accountStatus.rawValue)")
                throw CloudKitManagerError.userNotFound
            }
        } catch {
            print("❌ Failed to configure container: \(error.localizedDescription)")
            throw error
        }
    }
    
    private func createCustomZoneIfNeeded() async throws {
        print("🔄 Checking for custom zone...")
        do {
            let zone = CKRecordZone(zoneID: Dog.zoneID)
            return try await withCheckedThrowingContinuation { continuation in
                privateDatabase.save(zone) { savedZone, error in
                    if let error = error as? CKError {
                        if error.code == .zoneNotFound {
                            print("⚠️ Zone not found, creating it...")
                            let newZone = CKRecordZone(zoneID: Dog.zoneID)
                            self.privateDatabase.save(newZone) { _, saveError in
                                if let saveError = saveError {
                                    print("❌ Error creating zone: \(saveError.localizedDescription)")
                                    continuation.resume(throwing: saveError)
                                } else {
                                    print("✅ Custom zone created successfully")
                                    continuation.resume(returning: ())
                                }
                            }
                        } else if error.code == .zoneBusy || error.code == .serverRecordChanged {
                            // Zone already exists or is being modified, which is fine
                            print("✅ Zone already exists or is being modified")
                            continuation.resume(returning: ())
                        } else {
                            print("❌ Error creating zone: \(error.localizedDescription)")
                            continuation.resume(throwing: error)
                        }
                    } else if let error = error {
                        continuation.resume(throwing: error)
                    } else {
                        print("✅ Custom zone created or already exists")
                        continuation.resume(returning: ())
                    }
                }
            }
        } catch {
            print("❌ Error in zone creation: \(error.localizedDescription)")
            throw error
        }
    }
    
    // MARK: - Record Operations
    
    /// Ensures a record is in the correct zone
    private func ensureCorrectZone(_ record: CKRecord) -> CKRecord {
        if record.recordID.zoneID != Dog.zoneID {
            print("⚠️ Record not in DogsZone, moving to correct zone")
            let newRecordID = CKRecord.ID(recordName: record.recordID.recordName, zoneID: Dog.zoneID)
            let recordInZone = CKRecord(recordType: record.recordType, recordID: newRecordID)
            
            // Copy all fields
            for (key, value) in record {
                recordInZone[key] = value
                print("📝 Copying field: \(key)")
            }
            
            return recordInZone
        }
        return record
    }
    
    /// Saves a record to CloudKit
    /// - Parameter record: The record to save
    /// - Parameter savePolicy: The save policy to use (defaults to .allKeys)
    /// - Returns: The saved record
    /// - Throws: CloudKit errors if save fails
    private func saveRecord(_ record: CKRecord, savePolicy: CKModifyRecordsOperation.RecordSavePolicy = .allKeys) async throws -> CKRecord {
        print("💾 Saving record to CloudKit...")
        let (savedRecords, _) = try await privateDatabase.modifyRecords(
            saving: [record],
            deleting: [],
            savePolicy: savePolicy,
            atomically: true
        )
        
        guard let savedRecord = try savedRecords[record.recordID]?.get() else {
            print("❌ No record returned after save")
            throw CloudKitManagerError.saveFailed("No record returned after save")
        }
        
        print("✅ Record saved successfully")
        return savedRecord
    }
    
    public func save(_ record: CKRecord) async throws -> CKRecord {
        print("🔄 Starting to save record: \(record.recordType) - \(record.recordID.recordName)")
        print("📍 Zone ID: \(record.recordID.zoneID.zoneName)")
        
        let recordInZone = ensureCorrectZone(record)
        return try await saveRecord(recordInZone)
    }
    
    public func save<T: CloudKitSyncable>(_ item: T) async throws -> CKRecord {
        print("🔄 Converting item to CKRecord")
        let record = item.toCKRecord()
        return try await save(record)
    }
    
    public func update<T: CloudKitSyncable>(_ item: T) async throws -> CKRecord {
        print("🔄 Starting update for item")
        let record = item.toCKRecord()
        let recordInZone = ensureCorrectZone(record)
        return try await saveRecord(recordInZone, savePolicy: .changedKeys)
    }
    
    public func delete(_ record: CKRecord) async throws {
        print("🗑️ Deleting record: \(record.recordID.recordName)")
        try await privateDatabase.deleteRecord(withID: record.recordID)
        print("✅ Record deleted successfully")
    }
    
    public func fetchDogs() async throws -> [Dog] {
        print("🔍 Starting to fetch dogs from CloudKit")
        
        // First fetch from private database
        let predicate = NSPredicate(value: true)
        let query = CKQuery(recordType: Dog.recordType, predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
        
        print("🔄 Executing query in private database...")
        let (matchResults, _) = try await privateDatabase.records(matching: query, inZoneWith: Dog.zoneID)
        let privateRecords = matchResults.compactMap { try? $0.1.get() }
        print("📊 Found \(privateRecords.count) records in private database")
        
        // Then fetch from shared database
        print("🔄 Executing query in shared database...")
        let sharedDB = container.sharedCloudDatabase
        let (sharedResults, _) = try await sharedDB.records(matching: query, inZoneWith: CKRecordZone.default().zoneID)
        let sharedRecords = sharedResults.compactMap { try? $0.1.get() }
        print("📊 Found \(sharedRecords.count) records in shared database")
        
        // Process private records
        let privateDogs = privateRecords.compactMap { record in
            do {
                let dog = try Dog.fromCKRecord(record)
                print("✅ Successfully converted private record to Dog: \(dog.name)")
                return dog
            } catch {
                print("❌ Failed to convert private record to Dog: \(error)")
                return nil
            }
        }
        
        // Process shared records and fetch their shares
        var sharedDogs: [Dog] = []
        for record in sharedRecords {
            do {
                let dog = try Dog.fromCKRecord(record)
                dog.isShared = true
                
                // Fetch the associated share record
                let (shareResults, _) = try await sharedDB.records(matching: CKQuery(recordType: "cloudkit.share", predicate: NSPredicate(value: true)), inZoneWith: record.recordID.zoneID)
                if let shareRecord = try shareResults.first?.1.get() as? CKShare {
                    dog.shareRecordID = shareRecord.recordID.recordName
                    if let shareURL = try? await SharingURLGenerator.shared.generateShareURL(from: shareRecord) {
                        dog.shareURL = shareURL.absoluteString
                    }
                }
                
                print("✅ Successfully converted shared record to Dog: \(dog.name)")
                sharedDogs.append(dog)
            } catch {
                print("❌ Failed to convert shared record to Dog: \(error)")
            }
        }
        
        print("✅ Fetch completed. Returning \(privateDogs.count + sharedDogs.count) dogs")
        return privateDogs + sharedDogs
    }
    
    /// Creates a CKAsset from image data
    static func createAsset(from imageData: Data, filename: String) -> CKAsset? {
        print("🖼️ Creating asset for filename: \(filename)")
        let tempDir = FileManager.default.temporaryDirectory
        let tempFileURL = tempDir.appendingPathComponent(UUID().uuidString + "_" + filename)
        
        do {
            try imageData.write(to: tempFileURL)
            print("✅ Asset created successfully")
            return CKAsset(fileURL: tempFileURL)
        } catch {
            print("❌ Error creating asset: \(error)")
            return nil
        }
    }
    
    // MARK: - Walk Operations
    
    public func fetchWalks(for dog: Dog) async throws -> [Walk] {
        print("🔍 Fetching walks for dog: \(dog.name ?? "")")
        print("📝 Dog details - ID: \(dog.recordID ?? "nil"), isShared: \(dog.isShared ?? false)")
        
        // For shared dogs, we need to use the shared database's DogsZone
        let dogZoneID = if dog.isShared ?? false {
            // Use the shared database's DogsZone
            CKRecordZone.ID(zoneName: "DogsZone", ownerName: "_95f15e1388a74c44496595cb77c50953")
        } else {
            Dog.zoneID
        }
        
        let dogReference = CKRecord.Reference(
            recordID: CKRecord.ID(recordName: dog.recordID ?? "", zoneID: dogZoneID),
            action: .none
        )
        print("🔗 Created dog reference with zoneID: \(dogReference.recordID.zoneID.zoneName)")
        
        let predicate = NSPredicate(format: "dogReference == %@", dogReference)
        let query = CKQuery(recordType: Walk.recordType, predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
        
        // Use shared database for shared dogs
        let database = (dog.isShared ?? false) ? container.sharedCloudDatabase : privateDatabase
        print("📦 Using database: \(dog.isShared ?? false ? "shared" : "private")")
        
        // Use the same zone as the dog for walks
        let walkZoneID = dogZoneID
        print("🎯 Using zone: \(walkZoneID.zoneName) (owner: \(walkZoneID.ownerName))")
        
        print("🔄 Executing walks query...")
        do {
            let (matchResults, cursor) = try await database.records(matching: query, inZoneWith: walkZoneID)
            print("📊 Query results - Count: \(matchResults.count), Has more: \(cursor != nil)")
            
            let records = matchResults.compactMap { try? $0.1.get() }
            print("📊 Successfully parsed \(records.count) walk records")
            
            let walks = records.compactMap { record in
                do {
                    print("🔄 Processing walk record: \(record.recordID.recordName)")
                    print("📍 Record zone: \(record.recordID.zoneID.zoneName)")
                    
                    let walk = try Walk.fromCKRecord(record)
                    walk.dog = dog
                    walk.recordID = record.recordID.recordName
                    
                    print("✅ Successfully converted record to Walk")
                    return walk
                } catch {
                    print("❌ Failed to convert record to Walk: \(error)")
                    return nil
                }
            }
            
            print("✅ Walk fetch completed. Returning \(walks.count) walks")
            return walks
        } catch {
            print("❌ Error fetching walks: \(error)")
            if let ckError = error as? CKError {
                print("🔍 CloudKit error details:")
                print("  - Error code: \(ckError.code.rawValue)")
                print("  - Description: \(ckError.localizedDescription)")
                if let serverRecord = ckError.serverRecord {
                    print("  - Server record type: \(serverRecord.recordType)")
                    print("  - Server record zone: \(serverRecord.recordID.zoneID.zoneName)")
                }
            }
            throw error
        }
    }
    
    public func saveWalk(_ walk: Walk) async throws {
        print("💾 Saving walk to CloudKit...")
        guard let dog = walk.dog else {
            throw CloudKitManagerError.saveFailed("Walk must be associated with a dog")
        }
        
        print("📝 Walk details:")
        print("  - Walk ID: \(walk.recordID ?? "nil")")
        print("  - Dog ID: \(dog.recordID ?? "nil")")
        print("  - Is Shared: \(dog.isShared ?? false)")
        
        if dog.isShared ?? false {
            print("🔄 Getting share record for shared dog...")
            
            // First fetch the dog record from shared database
            let dogZoneID = CKRecordZone.ID(zoneName: "DogsZone", ownerName: "_95f15e1388a74c44496595cb77c50953")
            let dogRecordID = CKRecord.ID(recordName: dog.recordID ?? "", zoneID: dogZoneID)
            
            print("🔍 Fetching dog record from shared database...")
            let dogRecord = try await container.sharedCloudDatabase.record(for: dogRecordID)
            
            print("✅ Found dog record")
            print("  - Record ID: \(dogRecord.recordID.recordName)")
            print("  - Zone: \(dogRecord.recordID.zoneID.zoneName)")
            
            // Get the share from the dog record
            guard let share = dogRecord.share else {
                throw CloudKitManagerError.saveFailed("No share record found for dog")
            }
            
            print("✅ Found share record")
            print("  - Share Zone: \(share.recordID.zoneID.zoneName)")
            print("  - Share Owner: \(share.recordID.zoneID.ownerName)")
            
            // Create walk record in the share's zone
            let walkRecord = CKRecord(
                recordType: Walk.recordType,
                recordID: CKRecord.ID(recordName: walk.recordID ?? UUID().uuidString, zoneID: dogRecord.recordID.zoneID)
            )
            
            // Set up the sharing relationship
            walkRecord.setParent(dogRecord)
            
            // Set walk record fields
            if let date = walk.date {
                walkRecord["date"] = date
            }
            walkRecord["walkType"] = walk.walkType?.rawValue
            walkRecord["lastModified"] = walk.lastModified
            walkRecord["id"] = walk.id?.uuidString
            
            // Create dog reference using the dog's zone
            let dogReference = CKRecord.Reference(
                recordID: dogRecord.recordID,
                action: .deleteSelf
            )
            walkRecord["dogReference"] = dogReference
            
            print("📝 Created walk record in shared zone:")
            print("  - Record ID: \(walkRecord.recordID.recordName)")
            print("  - Zone: \(walkRecord.recordID.zoneID.zoneName)")
            print("  - Share: \(share.recordID.recordName)")
            
            // Save to shared database
            print("💾 Saving to shared database...")
            let (savedRecords, _) = try await container.sharedCloudDatabase.modifyRecords(
                saving: [walkRecord],
                deleting: [],
                savePolicy: .allKeys,
                atomically: true
            )
            
            guard let savedWalkRecord = try savedRecords[walkRecord.recordID]?.get() else {
                throw CloudKitManagerError.saveFailed("No record returned after save")
            }
            
            print("✅ Walk saved successfully to shared database")
            print("  - Saved Record ID: \(savedWalkRecord.recordID.recordName)")
            print("  - Share: \(savedWalkRecord.share?.recordID.recordName ?? "none")")
            
        } else {
            // Handle private dog walk save
            let walkRecord = walk.toCKRecord()
            print("📝 Created CKRecord for private dog:")
            print("  - Record ID: \(walkRecord.recordID.recordName)")
            print("  - Zone: \(walkRecord.recordID.zoneID.zoneName)")
            
            print("💾 Saving to private database...")
            let (savedRecords, _) = try await privateDatabase.modifyRecords(
                saving: [walkRecord],
                deleting: [],
                savePolicy: .allKeys,
                atomically: true
            )
            
            guard let savedWalkRecord = try savedRecords[walkRecord.recordID]?.get() else {
                throw CloudKitManagerError.saveFailed("No record returned after save")
            }
            
            print("✅ Walk saved successfully to private database")
        }
        
        // Update the dog's lastModified date in the appropriate database
        dog.lastModified = Date()
        
        // Create dog record with the correct zone ID for shared database
        let updatedDogZoneID = CKRecordZone.ID(zoneName: "DogsZone", ownerName: "_95f15e1388a74c44496595cb77c50953")
        let updatedDogRecordID = CKRecord.ID(recordName: dog.recordID ?? "", zoneID: updatedDogZoneID)
        let updatedDogRecord = CKRecord(recordType: Dog.recordType, recordID: updatedDogRecordID)
        updatedDogRecord["lastModified"] = dog.lastModified
        
        print("\n🔄 Updating dog's lastModified date...")
        print("  - Using zone: \(updatedDogZoneID.zoneName)")
        print("  - Zone owner: \(updatedDogZoneID.ownerName)")
        
        let database = (dog.isShared ?? false) ? container.sharedCloudDatabase : privateDatabase
        let (updatedRecords, _) = try await database.modifyRecords(
            saving: [updatedDogRecord],
            deleting: [],
            savePolicy: .changedKeys,
            atomically: true
        )
        
        if let updatedDogRecord = try updatedRecords[updatedDogRecord.recordID]?.get() {
            print("✅ Dog record updated successfully")
            print("  - Updated Record ID: \(updatedDogRecord.recordID.recordName)")
            print("  - Updated Zone: \(updatedDogRecord.recordID.zoneID.zoneName)")
        }
    }
    
    // MARK: - Debug Helpers
    
    public func debugPrintZoneInfo() async {
        print("\n📋 CloudKit Zone Debug Information:")
        do {
            // Check private database zones
            print("\n🔐 Private Database Zones:")
            let privateZones = try await privateDatabase.allRecordZones()
            for zone in privateZones {
                print("  - Zone: \(zone.zoneID.zoneName)")
                print("    Owner: \(zone.zoneID.ownerName)")
                print("    Capabilities: \(zone.capabilities.rawValue)")
            }
            
            // Check shared database zones
            print("\n🤝 Shared Database Zones:")
            let sharedZones = try await container.sharedCloudDatabase.allRecordZones()
            for zone in sharedZones {
                print("  - Zone: \(zone.zoneID.zoneName)")
                print("    Owner: \(zone.zoneID.ownerName)")
                print("    Capabilities: \(zone.capabilities.rawValue)")
            }
        } catch {
            print("❌ Error fetching zone information: \(error.localizedDescription)")
            if let ckError = error as? CKError {
                print("🔍 CloudKit error code: \(ckError.code.rawValue)")
            }
        }
    }
}
