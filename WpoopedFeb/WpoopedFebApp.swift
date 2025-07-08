//
//  WpoopedFebApp.swift
//  WpoopedFeb
//
//  Created by Halik on 2/7/25.
//

import SwiftUI
import SwiftData
import OSLog
import FirebaseCore
import FirebaseFirestore

// Add URL helper extension
extension URL {
    static func storeURL(for appGroup: String, databaseName: String) -> URL {
        guard let fileContainer = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup) else {
            fatalError("Shared file container could not be created.")
        }
        return fileContainer.appendingPathComponent("\(databaseName).sqlite")
    }
}

@main
struct WpoopedFebApp: App {
    // Register the app delegate for handling Firebase notifications
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    @StateObject private var authManager = AuthManager.shared
    @State private var isAuthenticated: Bool = false
    
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "WpoopedFeb", category: "ModelContainer")
    
    var sharedModelContainer: ModelContainer = {
        do {
            let schema = Schema([Dog.self])
            let modelConfiguration = ModelConfiguration(
                "WpoopedFeb",
                schema: schema,
                isStoredInMemoryOnly: false,
                allowsSave: true,
                groupContainer: .identifier("group.bumblebee.WpoopedFeb")
            )
            
            return try ModelContainer(for: schema, configurations: modelConfiguration)
        } catch {
            Self.logger.error("Failed to create ModelContainer: \(error.localizedDescription)")
            
            // Try creating an in-memory container as fallback
            do {
                let fallbackConfig = ModelConfiguration(isStoredInMemoryOnly: true)
                return try ModelContainer(for: Dog.self, configurations: fallbackConfig)
            } catch {
                Self.logger.critical("Failed to create in-memory container: \(error.localizedDescription)")
                fatalError("Critical error: Could not create any ModelContainer")
            }
        }
    }()

    var body: some Scene {
        WindowGroup {
            ZStack {
                if isAuthenticated {
                    ContentView()
                        .modelContainer(sharedModelContainer)
                } else {
                    MainWelcomeView()
                }
            }
            .onAppear {
                // Initialize isAuthenticated from AuthManager
                isAuthenticated = authManager.isAuthenticated
                
                // Debug auth state
                AuthDebugger.shared.debugAuthState()
                
                // NEW: Setup widget data sync when app launches
                if isAuthenticated {
                    setupWidgetDataSync()
                }
            }
            .listenToAuthStateChanges(isAuthenticated: $isAuthenticated)
            .onChange(of: authManager.isAuthenticated) { _, newValue in
                isAuthenticated = newValue
                print("📱 Auth state changed to: \(newValue)")
                
                // Sync widget data when authentication changes
                if newValue {
                    setupWidgetDataSync()
                }
            }
        }
    }
    
    // MARK: - Widget Data Sync
    private func setupWidgetDataSync() {
        Task {
            await syncDogsToWidgetData()
            // NEW: Sync any pending widget walks to Firebase
            await syncPendingWidgetWalks()
        }
    }
    
    private func syncDogsToWidgetData() async {
        do {
            // Get all dogs from the main app's model context
            let modelContext = sharedModelContainer.mainContext
            let dogDescriptor = FetchDescriptor<Dog>()
            let dogs = try modelContext.fetch(dogDescriptor)
            
            // Sync to SharedDataManager for widget access
            SharedDataManager.shared.syncFromMainApp(dogs: dogs)
            
            print("🔄 Synced \(dogs.count) dogs to widget data on app launch")
        } catch {
            print("❌ Failed to sync dogs to widget data: \(error.localizedDescription)")
        }
    }
    
    private func syncPendingWidgetWalks() async {
        let pendingWalks = SharedDataManager.shared.getPendingWidgetWalks()
        
        guard !pendingWalks.isEmpty else {
            print("✅ No pending widget walks to sync")
            return
        }
        
        print("🔄 Syncing \(pendingWalks.count) pending widget walks to Firebase...")
        
        for walkData in pendingWalks {
            do {
                // Convert WalkData to Firebase format and save
                let walkDoc: [String: Any] = [
                    "id": walkData.id,
                    "dogID": walkData.dogID,
                    "date": Timestamp(date: walkData.date),
                    "walkType": walkData.walkType.rawValue,
                    "ownerName": walkData.ownerName,
                    "createdFromWidget": true // Flag to identify widget-created walks
                ]
                
                // Save to Firebase
                let db = Firestore.firestore()
                let walkRef = db.collection("walks").document(walkData.id)
                try await walkRef.setData(walkDoc)
                
                print("✅ Synced widget walk to Firebase: \(walkData.walkType.displayName)")
                
                // Remove from pending list after successful sync
                SharedDataManager.shared.removePendingWidgetWalk(withID: walkData.id)
                
            } catch {
                print("❌ Failed to sync widget walk \(walkData.id) to Firebase: \(error)")
                // Keep in pending list for retry next time
            }
        }
        
        print("✅ Finished syncing pending widget walks")
    }
}
