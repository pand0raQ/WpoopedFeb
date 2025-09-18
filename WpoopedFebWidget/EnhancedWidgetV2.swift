//
//  EnhancedWidgetV2.swift
//  WpoopedFebWidget
//
//  Enhanced Traditional Widgets with iOS 26 Interactive Snippets
//

import WidgetKit
import SwiftUI
import AppIntents

// MARK: - Enhanced Widget Provider

struct EnhancedWalkWidgetProvider: AppIntentTimelineProvider {
    typealias Entry = EnhancedWalkWidgetEntry
    typealias Intent = EnhancedDogSelectionConfigurationIntent

    func placeholder(in context: Context) -> EnhancedWalkWidgetEntry {
        EnhancedWalkWidgetEntry.placeholder
    }

    func snapshot(for configuration: EnhancedDogSelectionConfigurationIntent, in context: Context) async -> EnhancedWalkWidgetEntry {
        return createEntry(for: configuration)
    }

    func timeline(for configuration: EnhancedDogSelectionConfigurationIntent, in context: Context) async -> Timeline<EnhancedWalkWidgetEntry> {
        let currentEntry = createEntry(for: configuration)

        // More conservative refresh for traditional widgets
        let nextRefresh = Calendar.current.date(byAdding: .minute, value: 5, to: Date())!
        return Timeline(entries: [currentEntry], policy: .after(nextRefresh))
    }

    private func createEntry(for configuration: EnhancedDogSelectionConfigurationIntent? = nil) -> EnhancedWalkWidgetEntry {
        let dogs = SharedDataManager.shared.getAllDogs()

        return EnhancedWalkWidgetEntry(
            date: Date(),
            dogs: dogs,
            selectedDogID: configuration?.selectedDog?.id,
            lastUpdateTime: SharedDataManager.shared.getLastUpdateTimestamp()
        )
    }
}

// MARK: - Enhanced Timeline Entry

struct EnhancedWalkWidgetEntry: TimelineEntry {
    let date: Date
    let dogs: [DogData]
    let selectedDogID: String?
    let lastUpdateTime: Date?

    static let placeholder = EnhancedWalkWidgetEntry(
        date: Date(),
        dogs: [DogData.sample],
        selectedDogID: nil,
        lastUpdateTime: Date()
    )
}

// MARK: - Main Enhanced Widget View

struct EnhancedWalkWidgetView: View {
    let entry: EnhancedWalkWidgetEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        Group {
            switch family {
            case .systemSmall:
                SmallEnhancedWidgetView(entry: entry)
            case .systemMedium:
                MediumEnhancedWidgetView(entry: entry)
            case .systemLarge:
                LargeEnhancedWidgetView(entry: entry)
            @unknown default:
                MediumEnhancedWidgetView(entry: entry)
            }
        }
    }
}

// MARK: - Small Widget View

struct SmallEnhancedWidgetView: View {
    let entry: EnhancedWalkWidgetEntry

    private var selectedDog: DogData? {
        if let selectedDogID = entry.selectedDogID {
            return entry.dogs.first { $0.id == selectedDogID }
        }
        return entry.dogs.first
    }

    var body: some View {
        if let dog = selectedDog {
            VStack(spacing: 8) {
                // Dog header
                HStack {
                    DogAvatarView(dogID: dog.id, size: 32)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(dog.name)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .lineLimit(1)

                        if let lastWalk = dog.lastWalk {
                            Text(timeAgo(from: lastWalk.date))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        } else {
                            Text("No walks")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }

                    Spacer()
                }

                Spacer()

                // Quick action button
                Button(intent: LogWalkIntent(dogID: dog.id, walkType: .walk)) {
                    Text("Walk")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color.blue)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }
            .padding(12)
        } else {
            NoDogSelectedView()
        }
    }
}

// MARK: - Medium Widget View

struct MediumEnhancedWidgetView: View {
    let entry: EnhancedWalkWidgetEntry

    private var selectedDog: DogData? {
        if let selectedDogID = entry.selectedDogID {
            return entry.dogs.first { $0.id == selectedDogID }
        }
        return entry.dogs.first
    }

    var body: some View {
        if let dog = selectedDog {
            VStack(spacing: 12) {
                // Dog header with status
                HStack(spacing: 12) {
                    DogAvatarView(dogID: dog.id, size: 50)

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
                                    Text("Last: \(timeAgo(from: lastWalk.date))")
                                        .font(.caption)
                                        .foregroundColor(.secondary)

                                    WalkTypeIcon(walkType: lastWalk.walkType, size: .small)
                                }

                                if Calendar.current.isDateInToday(lastWalk.date) {
                                    Text("✓ Walked today")
                                        .font(.caption2)
                                        .foregroundColor(.green)
                                }
                            }
                        } else {
                            Text("No walks today")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    Spacer()

                    // Data freshness indicator
                    DataFreshnessIndicator()
                }

                // Enhanced action buttons
                HStack(spacing: 10) {
                    Button(intent: LogWalkIntent(dogID: dog.id, walkType: .walk)) {
                        ActionButtonContent(
                            icon: "figure.walk",
                            text: "Walk",
                            color: .blue
                        )
                    }
                    .buttonStyle(.plain)

                    Button(intent: LogWalkIntent(dogID: dog.id, walkType: .walkAndPoop)) {
                        ActionButtonContent(
                            icon: "leaf.fill",
                            text: "Walk + Poop",
                            color: .brown
                        )
                    }
                    .buttonStyle(.plain)

                    Button(intent: TestIntent()) {
                        ActionButtonContent(
                            icon: "list.bullet",
                            text: "History",
                            color: .gray,
                            isSecondary: true
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(16)
        } else {
            NoDogSelectedView()
        }
    }
}

// MARK: - Large Widget View

struct LargeEnhancedWidgetView: View {
    let entry: EnhancedWalkWidgetEntry

    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Text("Dog Walks")
                    .font(.title2)
                    .fontWeight(.bold)

                Spacer()

                DataFreshnessIndicator()
            }

            if entry.dogs.isEmpty {
                Spacer()
                NoDogSelectedView()
                Spacer()
            } else {
                // Dog list with actions
                VStack(spacing: 12) {
                    ForEach(entry.dogs.prefix(3), id: \.id) { dog in
                        LargeDogRowView(dog: dog)
                    }
                }

                Spacer()

                // Global actions
                HStack(spacing: 12) {
                    Button(intent: TestIntent()) {
                        HStack {
                            Image(systemName: "pawprint.2.fill")
                            Text("Walk All Dogs")
                        }
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.blue)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)

                    Button(intent: TestIntent()) {
                        HStack {
                            Image(systemName: "clock.fill")
                            Text("Recent Walks")
                        }
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.blue)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.blue.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(16)
    }
}

// MARK: - Large Dog Row View

struct LargeDogRowView: View {
    let dog: DogData

    var body: some View {
        HStack(spacing: 12) {
            DogAvatarView(dogID: dog.id, size: 40)

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
                    Text("No walks today")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // Quick action buttons
            HStack(spacing: 6) {
                Button(intent: LogWalkIntent(dogID: dog.id, walkType: .walk)) {
                    Image(systemName: "figure.walk")
                        .font(.caption)
                        .foregroundColor(.blue)
                        .frame(width: 28, height: 28)
                        .background(Color.blue.opacity(0.1))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)

                Button(intent: LogWalkIntent(dogID: dog.id, walkType: .walkAndPoop)) {
                    Image(systemName: "leaf.fill")
                        .font(.caption)
                        .foregroundColor(.brown)
                        .frame(width: 28, height: 28)
                        .background(Color.brown.opacity(0.1))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Helper Views

struct ActionButtonContent: View {
    let icon: String
    let text: String
    let color: Color
    let isSecondary: Bool

    init(icon: String, text: String, color: Color, isSecondary: Bool = false) {
        self.icon = icon
        self.text = text
        self.color = color
        self.isSecondary = isSecondary
    }

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
            Text(text)
                .font(.caption)
                .fontWeight(.medium)
        }
        .foregroundColor(isSecondary ? color : .white)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(isSecondary ? color.opacity(0.1) : color)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// DataFreshnessIndicator is defined in WpoopedFebWidget.swift

struct NoDogSelectedView: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "pawprint.circle")
                .font(.largeTitle)
                .foregroundColor(.gray)

            Text("No Dogs Found")
                .font(.headline)
                .fontWeight(.medium)

            Text("Open the app to add dogs")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }
}

// MARK: - Enhanced Configuration Intent

struct EnhancedDogSelectionConfigurationIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Select Dog"
    static var description = IntentDescription("Choose which dog to feature in the widget")

    @Parameter(title: "Dog", description: "Select the dog for this widget")
    var selectedDog: DogEntity?

    init() {}

    init(selectedDog: DogEntity?) {
        self.selectedDog = selectedDog
    }
}

// MARK: - Main Enhanced Widget Configuration

struct EnhancedWpoopedFebWidget: Widget {
    let kind: String = "EnhancedWpoopedFebWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: EnhancedDogSelectionConfigurationIntent.self,
            provider: EnhancedWalkWidgetProvider()
        ) { entry in
            EnhancedWalkWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Enhanced Dog Walks")
        .description("Track your dog's walks with enhanced interactive features and iOS 26 snippet support.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

// MARK: - Helper Functions

private func timeAgo(from date: Date) -> String {
    let interval = Date().timeIntervalSince(date)

    if interval < 60 {
        return "now"
    } else if interval < 3600 {
        let minutes = Int(interval / 60)
        return "\(minutes)m"
    } else if interval < 86400 {
        let hours = Int(interval / 3600)
        return "\(hours)h"
    } else {
        let days = Int(interval / 86400)
        return "\(days)d"
    }
}