//
//  WidgetDataManager.swift
//  WpoopedFebWidget
//
//  Created by Widget Extension on 7/27/25.
//

import Foundation
import WidgetKit

class SharedDataManager {
    static let shared = SharedDataManager()
    
    private let sharedDefaults: UserDefaults?
    
    private init() {
        self.sharedDefaults = UserDefaults(suiteName: "group.bumblebee.WpoopedFeb")
        if sharedDefaults == nil {
            print("❌ Widget: Failed to initialize shared UserDefaults")
        }
    }
    
    // MARK: - Keys for UserDefaults
    private enum Keys {
        static let dogsData = "shared_dogs_data"
        static let lastUpdateTimestamp = "last_update_timestamp"
        static let widgetDisplaySettings = "widget_display_settings"
        static let pendingWidgetWalks = "pending_widget_walks"
    }
    
    // MARK: - Widget Display Settings
    struct WidgetDisplaySettings: Codable {
        var preferredDogID: String?
        var showAllDogs: Bool
        
        init(preferredDogID: String? = nil, showAllDogs: Bool = true) {
            self.preferredDogID = preferredDogID
            self.showAllDogs = showAllDogs
        }
    }
    
    // MARK: - Dog Data Management
    func getAllDogs() -> [DogData] {
        guard let defaults = sharedDefaults else {
            print("❌ Widget: Failed to access shared UserDefaults")
            return []
        }
        
        guard let data = defaults.data(forKey: Keys.dogsData) else {
            print("📱 Widget: No shared dog data found in app group 'group.bumblebee.WpoopedFeb'")
            print("🔍 Widget: Available keys in shared defaults: \(Array(defaults.dictionaryRepresentation().keys))")
            
            // Return empty array - no more fake data!
            print("⚠️ Widget: Returning empty array to prompt sync")
            return []
        }
        
        do {
            let dogs = try JSONDecoder().decode([DogData].self, from: data)
            print("📱 Widget: Retrieved \(dogs.count) dogs from shared data")
            for dog in dogs {
                print("  - \(dog.name) (ID: \(dog.id))")
            }
            return dogs
        } catch {
            print("❌ Widget: Failed to decode dog data: \(error)")
            return []
        }
    }
    
    func saveLatestWalk(dogID: String, walkData: WalkData) {
        print("💾 Widget: === SAVING LATEST WALK ===")
        print("💾 Widget: Dog ID: \(dogID)")
        print("💾 Widget: Walk ID: \(walkData.id)")
        print("💾 Widget: Walk Type: \(walkData.walkType.displayName)")
        
        var dogs = getAllDogs()
        print("💾 Widget: Retrieved \(dogs.count) dogs from shared data")
        
        // Find and update the dog with the new walk
        if let index = dogs.firstIndex(where: { $0.id == dogID }) {
            print("💾 Widget: Found dog at index \(index): \(dogs[index].name)")
            print("💾 Widget: Previous last walk: \(dogs[index].lastWalk?.walkType.displayName ?? "None")")
            
            let updatedDog = DogData(
                id: dogs[index].id,
                name: dogs[index].name,
                imageData: dogs[index].imageData,
                isShared: dogs[index].isShared,
                lastWalk: walkData
            )
            dogs[index] = updatedDog
            
            print("💾 Widget: Updated dog with new walk: \(walkData.walkType.displayName)")
            
            // Save updated dogs array
            saveDogs(dogs)
            print("✅ Widget: Updated dog \(dogID) with latest walk")
        } else {
            print("⚠️ Widget: Dog \(dogID) not found for walk update")
            print("⚠️ Widget: Available dog IDs:")
            for dog in dogs {
                print("  - \(dog.id) (\(dog.name))")
            }
        }
        
        print("💾 Widget: === SAVE LATEST WALK COMPLETE ===")
    }
    
    private func saveDogs(_ dogs: [DogData]) {
        guard let defaults = sharedDefaults else { return }
        
        do {
            let data = try JSONEncoder().encode(dogs)
            defaults.set(data, forKey: Keys.dogsData)
            defaults.set(Date(), forKey: Keys.lastUpdateTimestamp)
            print("💾 Saved \(dogs.count) dogs to shared data")
        } catch {
            print("❌ Failed to save dogs: \(error)")
        }
    }
    
    // MARK: - Widget Timeline Management
    func updateWidgetTimeline() {
        WidgetCenter.shared.reloadAllTimelines()
        print("🔄 Requested widget timeline reload")
    }
    
    func updateWidgetTimeline(for dogID: String) {
        updateWidgetTimeline()
    }
    
    // MARK: - Pending Widget Walks Management
    func addPendingWidgetWalk(_ walkData: WalkData) {
        print("📝 Widget: === ADDING PENDING WALK ===")
        print("📝 Widget: Walk ID: \(walkData.id)")
        print("📝 Widget: Dog ID: \(walkData.dogID)")
        print("📝 Widget: Walk Type: \(walkData.walkType.displayName)")
        
        guard let defaults = sharedDefaults else { 
            print("❌ Widget: Failed to access shared defaults for pending walks")
            return 
        }
        
        var pendingWalks = getPendingWidgetWalks()
        print("📝 Widget: Current pending walks count: \(pendingWalks.count)")
        
        pendingWalks.append(walkData)
        print("📝 Widget: Added walk to pending list, new count: \(pendingWalks.count)")
        
        do {
            let data = try JSONEncoder().encode(pendingWalks)
            defaults.set(data, forKey: Keys.pendingWidgetWalks)
            print("✅ Widget: Successfully saved pending walk to shared storage")
            print("📝 Widget: Walk queued for main app sync: \(walkData.walkType.displayName) for dog \(walkData.dogID)")
        } catch {
            print("❌ Widget: Failed to save pending widget walk: \(error)")
        }
        
        print("📝 Widget: === PENDING WALK ADDED ===")
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
    
    // MARK: - Helper Methods for Interactive Snippets
    func getDogName(for dogID: String) -> String? {
        let dogs = getAllDogs()
        return dogs.first(where: { $0.id == dogID })?.name
    }

    func isDogShared(_ dogID: String) -> Bool {
        let dogs = getAllDogs()
        return dogs.first(where: { $0.id == dogID })?.isShared ?? false
    }

    func getLastUpdateTimestamp() -> Date? {
        return sharedDefaults?.object(forKey: Keys.lastUpdateTimestamp) as? Date
    }

    // MARK: - Widget Display Settings
    func getWidgetSettings() -> WidgetDisplaySettings {
        guard let defaults = sharedDefaults,
              let data = defaults.data(forKey: Keys.widgetDisplaySettings) else {
            return WidgetDisplaySettings()
        }
        
        do {
            return try JSONDecoder().decode(WidgetDisplaySettings.self, from: data)
        } catch {
            print("❌ Failed to decode widget settings: \(error)")
            return WidgetDisplaySettings()
        }
    }
    
    func saveWidgetSettings(_ settings: WidgetDisplaySettings) {
        guard let defaults = sharedDefaults else { return }
        
        do {
            let data = try JSONEncoder().encode(settings)
            defaults.set(data, forKey: Keys.widgetDisplaySettings)
            print("💾 Saved widget settings")
        } catch {
            print("❌ Failed to save widget settings: \(error)")
        }
    }
}