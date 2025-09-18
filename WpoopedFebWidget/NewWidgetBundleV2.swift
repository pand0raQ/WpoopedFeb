//
//  NewWidgetBundleV2.swift
//  WpoopedFebWidget
//
//  Complete Widget Bundle with iOS 26 Interactive Snippets & Control Widgets
//

import WidgetKit
import SwiftUI
import AppIntents

// Alternative widget bundle implementation - not used as @main
struct NewWpoopedFebWidgetBundle: WidgetBundle {
    var body: some Widget {
        // Traditional Home Screen Widgets
        EnhancedWpoopedFebWidget()

        // iOS 18+ Control Widgets (with iOS 26 snippet integration)
        if #available(iOS 18.0, *) {
            QuickWalkControlWidget()
            DogSelectionControlWidget()
            WalkTypeToggleControlWidget()
            MultiDogQuickActionsControlWidget()
        }

        // Legacy widget for backwards compatibility
        LegacyWpoopedFebWidget()
    }
}

// MARK: - Legacy Widget for Backwards Compatibility

struct LegacyWpoopedFebWidget: Widget {
    let kind: String = "LegacyWpoopedFebWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: DogSelectionConfigurationIntent.self,
            provider: WalkWidgetProvider()
        ) { entry in
            WalkWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Dog Walks (Legacy)")
        .description("Compatible widget for older iOS versions.")
        .supportedFamilies([.systemMedium])
    }
}

// MARK: - Shared Component Views
// WalkTypeIcon is defined in WpoopedFebWidget.swift

// MARK: - Preview Support

#Preview("Enhanced Widget - Medium", as: .systemMedium) {
    EnhancedWpoopedFebWidget()
} timeline: {
    EnhancedWalkWidgetEntry.placeholder
}

#Preview("Enhanced Widget - Small", as: .systemSmall) {
    EnhancedWpoopedFebWidget()
} timeline: {
    EnhancedWalkWidgetEntry.placeholder
}

#Preview("Enhanced Widget - Large", as: .systemLarge) {
    EnhancedWpoopedFebWidget()
} timeline: {
    EnhancedWalkWidgetEntry.placeholder
}

#Preview("Legacy Widget", as: .systemMedium) {
    LegacyWpoopedFebWidget()
} timeline: {
    WalkWidgetEntry.placeholder
}

// MARK: - iOS 26 Snippet Previews

@available(iOS 26.0, *)
#Preview("Walk Confirmation Snippet") {
    WalkConfirmationSnippetView(
        result: WalkResult(
            walkData: WalkData(
                id: "preview-walk",
                dogID: "preview-dog",
                date: Date(),
                walkType: .walk,
                ownerName: "Preview User"
            ),
            syncStatus: .synced,
            coParentNotified: true
        ),
        walkStore: WalkDataStore.shared
    )
}

// iOS 26 Snippet previews - commented out for now as they require full implementation
// @available(iOS 26.0, *)
// #Preview("Dog Selection Snippet") {
//     DogSelectionSnippetView(walkStore: WalkDataStore.shared)
// }

@available(iOS 26.0, *)
#Preview("Recent Walks Snippet") {
    RecentWalksSnippetView(walkStore: WalkDataStore.shared)
}

// MARK: - Control Widget Previews (iOS 18+)
// Note: Control Widget previews require special handling in Xcode
// They can be tested using the Control Gallery in the Simulator