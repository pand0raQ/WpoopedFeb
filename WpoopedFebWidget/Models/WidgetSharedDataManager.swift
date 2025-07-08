//
//  WidgetSharedDataManager.swift
//  WpoopedFebWidget
//
//  Created by Widget Extension on 7/7/25.
//

import Foundation
import WidgetKit

class SharedDataManager {
    static let shared = SharedDataManager()
    
    private let sharedDefaults: UserDefaults?
    
    private init() {
        self.sharedDefaults = UserDefaults(suiteName: "group.bumblebee.WpoopedFeb")
        if sharedDefaults == nil {
            print("❌ Failed to initialize shared UserDefaults")
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
        guard let defaults = sharedDefaults,
              let data = defaults.data(forKey: Keys.dogsData) else {
            print("📱 No shared dog data found, returning sample data")
            return [DogData.sample]
        }
        
        do {
            let dogs = try JSONDecoder().decode([DogData].self, from: data)
            print("📱 Retrieved \(dogs.count) dogs from shared data")
            return dogs
        } catch {
            print("❌ Failed to decode dog data: \(error)")
            return [DogData.sample]
        }
    }
    
    func saveLatestWalk(dogID: String, walkData: WalkData) {
        var dogs = getAllDogs()
        
        // Find and update the dog with the new walk
        if let index = dogs.firstIndex(where: { $0.id == dogID }) {
            let updatedDog = DogData(
                id: dogs[index].id,
                name: dogs[index].name,
                imageData: dogs[index].imageData,
                isShared: dogs[index].isShared,
                lastWalk: walkData
            )
            dogs[index] = updatedDog
            
            // Save updated dogs array
            saveDogs(dogs)
            print("✅ Updated dog \(dogID) with latest walk")
        } else {
            print("⚠️ Dog \(dogID) not found for walk update")
        }
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