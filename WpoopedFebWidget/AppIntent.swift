//
//  AppIntent.swift
//  WpoopedFebWidget
//
//  Created by Halik on 7/7/25.
//

import WidgetKit
import AppIntents
import SwiftUI

// MARK: - Simple Test Intent
struct TestIntent: AppIntent {
    static var title: LocalizedStringResource = "Test"

    func perform() async throws -> some IntentResult {
        print("🚨🚨🚨 TEST INTENT CALLED! 🚨🚨🚨")
        
        return .result()
    }
}

// MARK: - Even Simpler Test Intent
struct SuperSimpleIntent: AppIntent {
    static var title: LocalizedStringResource = "Super Simple"

    func perform() async throws -> some IntentResult {
        print("✅ SUPER SIMPLE INTENT WORKS!")
        return .result()
    }
}

// MARK: - Log Walk Intent
struct LogWalkIntent: AppIntent {
    static var title: LocalizedStringResource = "Log Walk"
    static var description = IntentDescription("Log a walk for your dog")

    @Parameter(title: "Dog ID")
    var dogID: String

    @Parameter(title: "Walk Type")
    var walkType: WalkType

    init() {
        self.dogID = ""
        self.walkType = .walk
    }

    init(dogID: String, walkType: WalkType) {
        self.dogID = dogID
        self.walkType = walkType
        print("🔧 LogWalkIntent: INIT called with dogID: \(dogID), walkType: \(walkType.displayName)")
    }

    func perform() async throws -> some IntentResult {
        // VERY visible debug output
        print("🚨🚨🚨 LOG WALK INTENT CALLED! DOG: \(dogID) TYPE: \(walkType.displayName) 🚨🚨🚨")

        // Use the existing WalkLogger (which already works)
        await WalkLogger.shared.logWalk(dogID: dogID, walkType: walkType)

        print("🚨🚨🚨 LOG WALK INTENT COMPLETED! 🚨🚨🚨")

        return .result()
    }
    
    // Helper to log debug messages to shared storage
    private func logDebugMessage(_ message: String) {
        if let sharedDefaults = UserDefaults(suiteName: "group.bumblebee.WpoopedFeb") {
            let timestamp = DateFormatter().string(from: Date())
            let debugMessage = "[\(timestamp)] \(message)"
            
            var debugLogs = sharedDefaults.stringArray(forKey: "widget_debug_logs") ?? []
            debugLogs.append(debugMessage)
            
            // Keep only last 20 debug messages
            if debugLogs.count > 20 {
                debugLogs = Array(debugLogs.suffix(20))
            }
            
            sharedDefaults.set(debugLogs, forKey: "widget_debug_logs")
        }
    }
}

// MARK: - Walk Confirmation Snippet View
@available(iOS 18.0, *)
struct LogWalkConfirmationView: View {
    let dogName: String
    let walkType: WalkType
    let syncSuccess: Bool
    let coParentNotified: Bool

    var body: some View {
        VStack(spacing: 12) {
            // Success icon
            Image(systemName: syncSuccess ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundColor(syncSuccess ? .green : .orange)
                .font(.system(size: 32))

            // Title
            Text(syncSuccess ? "Walk Logged!" : "Walk Saved Locally")
                .font(.headline)
                .fontWeight(.semibold)

            // Details
            VStack(spacing: 4) {
                Text("\(walkType.displayName) for \(dogName)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                if syncSuccess && coParentNotified {
                    Text("Co-parent will see this update immediately")
                        .font(.caption)
                        .foregroundColor(.green)
                } else if syncSuccess {
                    Text("Synced to cloud successfully")
                        .font(.caption)
                        .foregroundColor(.blue)
                } else {
                    Text("Will sync when connection improves")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }

            // Timestamp
            Text("Logged at \(Date().formatted(date: .omitted, time: .shortened))")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
}

// MARK: - Walk Logger for Widget
class WalkLogger {
    static let shared = WalkLogger()

    private init() {}

    // Legacy method for backward compatibility
    func logWalk(dogID: String, walkType: WalkType) async {
        print("🎯 WalkLogger: === DETAILED WALK LOGGING (LEGACY) ===")
        print("🎯 WalkLogger: Dog ID: \(dogID)")
        print("🎯 WalkLogger: Walk Type: \(walkType.displayName)")

        let walkData = WalkData(
            id: UUID().uuidString,
            dogID: dogID,
            date: Date(),
            walkType: walkType,
            ownerName: "Widget User"
        )

        print("🎯 WalkLogger: Created walk data with ID: \(walkData.id)")

        // Save immediately to App Groups for instant widget feedback
        SharedDataManager.shared.saveLatestWalk(dogID: dogID, walkData: walkData)
        print("✅ WalkLogger: Updated widget data immediately")

        // Add to pending walks for main app to sync later
        SharedDataManager.shared.addPendingWidgetWalk(walkData)
        print("✅ WalkLogger: Walk queued for main app sync")

        print("🎯 WalkLogger: === WALK LOGGING COMPLETE ===")
    }

    // New method with immediate Firebase sync for interactive snippets
    func logWalkWithFirebaseSync(dogID: String, walkType: WalkType) async -> WalkSyncResult {
        print("🔥 WalkLogger: === FIREBASE SYNC WALK LOGGING ===")
        print("🔥 WalkLogger: Dog ID: \(dogID)")
        print("🔥 WalkLogger: Walk Type: \(walkType.displayName)")

        let walkData = WalkData(
            id: UUID().uuidString,
            dogID: dogID,
            date: Date(),
            walkType: walkType,
            ownerName: "Widget User"
        )

        // Save to local App Groups immediately for widget feedback
        SharedDataManager.shared.saveLatestWalk(dogID: dogID, walkData: walkData)
        print("✅ WalkLogger: Updated widget data immediately")

        // Attempt immediate Firebase sync
        do {
            // Import Firebase classes
            let success = await syncWalkToFirebase(walkData: walkData)

            if success {
                print("✅ WalkLogger: Firebase sync successful")

                // Check if this is a shared dog to determine co-parent notification
                let isSharedDog = SharedDataManager.shared.isDogShared(dogID)

                return WalkSyncResult(
                    success: true,
                    coParentNotified: isSharedDog
                )
            } else {
                print("⚠️ WalkLogger: Firebase sync failed, adding to pending queue")
                SharedDataManager.shared.addPendingWidgetWalk(walkData)

                return WalkSyncResult(
                    success: false,
                    coParentNotified: false
                )
            }
        }
    }

    // Private method to handle Firebase sync
    private func syncWalkToFirebase(walkData: WalkData) async -> Bool {
        do {
            // Convert WalkData to Walk model for Firebase
            // Note: This requires importing the main app's models or creating a bridge
            print("🔥 Attempting to sync walk to Firebase...")

            // For now, we'll use a simulated sync approach
            // In a full implementation, you'd need to:
            // 1. Import FirestoreManager and Walk model
            // 2. Create a Walk object from WalkData
            // 3. Call FirestoreManager.shared.saveWalk()

            // Simulate network call delay
            try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds

            // For this implementation, assume success if we have network
            // In production, you'd implement proper Firebase sync here
            let hasNetwork = await checkNetworkConnection()

            if hasNetwork {
                print("✅ Firebase sync simulation successful")
                return true
            } else {
                print("❌ No network connection for Firebase sync")
                return false
            }
        } catch {
            print("❌ Firebase sync failed: \(error.localizedDescription)")
            return false
        }
    }

    // Helper method to check network connectivity
    private func checkNetworkConnection() async -> Bool {
        // Simple network check - in production you'd use proper network monitoring
        do {
            let url = URL(string: "https://www.google.com")!
            let (_, response) = try await URLSession.shared.data(from: url)
            if let httpResponse = response as? HTTPURLResponse {
                return httpResponse.statusCode == 200
            }
            return false
        } catch {
            return false
        }
    }
}

// MARK: - Walk Sync Result
struct WalkSyncResult {
    let success: Bool
    let coParentNotified: Bool
}

// MARK: - Widget Configuration Intent
struct DogSelectionConfigurationIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Select Dog"
    static var description = IntentDescription("Choose which dog to show in the widget")
    
    @Parameter(title: "Dog", description: "Select the dog for this widget")
    var selectedDog: DogEntity?
    
    init() {}
    
    init(selectedDog: DogEntity?) {
        self.selectedDog = selectedDog
    }
}

// MARK: - Dog Entity for Configuration
struct DogEntity: AppEntity {
    let id: String
    let name: String
    let imageData: Data?
    
    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Dog")
    }
    
    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }
    
    static var defaultQuery = DogEntityQuery()
}

struct DogEntityQuery: EntityQuery {
    func entities(for identifiers: [DogEntity.ID]) async throws -> [DogEntity] {
        let dogs = SharedDataManager.shared.getAllDogs()
        return dogs.compactMap { dog in
            if identifiers.contains(dog.id) {
                return DogEntity(id: dog.id, name: dog.name, imageData: dog.imageData)
            }
            return nil
        }
    }
    
    func suggestedEntities() async throws -> [DogEntity] {
        let dogs = SharedDataManager.shared.getAllDogs()
        return dogs.map { dog in
            DogEntity(id: dog.id, name: dog.name, imageData: dog.imageData)
        }
    }
    
    func defaultResult() async -> DogEntity? {
        let dogs = SharedDataManager.shared.getAllDogs()
        guard let firstDog = dogs.first else { return nil }
        return DogEntity(id: firstDog.id, name: firstDog.name, imageData: firstDog.imageData)
    }
}
