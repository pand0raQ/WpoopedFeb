//
//  WpoopedFebWidgetBundle.swift
//  WpoopedFebWidget
//
//  Updated to use iOS 26 Interactive Snippets & Control Widgets
//

import WidgetKit
import SwiftUI
import AppIntents

@main
struct WpoopedFebWidgetBundle: WidgetBundle {
    var body: some Widget {
        // Enhanced traditional widgets with iOS 26 snippet support
        EnhancedWpoopedFebWidget()

        // iOS 18+ Control Widgets with snippet integration
        if #available(iOS 18.0, *) {
            QuickWalkControlWidget()
            DogSelectionControlWidget()
            WalkTypeToggleControlWidget()
            MultiDogQuickActionsControlWidget()
        }

        // Legacy widget for backwards compatibility
        WpoopedFebWidget()
    }
}
