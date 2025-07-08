//
//  AppIntent.swift
//  WpoopedFebWidget
//
//  Created by Halik on 7/7/25.
//

import WidgetKit
import AppIntents

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
    }
    
    func perform() async throws -> some IntentResult {
        print("🚶‍♂️ Widget: Logging walk for dog \(dogID), type: \(walkType)")
        
        // Log walk through the walk logger
        await WalkLogger.shared.logWalk(dogID: dogID, walkType: walkType)
        
        // Update widget timeline immediately
        SharedDataManager.shared.updateWidgetTimeline()
        
        // Return success result
        return .result()
    }
}

// MARK: - Walk Logger for Widget
class WalkLogger {
    static let shared = WalkLogger()
    
    private init() {}
    
    func logWalk(dogID: String, walkType: WalkType) async {
        print("🎯 WalkLogger: Starting walk log for dog \(dogID)")
        
        do {
            // Create walk data immediately for widget
            let walkData = WalkData(
                id: UUID().uuidString,
                dogID: dogID,
                date: Date(),
                walkType: walkType,
                ownerName: "Widget User" // Could be improved with user context
            )
            
            // Save immediately to App Groups for instant widget feedback
            SharedDataManager.shared.saveLatestWalk(dogID: dogID, walkData: walkData)
            print("✅ WalkLogger: Updated widget data immediately")
            
            // Add to pending walks for main app to sync later
            SharedDataManager.shared.addPendingWidgetWalk(walkData)
            
            // Try to save to Firebase (this might fail if app is not running)
            await saveToFirebaseInBackground(walkData: walkData)
            
        } catch {
            print("❌ WalkLogger: Error logging walk: \(error)")
        }
    }
    
    private func saveToFirebaseInBackground(walkData: WalkData) async {
        // This is a simplified Firebase save for widget context
        // The main app will handle the full Firebase integration
        print("🔄 WalkLogger: Attempting Firebase save in background...")
        
        // For now, we'll just log that we tried
        // The main app will sync this data when it's next opened
        print("ℹ️ WalkLogger: Firebase save queued for main app sync")
    }
}

// MARK: - Widget Configuration Intent (optional for future customization)
// Note: This can be implemented later if needed for configurable widgets
