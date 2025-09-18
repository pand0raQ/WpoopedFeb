//
//  ControlWidgetsV2.swift
//  WpoopedFebWidget
//
//  iOS 18+ Control Widgets with iOS 26 Interactive Snippets
//

import WidgetKit
import SwiftUI
import AppIntents

// MARK: - Quick Walk Control Widget

@available(iOS 18.0, *)
struct QuickWalkControlWidget: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "com.wpooped.quickwalk") {
            ControlWidgetButton(action: QuickWalkControlIntent()) {
                Label("Quick Walk", systemImage: "figure.walk")
            }
        }
        .displayName("Quick Walk")
        .description("Log a quick walk for your primary dog")
    }
}

@available(iOS 18.0, *)
struct QuickWalkControlIntent: AppIntent {
    static var title: LocalizedStringResource = "Quick Walk"
    static var description = IntentDescription("Log a quick walk for your primary dog")

    func perform() async throws -> some IntentResult {
        // Get the primary dog (first dog or most recently walked)
        let dogs = SharedDataManager.shared.getAllDogs()
        guard let primaryDog = dogs.first else {
            print("❌ No dogs available for quick walk")
            return .result()
        }

        print("🚀 QuickWalkControlIntent: Logging walk for \(primaryDog.name)")

        // For now, use the existing WalkLogger until iOS 26 snippets are available
        await WalkLogger.shared.logWalk(dogID: primaryDog.id, walkType: .walk)
        return .result()
    }
}

// MARK: - Dog Selection Control Widget

@available(iOS 18.0, *)
struct DogSelectionControlWidget: ControlWidget {
    var body: some ControlWidgetConfiguration {
        AppIntentControlConfiguration(
            kind: "com.wpooped.dogselection",
            intent: DogSelectionControlIntent.self
        ) { configuration in
            ControlWidgetButton(action: LogWalkForSelectedDogIntent(selectedDog: configuration.selectedDog)) {
                if let dog = configuration.selectedDog {
                    Label(dog.name, systemImage: "pawprint.fill")
                } else {
                    Label("Select Dog", systemImage: "pawprint.circle")
                }
            }
        }
        .displayName("Dog Walk Logger")
        .description("Select a dog and log walks quickly")
    }
}

struct DogSelectionControlIntent: ControlConfigurationIntent {
    static var title: LocalizedStringResource = "Select Dog for Control"
    static var description = IntentDescription("Choose which dog to show in the Control Center widget")

    @Parameter(title: "Dog", description: "Select the dog for quick walk logging")
    var selectedDog: DogControlEntity?

    init() {}

    init(selectedDog: DogControlEntity?) {
        self.selectedDog = selectedDog
    }
}

struct DogControlEntity: AppEntity {
    let id: String
    let name: String

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Dog")
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }

    static var defaultQuery = DogControlEntityQuery()
}

struct DogControlEntityQuery: EntityQuery {
    func entities(for identifiers: [DogControlEntity.ID]) async throws -> [DogControlEntity] {
        let dogs = SharedDataManager.shared.getAllDogs()
        return dogs.compactMap { dog in
            if identifiers.contains(dog.id) {
                return DogControlEntity(id: dog.id, name: dog.name)
            }
            return nil
        }
    }

    func suggestedEntities() async throws -> [DogControlEntity] {
        let dogs = SharedDataManager.shared.getAllDogs()
        return dogs.map { dog in
            DogControlEntity(id: dog.id, name: dog.name)
        }
    }

    func defaultResult() async -> DogControlEntity? {
        let dogs = SharedDataManager.shared.getAllDogs()
        guard let firstDog = dogs.first else { return nil }
        return DogControlEntity(id: firstDog.id, name: firstDog.name)
    }
}

@available(iOS 18.0, *)
struct LogWalkForSelectedDogIntent: AppIntent {
    static var title: LocalizedStringResource = "Log Walk for Selected Dog"

    @Parameter(title: "Selected Dog")
    var selectedDog: DogControlEntity?

    init() {}

    init(selectedDog: DogControlEntity?) {
        self.selectedDog = selectedDog
    }

    func perform() async throws -> some IntentResult {
        guard let dog = selectedDog else {
            print("❌ No dog selected for walk logging")
            return .result()
        }

        print("🐕 LogWalkForSelectedDogIntent: Logging walk for \(dog.name)")

        // For now, use the existing WalkLogger
        await WalkLogger.shared.logWalk(dogID: dog.id, walkType: .walk)
        return .result()
    }
}

// MARK: - Walk Type Toggle Control Widget

@available(iOS 18.0, *)
struct WalkTypeToggleControlWidget: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "com.wpooped.walktypetoggle") {
            ControlWidgetButton(action: WalkTypeToggleIntent()) {
                Label("Toggle Walk Type", systemImage: "repeat")
            }
        }
        .displayName("Walk Type Toggle")
        .description("Toggle between walk-only and walk+poop modes")
    }
}

@available(iOS 18.0, *)
struct WalkTypeToggleIntent: AppIntent {
    static var title: LocalizedStringResource = "Toggle Walk Type"

    // Shared state for the toggle
    @AppStorage("walkTypeToggle_isPoopWalk", store: UserDefaults(suiteName: "group.bumblebee.WpoopedFeb"))
    static var isPoopWalk: Bool = false

    func perform() async throws -> some IntentResult {
        // Toggle the walk type
        Self.isPoopWalk.toggle()

        // Get the primary dog
        let dogs = SharedDataManager.shared.getAllDogs()
        guard let primaryDog = dogs.first else {
            print("❌ No dogs available for toggle walk")
            return .result()
        }

        let walkType: WalkType = Self.isPoopWalk ? .walkAndPoop : .walk
        print("🔄 WalkTypeToggleIntent: Logging \(walkType.displayName) for \(primaryDog.name)")

        // For now, use the existing WalkLogger
        await WalkLogger.shared.logWalk(dogID: primaryDog.id, walkType: walkType)
        return .result()
    }
}

// MARK: - Multi-Dog Quick Actions Control Widget

@available(iOS 18.0, *)
struct MultiDogQuickActionsControlWidget: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "com.wpooped.multidogactions") {
            ControlWidgetButton(action: ShowDogSelectionFallbackIntent()) {
                Label("All Dogs", systemImage: "pawprint.2.fill")
            }
        }
        .displayName("All Dogs Walk")
        .description("Quick access to log walks for all your dogs")
    }
}

@available(iOS 18.0, *)
struct ShowDogSelectionFallbackIntent: AppIntent {
    static var title: LocalizedStringResource = "Show Dog Selection"
    static var description = IntentDescription("Show dog selection for walk logging")

    func perform() async throws -> some IntentResult {
        print("📱 ShowDogSelectionFallbackIntent: Opening app for dog selection")
        // For iOS versions without snippets, just open the app
        return .result()
    }
}

// MARK: - Helper Functions for Control Widgets

// MARK: - Helper Functions

@available(iOS 18.0, *)
private func timeAgo(from date: Date) -> String {
    let interval = Date().timeIntervalSince(date)

    if interval < 60 {
        return "Just now"
    } else if interval < 3600 {
        let minutes = Int(interval / 60)
        return "\(minutes)m ago"
    } else if interval < 86400 {
        let hours = Int(interval / 3600)
        return "\(hours)h ago"
    } else {
        let days = Int(interval / 86400)
        return "\(days)d ago"
    }
}