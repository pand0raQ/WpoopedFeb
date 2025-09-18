import Foundation
import WidgetKit
import UIKit

// MARK: - Notification Extensions
extension Notification.Name {
    static let widgetDataUpdated = Notification.Name("widgetDataUpdated")
    static let dogWalkAdded = Notification.Name("dogWalkAdded")
}

// MARK: - Simplified Data Models for Widget
struct WalkData: Codable {
    let id: String
    let dogID: String
    let date: Date
    let walkType: WalkType
    let ownerName: String?
    
    init(id: String, dogID: String, date: Date, walkType: WalkType, ownerName: String? = nil) {
        self.id = id
        self.dogID = dogID
        self.date = date
        self.walkType = walkType
        self.ownerName = ownerName
    }
}

struct DogData: Codable {
    let id: String
    let name: String
    let imageData: Data?
    let isShared: Bool
    let lastWalk: WalkData?
    
    init(id: String, name: String, imageData: Data? = nil, isShared: Bool = false, lastWalk: WalkData? = nil) {
        self.id = id
        self.name = name
        self.imageData = imageData
        self.isShared = isShared
        self.lastWalk = lastWalk
    }
}

// MARK: - Shared Data Manager
class SharedDataManager {
    static let shared = SharedDataManager()
    private let appGroupID = "group.bumblebee.WpoopedFeb"
    
    private var sharedDefaults: UserDefaults? {
        return UserDefaults(suiteName: appGroupID)
    }
    
    private init() {}
    
    // MARK: - Keys for UserDefaults
    private enum Keys {
        static let dogsData = "shared_dogs_data"
        static let lastUpdateTimestamp = "last_update_timestamp"
        static let widgetDisplaySettings = "widget_display_settings"
        static let pendingWidgetWalks = "pending_widget_walks"
    }
    
    // MARK: - Dog Data Management
    func saveAllDogs(_ dogs: [DogData]) {
        guard let defaults = sharedDefaults else {
            print("❌ Failed to access shared UserDefaults")
            return
        }
        
        do {
            let data = try JSONEncoder().encode(dogs)
            defaults.set(data, forKey: Keys.dogsData)
            defaults.set(Date(), forKey: Keys.lastUpdateTimestamp)
            print("✅ Saved \(dogs.count) dogs to App Groups")
            
            // Trigger widget refresh after saving data
            updateWidgetTimeline()
        } catch {
            print("❌ Failed to encode dogs data: \(error)")
        }
    }
    
    func getAllDogs() -> [DogData] {
        guard let defaults = sharedDefaults,
              let data = defaults.data(forKey: Keys.dogsData) else {
            print("ℹ️ No dogs data found in App Groups")
            return []
        }
        
        do {
            let dogs = try JSONDecoder().decode([DogData].self, from: data)
            print("📱 Retrieved \(dogs.count) dogs from App Groups")
            return dogs
        } catch {
            print("❌ Failed to decode dogs data: \(error)")
            return []
        }
    }
    
    func saveDog(_ dogData: DogData) {
        var allDogs = getAllDogs()
        
        // Remove existing dog with same ID
        allDogs.removeAll { $0.id == dogData.id }
        
        // Add updated dog
        allDogs.append(dogData)
        
        // Sort by name for consistent ordering
        allDogs.sort { $0.name < $1.name }
        
        saveAllDogs(allDogs)
    }
    
    func removeDog(withID dogID: String) {
        var allDogs = getAllDogs()
        allDogs.removeAll { $0.id == dogID }
        saveAllDogs(allDogs)
    }
    
    // MARK: - Walk Data Management
    func saveLatestWalk(dogID: String, walkData: WalkData) {
        var allDogs = getAllDogs()
        
        // Find and update the specific dog
        if let index = allDogs.firstIndex(where: { $0.id == dogID }) {
            let dog = allDogs[index]
            let updatedDog = DogData(
                id: dog.id,
                name: dog.name,
                imageData: dog.imageData,
                isShared: dog.isShared,
                lastWalk: walkData
            )
            allDogs[index] = updatedDog
            
            saveAllDogs(allDogs)
            print("✅ Updated latest walk for dog: \(dog.name)")
        } else {
            print("⚠️ Dog with ID \(dogID) not found when saving walk")
        }
    }
    
    func getLatestWalk(for dogID: String) -> WalkData? {
        let dogs = getAllDogs()
        return dogs.first(where: { $0.id == dogID })?.lastWalk
    }

    func getDogName(for dogID: String) -> String? {
        let dogs = getAllDogs()
        return dogs.first(where: { $0.id == dogID })?.name
    }

    func isDogShared(_ dogID: String) -> Bool {
        let dogs = getAllDogs()
        return dogs.first(where: { $0.id == dogID })?.isShared ?? false
    }
    
    // MARK: - Sync from Main App Models
    func syncFromMainApp(dogs: [Dog]) {
        let dogDataArray = dogs.compactMap { dog -> DogData? in
            guard let id = dog.id?.uuidString,
                  let name = dog.name else {
                return nil
            }
            
            // Get the most recent walk
            let latestWalk = dog.walks?.sorted { ($0.date ?? Date.distantPast) > ($1.date ?? Date.distantPast) }.first
            
            let walkData: WalkData? = {
                guard let walk = latestWalk,
                      let walkID = walk.id?.uuidString,
                      let date = walk.date,
                      let walkType = walk.walkType else {
                    return nil
                }
                
                return WalkData(
                    id: walkID,
                    dogID: id,
                    date: date,
                    walkType: walkType,
                    ownerName: nil // Can be populated from user context if needed
                )
            }()
            
            return DogData(
                id: id,
                name: name,
                imageData: dog.imageData,
                isShared: dog.isShared ?? false,
                lastWalk: walkData
            )
        }
        
        saveAllDogs(dogDataArray)
        print("🔄 Synced \(dogDataArray.count) dogs from main app to App Groups")
    }
    
    // MARK: - Widget Timeline Management
    func updateWidgetTimeline() {
        WidgetCenter.shared.reloadAllTimelines()
        print("🔄 Requested widget timeline reload")
        
        // Also post notification for immediate sync
        NotificationCenter.default.post(name: .widgetDataUpdated, object: nil)
    }
    
    func updateWidgetTimeline(for dogID: String) {
        // For now, reload all timelines - can be optimized later if needed
        updateWidgetTimeline()
    }
    
    // MARK: - Pending Widget Walks Management
    func addPendingWidgetWalk(_ walkData: WalkData) {
        guard let defaults = sharedDefaults else { return }
        
        var pendingWalks = getPendingWidgetWalks()
        pendingWalks.append(walkData)
        
        do {
            let data = try JSONEncoder().encode(pendingWalks)
            defaults.set(data, forKey: Keys.pendingWidgetWalks)
            print("📝 Added pending widget walk: \(walkData.walkType.displayName) for dog \(walkData.dogID)")
        } catch {
            print("❌ Failed to save pending widget walk: \(error)")
        }
    }
    
    func getPendingWidgetWalks() -> [WalkData] {
        guard let defaults = sharedDefaults,
              let data = defaults.data(forKey: Keys.pendingWidgetWalks) else {
            return []
        }
        
        do {
            return try JSONDecoder().decode([WalkData].self, from: data)
        } catch {
            print("❌ Failed to decode pending widget walks: \(error)")
            return []
        }
    }
    
    func clearPendingWidgetWalks() {
        guard let defaults = sharedDefaults else { return }
        defaults.removeObject(forKey: Keys.pendingWidgetWalks)
        print("🧹 Cleared pending widget walks")
    }
    
    func removePendingWidgetWalk(withID walkID: String) {
        guard let defaults = sharedDefaults else { return }
        
        var pendingWalks = getPendingWidgetWalks()
        pendingWalks.removeAll { $0.id == walkID }
        
        do {
            let data = try JSONEncoder().encode(pendingWalks)
            defaults.set(data, forKey: Keys.pendingWidgetWalks)
            print("✅ Removed pending widget walk: \(walkID)")
        } catch {
            print("❌ Failed to update pending widget walks: \(error)")
        }
    }
    
    // MARK: - Widget Display Settings
    struct WidgetDisplaySettings: Codable {
        let preferredDogID: String?
        let showAllDogs: Bool
        let compactView: Bool
        
        init(preferredDogID: String? = nil, showAllDogs: Bool = true, compactView: Bool = false) {
            self.preferredDogID = preferredDogID
            self.showAllDogs = showAllDogs
            self.compactView = compactView
        }
    }
    
    func saveWidgetSettings(_ settings: WidgetDisplaySettings) {
        guard let defaults = sharedDefaults else { return }
        
        do {
            let data = try JSONEncoder().encode(settings)
            defaults.set(data, forKey: Keys.widgetDisplaySettings)
            updateWidgetTimeline()
        } catch {
            print("❌ Failed to save widget settings: \(error)")
        }
    }
    
    func getWidgetSettings() -> WidgetDisplaySettings {
        guard let defaults = sharedDefaults,
              let data = defaults.data(forKey: Keys.widgetDisplaySettings) else {
            return WidgetDisplaySettings() // Return default settings
        }
        
        do {
            return try JSONDecoder().decode(WidgetDisplaySettings.self, from: data)
        } catch {
            print("❌ Failed to decode widget settings: \(error)")
            return WidgetDisplaySettings()
        }
    }
    
    // MARK: - Debug and Utility
    func getLastUpdateTimestamp() -> Date? {
        return sharedDefaults?.object(forKey: Keys.lastUpdateTimestamp) as? Date
    }
    
    func clearAllData() {
        guard let defaults = sharedDefaults else { return }
        
        defaults.removeObject(forKey: Keys.dogsData)
        defaults.removeObject(forKey: Keys.lastUpdateTimestamp)
        defaults.removeObject(forKey: Keys.widgetDisplaySettings)
        
        updateWidgetTimeline()
        print("🗑️ Cleared all shared data")
    }
    
    func printDebugInfo() {
        let dogs = getAllDogs()
        let lastUpdate = getLastUpdateTimestamp()
        
        print("=== Shared Data Debug Info ===")
        print("Dogs count: \(dogs.count)")
        print("Last update: \(lastUpdate?.formatted() ?? "Never")")
        
        for dog in dogs {
            print("- Dog: \(dog.name) (ID: \(dog.id))")
            if let lastWalk = dog.lastWalk {
                print("  Last walk: \(lastWalk.walkType.displayName) at \(lastWalk.date.formatted())")
            } else {
                print("  No walks recorded")
            }
        }
        print("===============================")
    }
}

// MARK: - Extensions for Sample Data
extension DogData {
    static let sample = DogData(
        id: "sample-dog-id",
        name: "Buddy",
        imageData: nil,
        isShared: true,
        lastWalk: WalkData(
            id: "sample-walk-id",
            dogID: "sample-dog-id",
            date: Date().addingTimeInterval(-3600), // 1 hour ago
            walkType: .walkAndPoop,
            ownerName: "John"
        )
    )
} 