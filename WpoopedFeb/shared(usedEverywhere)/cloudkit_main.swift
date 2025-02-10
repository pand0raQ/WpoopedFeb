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
        print("📍 Using zone: \(Dog.zoneID.zoneName)")
        
        let predicate = NSPredicate(value: true)
        let query = CKQuery(recordType: Dog.recordType, predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
        
        print("🔄 Executing query...")
        let (matchResults, _) = try await privateDatabase.records(matching: query, inZoneWith: Dog.zoneID)
        let records = matchResults.compactMap { try? $0.1.get() }
        print("📊 Found \(records.count) records")
        
        let dogs = records.compactMap { record in
            do {
                let dog = try Dog.fromCKRecord(record)
                print("✅ Successfully converted record to Dog: \(dog.name)")
                return dog
            } catch {
                print("❌ Failed to convert record to Dog: \(error)")
                return nil
            }
        }
        
        print("✅ Fetch completed. Returning \(dogs.count) dogs")
        return dogs
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
}
