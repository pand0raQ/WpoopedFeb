//
//  WpoopedFebWidget.swift
//  WpoopedFebWidget
//
//  Created by Halik on 7/7/25.
//

import WidgetKit
import SwiftUI
import AppIntents

// MARK: - Timeline Provider
struct WalkWidgetProvider: AppIntentTimelineProvider {
    typealias Entry = WalkWidgetEntry
    typealias Intent = DogSelectionConfigurationIntent
    
    func placeholder(in context: Context) -> WalkWidgetEntry {
        WalkWidgetEntry.placeholder
    }
    
    func snapshot(for configuration: DogSelectionConfigurationIntent, in context: Context) async -> WalkWidgetEntry {
        return createEntry(for: configuration)
    }
    
    func timeline(for configuration: DogSelectionConfigurationIntent, in context: Context) async -> Timeline<WalkWidgetEntry> {
        let currentEntry = createEntry(for: configuration)
        
        // ULTRA-AGGRESSIVE refresh for widget-first experience
        // Refresh every 30 seconds to ensure users always see fresh data
        let nextRefresh = Calendar.current.date(byAdding: .second, value: 30, to: Date())!
        return Timeline(entries: [currentEntry], policy: .after(nextRefresh))
    }
    
    private func createEntry(for configuration: DogSelectionConfigurationIntent? = nil) -> WalkWidgetEntry {
        print("🔍 Widget Provider: Creating entry...")
        let dogs = SharedDataManager.shared.getAllDogs()
        print("🔍 Widget Provider: Got \(dogs.count) dogs")
        for dog in dogs {
            print("  - Widget Provider: \(dog.name) (ID: \(dog.id))")
        }
        
        let entry = WalkWidgetEntry(
            date: Date(),
            dogs: dogs,
            selectedDogID: configuration?.selectedDog?.id
        )
        print("🔍 Widget Provider: Created entry with \(entry.dogs.count) dogs")
        return entry
    }
}

// MARK: - Timeline Entry
struct WalkWidgetEntry: TimelineEntry {
    let date: Date
    let dogs: [DogData]
    let selectedDogID: String?
    
    static let placeholder = WalkWidgetEntry(
        date: Date(),
        dogs: [DogData.sample],
        selectedDogID: nil
    )
}

// MARK: - Main Widget View
struct WalkWidgetView: View {
    let entry: WalkWidgetEntry
    @Environment(\.widgetFamily) var family
    
    var body: some View {
        Group {
            if entry.dogs.isEmpty {
                NoDogsView()
            } else {
                // Only support medium widget size
                MediumWidgetView(dogs: entry.dogs, selectedDogID: entry.selectedDogID)
            }
        }
    }
}


// MARK: - Enhanced Medium Widget (Primary Interface)
struct MediumWidgetView: View {
    let dogs: [DogData]
    let selectedDogID: String?
    
    private var selectedDog: DogData? {
        print("🔍 Widget View: Selecting dog...")
        print("🔍 Widget View: Available dogs: \(dogs.count)")
        for dog in dogs {
            print("  - \(dog.name) (ID: \(dog.id))")
        }
        print("🔍 Widget View: Selected dog ID from config: \(selectedDogID ?? "None")")
        
        if let selectedDogID = selectedDogID {
            let matchedDog = dogs.first { $0.id == selectedDogID }
            print("🔍 Widget View: Matched dog: \(matchedDog?.name ?? "None")")
            return matchedDog
        }
        
        let firstDog = dogs.first
        print("🔍 Widget View: Using first dog: \(firstDog?.name ?? "None")")
        return firstDog
    }
    
    var body: some View {
        if let dog = selectedDog {
            VStack(spacing: 12) {
                // Dog header with larger profile
                HStack(spacing: 12) {
                    DogImageView(imageData: dog.imageData, size: 50)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(dog.name)
                                .font(.headline)
                                .fontWeight(.semibold)
                            
                            if dog.isShared {
                                Image(systemName: "person.2.fill")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            }
                        }
                        
                        if let lastWalk = dog.lastWalk {
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    Text("Last walk: \(timeAgo(from: lastWalk.date))")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    
                                    WalkTypeIcon(walkType: lastWalk.walkType, size: .small)
                                }
                                
                                // Show data freshness for decision making
                                DataFreshnessIndicator()
                            }
                        } else {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("No walks today")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                DataFreshnessIndicator()
                            }
                        }
                    }
                    
                    Spacer()
                }
                
                // Enhanced action buttons with better visibility
                HStack(spacing: 12) {
                    let simpleIntent = SuperSimpleIntent()
                    let _ = print("🔍 Widget: Creating SUPER SIMPLE intent")
                    Button(intent: simpleIntent) {
                        HStack(spacing: 6) {
                            Image(systemName: "figure.walk")
                                .font(.system(size: 14, weight: .semibold))
                            Text("Walk")
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            LinearGradient(
                                colors: [Color.blue, Color.blue.opacity(0.8)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                    
                    Button(intent: LogWalkIntent(dogID: dog.id, walkType: .walkAndPoop)) {
                        HStack(spacing: 6) {
                            Image(systemName: "leaf.fill")
                                .font(.system(size: 14, weight: .semibold))
                            Text("Walk + Poop")
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            LinearGradient(
                                colors: [Color.brown, Color.brown.opacity(0.8)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                }
                
                // Walk statistics for today
                if let lastWalk = dog.lastWalk, Calendar.current.isDateInToday(lastWalk.date) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.caption)
                        
                        Text("Walked today")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text(lastWalk.walkType.displayName)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(16)
        } else {
            NoDogsView()
        }
    }
}


// MARK: - Helper Views
struct DogRowView: View {
    let dog: DogData
    let showActions: Bool
    
    init(dog: DogData, showActions: Bool = false) {
        self.dog = dog
        self.showActions = showActions
    }
    
    var body: some View {
        HStack(spacing: 12) {
            DogImageView(imageData: dog.imageData, size: 40)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(dog.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    if dog.isShared {
                        Image(systemName: "person.2.fill")
                            .font(.caption2)
                            .foregroundColor(.blue)
                    }
                }
                
                if let lastWalk = dog.lastWalk {
                    HStack(spacing: 4) {
                        Text(timeAgo(from: lastWalk.date))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        WalkTypeIcon(walkType: lastWalk.walkType, size: .small)
                    }
                } else {
                    Text("No walks recorded")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            if showActions {
                HStack(spacing: 4) {
                    Button(intent: LogWalkIntent(dogID: dog.id, walkType: .walk)) {
                        Image(systemName: "figure.walk")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                    .buttonStyle(.plain)
                    
                    Button(intent: LogWalkIntent(dogID: dog.id, walkType: .walkAndPoop)) {
                        Image(systemName: "leaf.fill")
                            .font(.caption)
                            .foregroundColor(.brown)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

struct DogImageView: View {
    let imageData: Data?
    let size: CGFloat
    
    var body: some View {
        Group {
            if let imageData = imageData,
               let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Image(systemName: "pawprint.fill")
                    .foregroundColor(.accentColor)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .background(
            Circle()
                .fill(Color.gray.opacity(0.2))
        )
    }
}

struct WalkTypeIcon: View {
    let walkType: WalkType
    let size: IconSize
    
    enum IconSize {
        case small, medium, large
        
        var fontSize: Font {
            switch self {
            case .small: return .caption2
            case .medium: return .caption
            case .large: return .subheadline
            }
        }
    }
    
    var body: some View {
        Image(systemName: walkType.iconName)
            .font(size.fontSize)
            .foregroundColor(walkType == .walkAndPoop ? .brown : .blue)
    }
}

struct NoDogsView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "pawprint.circle")
                .font(.largeTitle)
                .foregroundColor(.gray)

            Text("No Dogs Found")
                .font(.headline)
                .fontWeight(.medium)

            VStack(spacing: 4) {
                Text("Open the app to sync your dogs")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)

                Text("Tap 'Sync Dogs to Widget' in the Dogs tab")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(16)
    }
}

struct DataFreshnessIndicator: View {
    var body: some View {
        if let lastUpdate = SharedDataManager.shared.getLastUpdateTimestamp() {
            let timeSince = Date().timeIntervalSince(lastUpdate)

            HStack(spacing: 4) {
                Circle()
                    .fill(timeSince < 300 ? .green : timeSince < 900 ? .yellow : .red) // 5min fresh, 15min stale
                    .frame(width: 6, height: 6)

                Text("Updated \(timeAgo(from: lastUpdate))")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        } else {
            HStack(spacing: 4) {
                Circle()
                    .fill(.gray)
                    .frame(width: 6, height: 6)

                Text("Sync pending")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Helper Functions
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

// MARK: - Main Widget Configuration
struct WpoopedFebWidget: Widget {
    let kind: String = "WpoopedFebWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: DogSelectionConfigurationIntent.self, provider: WalkWidgetProvider()) { entry in
            WalkWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Dog Walks")
        .description("Track your dog's walks and see the latest activity.")
        .supportedFamilies([.systemMedium])
    }
}

// MARK: - Preview
#Preview(as: .systemMedium) {
    WpoopedFebWidget()
} timeline: {
    WalkWidgetEntry.placeholder
}

