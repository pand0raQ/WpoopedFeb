//
//  WpoopedFebWidget.swift
//  WpoopedFebWidget
//
//  Created by Halik on 7/7/25.
//

import WidgetKit
import SwiftUI

// MARK: - Timeline Provider
struct WalkWidgetProvider: TimelineProvider {
    typealias Entry = WalkWidgetEntry
    
    func placeholder(in context: Context) -> WalkWidgetEntry {
        WalkWidgetEntry.placeholder
    }
    
    func getSnapshot(in context: Context, completion: @escaping (WalkWidgetEntry) -> Void) {
        let entry = createEntry()
        completion(entry)
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<WalkWidgetEntry>) -> Void) {
        let currentEntry = createEntry()
        
        // Refresh every 15 minutes or when significant events occur
        let nextRefresh = Calendar.current.date(byAdding: .minute, value: 15, to: Date())!
        let timeline = Timeline(entries: [currentEntry], policy: .after(nextRefresh))
        
        completion(timeline)
    }
    
    private func createEntry() -> WalkWidgetEntry {
        let dogs = SharedDataManager.shared.getAllDogs()
        let settings = SharedDataManager.shared.getWidgetSettings()
        
        return WalkWidgetEntry(
            date: Date(),
            dogs: dogs,
            settings: settings
        )
    }
}

// MARK: - Timeline Entry
struct WalkWidgetEntry: TimelineEntry {
    let date: Date
    let dogs: [DogData]
    let settings: SharedDataManager.WidgetDisplaySettings
    
    static let placeholder = WalkWidgetEntry(
        date: Date(),
        dogs: [DogData.sample],
        settings: SharedDataManager.WidgetDisplaySettings()
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
                switch family {
                case .systemSmall:
                    SmallWidgetView(dogs: entry.dogs, settings: entry.settings)
                case .systemMedium:
                    MediumWidgetView(dogs: entry.dogs, settings: entry.settings)
                case .systemLarge:
                    LargeWidgetView(dogs: entry.dogs, settings: entry.settings)
                @unknown default:
                    SmallWidgetView(dogs: entry.dogs, settings: entry.settings)
                }
            }
        }
    }
}

// MARK: - Small Widget (1x1)
struct SmallWidgetView: View {
    let dogs: [DogData]
    let settings: SharedDataManager.WidgetDisplaySettings
    
    private var displayDog: DogData? {
        if let preferredID = settings.preferredDogID {
            return dogs.first { $0.id == preferredID }
        }
        return dogs.first
    }
    
    var body: some View {
        VStack(spacing: 4) {
            if let dog = displayDog {
                HStack(spacing: 8) {
                    DogImageView(imageData: dog.imageData, size: 32)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(dog.name)
                            .font(.caption)
                            .fontWeight(.medium)
                            .lineLimit(1)
                        
                        if let lastWalk = dog.lastWalk {
                            Text(timeAgo(from: lastWalk.date))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        } else {
                            Text("No walks")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    if let lastWalk = dog.lastWalk {
                        WalkTypeIcon(walkType: lastWalk.walkType, size: .small)
                    }
                }
                
                Spacer()
                
                // Quick action button
                Button(intent: LogWalkIntent(dogID: dog.id, walkType: .walk)) {
                    HStack(spacing: 4) {
                        Image(systemName: "figure.walk")
                            .font(.caption2)
                        Text("Walk")
                            .font(.caption2)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.accentColor)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            } else {
                Text("No Dogs")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(12)
    }
}

// MARK: - Medium Widget (2x1)
struct MediumWidgetView: View {
    let dogs: [DogData]
    let settings: SharedDataManager.WidgetDisplaySettings
    
    private var displayDogs: [DogData] {
        if settings.showAllDogs {
            return Array(dogs.prefix(2))
        } else if let preferredID = settings.preferredDogID,
                  let dog = dogs.first(where: { $0.id == preferredID }) {
            return [dog]
        }
        return Array(dogs.prefix(1))
    }
    
    var body: some View {
        VStack(spacing: 8) {
            // Dog info section
            VStack(spacing: 6) {
                ForEach(displayDogs, id: \.id) { dog in
                    DogRowView(dog: dog)
                }
            }
            
            Spacer()
            
            // Action buttons
            if let firstDog = displayDogs.first {
                HStack(spacing: 8) {
                    Button(intent: LogWalkIntent(dogID: firstDog.id, walkType: .walk)) {
                        Label("Walk", systemImage: "figure.walk")
                            .font(.caption)
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.blue)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    
                    Button(intent: LogWalkIntent(dogID: firstDog.id, walkType: .walkAndPoop)) {
                        Label("Walk + Poop", systemImage: "leaf.fill")
                            .font(.caption)
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.brown)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(12)
    }
}

// MARK: - Large Widget (2x2)
struct LargeWidgetView: View {
    let dogs: [DogData]
    let settings: SharedDataManager.WidgetDisplaySettings
    
    var body: some View {
        VStack(spacing: 12) {
            // Header
            HStack {
                Text("Dog Walks")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
                Text("Last Update: \(Date(), style: .time)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            // Dogs list
            VStack(spacing: 8) {
                ForEach(dogs.prefix(3), id: \.id) { dog in
                    DogRowView(dog: dog, showActions: true)
                }
            }
            
            Spacer()
            
            // Summary
            if !dogs.isEmpty {
                HStack {
                    Text("\(dogs.count) dog\(dogs.count == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    let walksToday = dogs.compactMap { $0.lastWalk }.filter { 
                        Calendar.current.isDateInToday($0.date) 
                    }.count
                    
                    Text("\(walksToday) walk\(walksToday == 1 ? "" : "s") today")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(16)
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
        VStack(spacing: 8) {
            Image(systemName: "pawprint.circle")
                .font(.title2)
                .foregroundColor(.gray)
            
            Text("No Dogs")
                .font(.caption)
                .fontWeight(.medium)
            
            Text("Add a dog in the app")
                .font(.caption2)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
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
        StaticConfiguration(kind: kind, provider: WalkWidgetProvider()) { entry in
            WalkWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Dog Walks")
        .description("Track your dog's walks and see the latest activity.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

// MARK: - Preview
#Preview(as: .systemSmall) {
    WpoopedFebWidget()
} timeline: {
    WalkWidgetEntry.placeholder
}

#Preview(as: .systemMedium) {
    WpoopedFebWidget()
} timeline: {
    WalkWidgetEntry.placeholder
}

#Preview(as: .systemLarge) {
    WpoopedFebWidget()
} timeline: {
    WalkWidgetEntry.placeholder
}

