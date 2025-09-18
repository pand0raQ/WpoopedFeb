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
import BackgroundTasks

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
                    setupRealtimeWidgetSync()
                }
            }
            .listenToAuthStateChanges(isAuthenticated: $isAuthenticated)
            .onChange(of: authManager.isAuthenticated) { _, newValue in
                isAuthenticated = newValue
                print("📱 Auth state changed to: \(newValue)")
                
                // Sync widget data when authentication changes
                if newValue {
                    setupWidgetDataSync()
                    setupRealtimeWidgetSync()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                // Sync widget data when app comes to foreground
                // This ensures widgets are updated when user switches between apps
                print("📱 App entering foreground - syncing widget data and pending walks")
                Task {
                    await syncDogsToWidgetData()
                    await syncPendingWidgetWalks()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
                // Sync pending walks when app goes to background
                // This gives a chance to sync before app is suspended
                print("📱 App entering background - final sync of pending walks")
                Task {
                    await syncPendingWidgetWalks()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .dogWalkAdded)) { _ in
                // Sync widget data when a walk is added (including from Firebase real-time updates)
                print("📱 Dog walk added - syncing widget data")
                Task {
                    await syncDogsToWidgetData()
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
        print("🔄 === SYNCING PENDING WIDGET WALKS ===")
        
        let pendingWalks = SharedDataManager.shared.getPendingWidgetWalks()
        print("🔄 Found \(pendingWalks.count) pending widget walks")
        
        guard !pendingWalks.isEmpty else {
            print("✅ No pending widget walks to sync")
            return
        }
        
        print("🔄 Syncing \(pendingWalks.count) pending widget walks to Firebase...")
        
        for (index, walkData) in pendingWalks.enumerated() {
            print("🔄 Processing walk \(index + 1)/\(pendingWalks.count):")
            print("  - Walk ID: \(walkData.id)")
            print("  - Dog ID: \(walkData.dogID)")
            print("  - Walk Type: \(walkData.walkType.displayName)")
            print("  - Date: \(walkData.date)")
            print("  - Owner: \(walkData.ownerName ?? "Unknown")")
            
            do {
                // Convert WalkData to Firebase format and save
                let walkDoc: [String: Any] = [
                    "id": walkData.id,
                    "dogID": walkData.dogID,
                    "date": Timestamp(date: walkData.date),
                    "walkType": walkData.walkType.rawValue,
                    "ownerName": walkData.ownerName ?? "Widget User",
                    "createdFromWidget": true // Flag to identify widget-created walks
                ]
                
                print("🔄 Saving to Firebase collection 'walks' with document ID: \(walkData.id)")
                
                // Save to Firebase
                let db = Firestore.firestore()
                let walkRef = db.collection("walks").document(walkData.id)
                try await walkRef.setData(walkDoc)
                
                print("✅ Successfully synced widget walk to Firebase: \(walkData.walkType.displayName)")
                
                // Remove from pending list after successful sync
                SharedDataManager.shared.removePendingWidgetWalk(withID: walkData.id)
                print("✅ Removed walk from pending list")
                
            } catch {
                print("❌ Failed to sync widget walk \(walkData.id) to Firebase: \(error)")
                print("❌ Error details: \(error.localizedDescription)")
                // Keep in pending list for retry next time
            }
        }
        
        // Check remaining pending walks
        let remainingWalks = SharedDataManager.shared.getPendingWidgetWalks()
        print("🔄 Remaining pending walks after sync: \(remainingWalks.count)")
        
        print("✅ === FINISHED SYNCING PENDING WIDGET WALKS ===")
    }
    
    // MARK: - Real-time Widget Sync
    private func setupRealtimeWidgetSync() {
        print("🔄 Setting up real-time widget sync")
        
        // Listen for walk changes in Firebase to update widgets immediately
        let db = Firestore.firestore()
        
        // Listen to all walks collection for changes
        db.collection("walks").addSnapshotListener { snapshot, error in
            if let error = error {
                print("❌ Error listening to walks: \(error)")
                return
            }
            
            guard let snapshot = snapshot else { return }
            
            // Check if there are any changes (not just initial load)
            if !snapshot.documentChanges.isEmpty {
                print("🔄 Walks collection changed - syncing widget data")

                // Immediately sync dogs to widget data to ensure latest walks are shown
                Task {
                    await syncDogsToWidgetData()
                }

                // Post notification to trigger widget sync
                NotificationCenter.default.post(name: .dogWalkAdded, object: nil)
            }
        }
    }
}
