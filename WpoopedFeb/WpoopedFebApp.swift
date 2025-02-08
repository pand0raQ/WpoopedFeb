//
//  WpoopedFebApp.swift
//  WpoopedFeb
//
//  Created by Halik on 2/7/25.
//

import SwiftUI
import SwiftData
import OSLog

@main
struct WpoopedFebApp: App {
    @StateObject private var authManager = AuthManager.shared
    
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "WpoopedFeb", category: "ModelContainer")
    
    var sharedModelContainer: ModelContainer = {
        do {
            // Define the model configuration
            let config = ModelConfiguration(
                "WpoopedFeb-Database",
                schema: Schema([Dog.self]),
                isStoredInMemoryOnly: false,
                allowsSave: true,
                groupContainer: .automatic,
                cloudKitDatabase: .none
            )
            
            // Create the container with the configuration
            let container = try ModelContainer(
                for: Dog.self,
                configurations: config
            )
            
            return container
        } catch {
            // Log the error
            Self.logger.error("Failed to create ModelContainer: \(error.localizedDescription)")
            
            // Create a fallback in-memory container
            do {
                let fallbackConfig = ModelConfiguration(isStoredInMemoryOnly: true)
                return try ModelContainer(
                    for: Dog.self,
                    configurations: fallbackConfig
                )
            } catch {
                Self.logger.critical("Could not create fallback ModelContainer: \(error.localizedDescription)")
                fatalError("Critical error: Could not create fallback ModelContainer: \(error)")
            }
        }
    }()

    var body: some Scene {
        WindowGroup {
            if authManager.isAuthenticated {
                ContentView()
                    .modelContainer(sharedModelContainer)
            } else {
                WelcomeView()
            }
        }
    }
}
