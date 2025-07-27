# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

WpoopedFeb is an iOS dog walking tracking app built with SwiftUI and recently migrated from CloudKit to Firebase. The app allows users to register dogs, track walks, and share dogs with other users. It includes a home screen widget for quick walk logging.

## Architecture

### Core Data Flow
- **SwiftData**: Local persistence for offline capability with Dog and Walk models
- **Firebase**: Backend services including Firestore (database), Storage (images), and Auth (authentication)
- **Dual Sync**: The app maintains both local SwiftData and Firebase copies, syncing between them
- **Widget Integration**: Home screen widget can log walks that sync to Firebase when the main app opens

### Key Components
- **AuthManager**: Handles Firebase authentication and Apple Sign In
- **FirestoreManager** (in firebase_main.swift): Manages all Firebase operations
- **SharedDataManager**: Coordinates data between main app and widget
- **Dog/Walk Models**: SwiftData models with Firebase sync capabilities

### Authentication
- Supports both Firebase Auth (email/password) and Apple Sign In
- Uses Firebase UID as primary identifier when available
- Falls back to Apple ID for offline scenarios

## Development Commands

### Building the Project
```bash
# Install dependencies
pod install

# Build project (use workspace, not project file)
open WpoopedFeb.xcworkspace

# Clean build if having issues
# In Xcode: Product > Clean Build Folder (Shift+Command+K)

# Fix sandbox permission issues (if needed)
./build_fix.sh
```

### Firebase Setup
```bash
# Update Firebase rules
./update_firebase_rules.sh

# Check Firebase configuration
# Ensure GoogleService-Info.plist is properly configured
```

### Testing
The app has both local SwiftData and Firebase functionality that should be tested:
- User authentication (both Firebase and Apple Sign In)
- Creating and saving dogs (local + Firebase sync)
- Adding walks to dogs (local + Firebase sync)
- Dog sharing functionality
- Widget functionality
- Image upload/download

## File Structure

### Core App (`WpoopedFeb/`)
- `WpoopedFebApp.swift`: Main app entry point with authentication flow and widget sync
- `AppDelegate.swift`: Firebase configuration and push notifications

### Shared Models (`shared(usedEverywhere)/`)
- `Dog.swift`: Core dog model with SwiftData and Firebase sync
- `Walk.swift`: Walk tracking model with sync capabilities
- `AuthManager.swift`: Authentication management
- `firebase_main.swift`: Main Firebase operations manager
- `SharedDataManager.swift`: Widget-app data coordination

### Views (`views(onlyUiParts)/` and `views_data(onlyDataUsedInViews)/`)
- UI components separated from data/logic
- ContentView.swift: Main app interface
- Welcome flow for authentication

### Widget (`WpoopedFebWidget/`)
- Home screen widget for quick walk logging
- Syncs with main app via SharedDataManager

## Key Considerations

### Firebase Migration Context
This project was recently migrated from CloudKit to Firebase. Some legacy CloudKit references may still exist but should be replaced with Firebase equivalents.

### Build Issues
- The project includes build fix scripts for sandbox permission issues with Firebase dependencies
- Always use the `.xcworkspace` file, not the `.xcodeproj` file
- Custom rsync wrapper and xcconfig files resolve build sandbox issues

### Widget Sync
- Widget walks are stored locally first, then synced to Firebase when main app opens
- SharedDataManager coordinates between widget and main app
- Widget has its own data models that mirror the main app structure

### Authentication State
- App supports both authenticated and offline modes
- Uses sample data when authentication fails
- AuthDebugger provides detailed authentication state logging

## Firebase Configuration

The app requires proper Firebase setup:
- Firestore database with security rules (see firestore_rules.txt)
- Firebase Storage with appropriate rules (see storage_rules.txt)
- Firebase Authentication enabled
- Firebase Cloud Messaging for notifications
- GoogleService-Info.plist properly configured

## Dependencies

Key dependencies managed via CocoaPods:
- Firebase/Core, Firebase/Auth, Firebase/Firestore, Firebase/Storage, Firebase/Messaging, Firebase/Analytics
- Target iOS 16.0+
- Xcode 15+ compatibility fixes included