# WpoopedFeb - CloudKit to Firebase Migration

This project has been migrated from CloudKit to Firebase Firestore for data storage and synchronization. This README provides instructions on how to complete the setup process.

## Migration Overview

The following components have been migrated:
- Dog model: Updated to use Firestore instead of CloudKit
- Walk model: Updated to use Firestore instead of CloudKit
- Sharing functionality: Reimplemented using Firestore
- Authentication: Added Firebase Authentication

## Setup Instructions

### 1. Install Firebase SDK

First, install the Firebase SDK using CocoaPods:

```bash
cd /path/to/WpoopedFeb
pod install
```

### 2. Create a Firebase Project

1. Go to the [Firebase Console](https://console.firebase.google.com/)
2. Create a new project
3. Add an iOS app to the project
   - Use the bundle ID: `bumblebee.WpoopedFeb`
   - Download the `GoogleService-Info.plist` file
   - Replace the placeholder file in the project with the downloaded file

### 3. Enable Firebase Services

In the Firebase Console, enable the following services:
- Authentication (Email/Password)
- Firestore Database
- Storage
- Cloud Messaging (optional, for notifications)

### 4. Set Up Firestore Security Rules

In the Firebase Console, go to Firestore Database > Rules and set up appropriate security rules:

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /dogs/{dogId} {
      allow read, write: if request.auth != null;
    }
    match /walks/{walkId} {
      allow read, write: if request.auth != null;
    }
    match /shares/{shareId} {
      allow read, write: if request.auth != null;
    }
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
  }
}
```

### 5. Set Up Storage Rules

In the Firebase Console, go to Storage > Rules and set up appropriate security rules:

```
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    match /dogs/{imageId} {
      allow read: if request.auth != null;
      allow write: if request.auth != null;
    }
  }
}
```

## Data Migration

If you need to migrate existing data from CloudKit to Firebase, you can use the following approach:

1. Fetch all dogs and walks from CloudKit
2. Convert each item to the Firestore format
3. Save each item to Firestore

Example code for migration (to be run once):

```swift
Task {
    // Migrate dogs
    let dogs = try await CloudKitManager.shared.fetchAllDogs()
    for dog in dogs {
        await dog.saveToFirestore()
    }
    
    // Migrate walks
    for dog in dogs {
        let walks = try await CloudKitManager.shared.fetchWalks(for: dog)
        for walk in walks {
            await walk.saveToFirestore()
        }
    }
}
```

## Removed CloudKit Files

The following CloudKit-related files are no longer needed and can be removed:
- `cloudkit_main.swift`
- `cloudkit_sharing_manager.swift`

## New Firebase Files

The following new files have been added:
- `firebase_main.swift`: Main Firebase manager
- `firebase_sharing_manager.swift`: Handles sharing functionality
- `FirebaseNotifications.swift`: Handles Firebase notifications
- `FirestoreError.swift`: Error types for Firestore operations
- `AuthManager.swift`: Handles Firebase authentication
- `SharingURLGenerator.swift`: Utility for generating sharing URLs
- `WelcomeView.swift`: Authentication UI

## Testing

After completing the setup, test the following functionality:
1. User authentication (sign up and sign in)
2. Creating and saving dogs
3. Adding walks to dogs
4. Sharing dogs with other users
5. Image upload and download

## Troubleshooting

If you encounter issues:
1. Check that the Firebase SDK is properly installed
2. Verify that the `GoogleService-Info.plist` file is correctly configured
3. Ensure that the required Firebase services are enabled
4. Check the console logs for any Firebase-specific errors
