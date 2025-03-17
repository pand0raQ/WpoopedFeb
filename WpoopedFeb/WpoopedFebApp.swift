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
            }
            .listenToAuthStateChanges(isAuthenticated: $isAuthenticated)
            .onChange(of: authManager.isAuthenticated) { _, newValue in
                isAuthenticated = newValue
                print("📱 Auth state changed to: \(newValue)")
            }
        }
    }
}
