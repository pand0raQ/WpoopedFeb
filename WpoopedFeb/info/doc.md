# WpoopedFeb Project Documentation

This document provides an overview of the WpoopedFeb project, its architecture, and key components. The purpose is to give an AI assistant sufficient context to understand the project and assist with development tasks.

## Overview

WpoopedFeb is an iOS application built with SwiftUI and SwiftData that allows users to register, manage, and share information about their dogs. It utilizes CloudKit for data synchronization and sharing between users. The app features user authentication via Apple Sign-In, image uploading and cropping, QR code generation for sharing, and a profile view to manage user data.

## Architecture

The application follows the Model-View-ViewModel (MVVM) architectural pattern. This separates the user interface (View) from the business logic (ViewModel) and the data model (Model).

*   **Model:** Represents the data and data access layer. This includes `Dog` (SwiftData model) and data managers like `AuthManager` and `CloudKitManager`.
*   **View:**  The user interface, responsible for displaying data and handling user interactions.  Views are defined using SwiftUI.
*   **ViewModel:**  Acts as an intermediary between the View and the Model.  It provides data to the View in a format it can easily display and handles user interactions by updating the Model.

## Key Components

### 1. Authentication (`authModule.swift`)

*   **`AuthManager`:** A singleton class (`static let shared`) that manages user authentication using Apple Sign-In. It handles signing in, signing out, and persisting user data. It conforms to `ASAuthorizationControllerDelegate` and `ASAuthorizationControllerPresentationContextProviding`.
    ```swift:WpoopedFeb/shared(usedEverywhere)/authModule.swift
    startLine: 7
    endLine: 111
    ```
*   **`UserData`:** A struct representing the user's data (ID, name, email, sign-up date).
    ```swift:WpoopedFeb/shared(usedEverywhere)/authModule.swift
    startLine: 17
    endLine: 26
    ```
*   **Authentication State:** The `isAuthenticated` property (published using `@Published`) tracks the user's authentication status.
    ```swift:WpoopedFeb/shared(usedEverywhere)/authModule.swift
    startLine: 12
    endLine: 12
    ```

### 2. Data Models

*   **`Dog` (`Dog.swift`):** The core data model representing a dog. It uses SwiftData for local persistence and conforms to the `CloudKitSyncable` protocol for CloudKit integration.
    ```swift:WpoopedFeb/shared(usedEverywhere)/Dog.swift
    startLine: 1
    endLine: 202
    ```
    *   **`CloudKitSyncable`:** A protocol defining methods for converting between `Dog` objects and `CKRecord` objects for CloudKit synchronization.
        ```swift:WpoopedFeb/shared(usedEverywhere)/Dog.swift
        startLine: 6
        endLine: 9
        ```
    *   **`qrCodeData`:** Stores the QR code data in `UserDefaults` for efficient access.
        ```swift:WpoopedFeb/shared(usedEverywhere)/Dog.swift
        startLine: 34
        endLine: 45
        ```
    *   **`shareOwnerName`:** Stores the CloudKit owner name from share metadata when a share is accepted, used for dynamic zone ID determination.
        ```swift:WpoopedFeb/shared(usedEverywhere)/Dog.swift
        startLine: 22
        endLine: 22
        ```
    *   **`getZoneID()`:** Helper method that returns the correct CloudKit zone ID based on sharing status and owner information.
        ```swift:WpoopedFeb/shared(usedEverywhere)/Dog.swift
        startLine: 98
        endLine: 107
        ```
    *   **`saveToCloudKit()`:** Saves the `Dog` object to CloudKit, including handling image assets.
        ```swift:WpoopedFeb/shared(usedEverywhere)/Dog.swift
        startLine: 73
        endLine: 88
        ```
    *   **`toCKRecord()` and `fromCKRecord()`:** Implement the `CloudKitSyncable` protocol for conversion to and from `CKRecord`.
        ```swift:WpoopedFeb/shared(usedEverywhere)/Dog.swift
        startLine: 95
        endLine: 201
        ```
    *   **Access Control:**
        ```swift:WpoopedFeb/shared(usedEverywhere)/Dog.swift
        var permissions: CKShare.Permission?
        var sharedBy: String?  // Owner's user ID
        var sharedWith: [String] = []  // Co-parent IDs
        
        var isOwnedByCurrentUser: Bool {
            sharedBy == nil || sharedBy == AuthManager.shared.currentUser()?.id
        }
        
        var canEdit: Bool {
            guard let permissions else { return true }
            return permissions.contains(.readWrite) 
            && isOwnedByCurrentUser
        }
        ```

### 3. CloudKit Management

*   **`CloudKitManager` (`cloudkit_main.swift`):** A singleton class that handles interactions with CloudKit. It provides methods for saving, updating, deleting, and fetching `Dog` records.
    ```swift:WpoopedFeb/shared(usedEverywhere)/cloudkit_main.swift
    startLine: 1
    endLine: 178
    ```
    *   **`save(_:)`, `update(_:)`, `delete(_:)`, `fetchDogs()`:** Core CloudKit operations.
        ```swift:WpoopedFeb/shared(usedEverywhere)/cloudkit_main.swift
        startLine: 50
        endLine: 160
        ```
    *   **`createAsset(from:filename:)`:** Creates a `CKAsset` from image data.
        ```swift:WpoopedFeb/shared(usedEverywhere)/cloudkit_main.swift
        startLine: 163
        endLine: 177
        ```
*   **`CloudKitSharingManager` (`cloudkit_sharing_manager.swift`):** Handles CloudKit sharing functionality, allowing users to share `Dog` records with others.
    ```swift:WpoopedFeb/shared(usedEverywhere)/cloudkit_sharing_manager.swift
    startLine: 1
    endLine: 110
    ```
    *   **`shareDog(_:)`:** Creates or retrieves a `CKShare` for a given `Dog` object. Sets public permission to `.readWrite`.
        ```swift:WpoopedFeb/shared(usedEverywhere)/cloudkit_sharing_manager.swift
        startLine: 21
        endLine: 107
        ```
    *   **`acceptShare(from:context:)`:** Handles accepting a CloudKit share from a URL. Extracts and stores the owner's information from share metadata for proper zone identification.
        ```swift:WpoopedFeb/shared(usedEverywhere)/cloudkit_sharing_manager.swift
        startLine: 146
        endLine: 184
        ```
    *   **`fetchShareMetadata(from:)`:** Fetches share metadata from a URL, used for extracting owner information and validating shares.
        ```swift:WpoopedFeb/shared(usedEverywhere)/cloudkit_sharing_manager.swift
        startLine: 112
        endLine: 128
        ```
*   **`ShareQRGenerator` (`share_QR_generator.swift`):** Generates QR codes from URLs, used for sharing dogs.
    ```swift:WpoopedFeb/shared(usedEverywhere)/share_QR_generator.swift
    startLine: 1
    endLine: 97
    ```
    * **`QRCodeGenerator`:** Handles actual QR image generation
*   **`SharingURLGenerator`:** (Referenced but not included in code snippets) Responsible for generating sharing URLs from `CKShare` objects.

### 4. Views and ViewModels

*   **`ContentView` (`ContentView.swift`):** The main view of the application, displaying the list of dogs (`DogsListView`).
    ```swift:WpoopedFeb/views(onlyUiParts)/ContentView.swift
    startLine: 1
    endLine: 38
    ```

*   **`DogsListView` (`dogs_list_view.swift`):** Displays a list of dogs and provides navigation to `DogDetailView`. Includes a button to add new dogs via `DogRegistrationView`.
    ```swift:WpoopedFeb/views(onlyUiParts)/dogs_list_view.swift
    startLine: 1
    endLine: 85
    ```
    *   **`DogRowView`:** A custom view for displaying a single dog in the list.
        ```swift:WpoopedFeb/views(onlyUiParts)/dogs_list_view.swift
        startLine: 35
        endLine: 76
        ```
    *   **Owner-Specific Features:**
        ```swift:WpoopedFeb/views(onlyUiParts)/dogs_list_view.swift
        // Context menu shows different options based on ownership
        .contextMenu {
            if dog.isOwnedByCurrentUser {
                Button("Delete", role: .destructive) { deleteDog(dog) }
            } else {
                Text("Shared by \(dog.ownerName)")
                Button("Stop Sharing") { removeSharedDog(dog) }
            }
        }
        ```
    *   **Debug Tools:** (Development Only) Contains test buttons for manual CloudKit operations

*   **`DogDetailView` (`dog_detail_view.swift`) and `DogDetailViewModel` (`dogdetail_data.swift`):** Displays details of a selected dog, including the image, name, and sharing status.  Provides functionality for sharing the dog via QR code.
    ```swift:WpoopedFeb/views(onlyUiParts)/dog_detail_view.swift
    startLine: 1
    endLine: 118
    ```
    ```swift:WpoopedFeb/views_data(onlyDataUsedInViews/dogdetail_data.swift
    startLine: 1
    endLine: 68
    ```
    *   **`shareButtonTapped()`:** Initiates the dog sharing process.
        ```swift:WpoopedFeb/views_data(onlyDataUsedInViews/dogdetail_data.swift
        startLine: 21
        endLine: 43
        ```
    *   **`generateQRCode()`:** Generates or retrieves the QR code for sharing.
        ```swift:WpoopedFeb/views_data(onlyDataUsedInViews/dogdetail_data.swift
        startLine: 45
        endLine: 62
        ```
    *   **Owner-Specific Features:**
        ```swift:WpoopedFeb/views(onlyUiParts)/dog_detail_view.swift
        // Shows sharing controls and QR code
        if viewModel.dog.isShared {
            Image(systemName: "person.2.fill")
            Text("Shared with \(viewModel.dog.coParents.count) people")
            ShareLink(item: viewModel.dog.shareURL!) {
                Label("Share", systemImage: "square.and.arrow.up")
            }
        }
        ```

*   **`DogRegistrationView` (`dog_registration_view.swift`):** Allows users to register a new dog, including selecting and cropping an image.
    ```swift:WpoopedFeb/views(onlyUiParts)/dog_registration_view.swift
    startLine: 1
    endLine: 94
    ```
    *   **`ImagePicker`:** A `UIViewControllerRepresentable` struct that integrates `PHPickerViewController` for image selection.
        ```swift:WpoopedFeb/views(onlyUiParts)/dog_registration_view.swift
        startLine: 96
        endLine: 134
        ```
    *   **`ImageCropperView`:** A custom view for cropping the selected image.
        ```swift:WpoopedFeb/views(onlyUiParts)/dog_registration_view.swift
        startLine: 136
        endLine: 235
        ```
    *   **`saveDog()`:** Creates a new `Dog` object and saves it to SwiftData and CloudKit.
        ```swift:WpoopedFeb/views(onlyUiParts)/dog_registration_view.swift
        startLine: 76
        endLine: 93
        ```

*   **`ProfileView` (`profile_view_data.swift`) and `ProfileViewModel` (`profile_view_model.swift`):** Displays user profile information and provides options for signing out and deleting all user data.
    ```swift:WpoopedFeb/views(onlyUiParts)/profile_view_data.swift
    startLine: 1
    endLine: 49
    ```
    ```swift:WpoopedFeb/views_data(onlyDataUsedInViews/profile_view_model.swift
    startLine: 1
    endLine: 56
    ```
    *   **`deleteAllUserData()`:** Deletes all local data (SwiftData and UserDefaults) and signs the user out.
        ```swift:WpoopedFeb/views_data(onlyDataUsedInViews/profile_view_model.swift
        startLine: 29
        endLine: 41
        ```

*   **`WelcomeView` (`welcome_view.swift`):** The initial view presented to users who are not signed in.  Provides an introduction and prompts the user to sign in with Apple.
    ```swift:WpoopedFeb/views(onlyUiParts)/welcome_view.swift
    startLine: 1
    endLine: 137
    ```

### 5. Share Acceptance Handling

*   **`QRScannerView` (`QRScannerView.swift`):** A SwiftUI view that handles QR code scanning and URL processing.
    ```swift:WpoopedFeb/views(onlyUiParts)/QRScannerView.swift
    startLine: 1
    endLine: [new implementation]
    ```
    
*   **`QRScannerViewModel` (`QRscanner_data.swift`):** Handles the business logic for processing scanned URLs and share acceptance.
    ```swift:WpoopedFeb/views_data(onlyDataUsedInViews)/QRscanner_data.swift
    // ... existing code ...
    
    /// Processes a scanned URL containing CloudKit share metadata
    func handleScannedURL(_ url: URL) async {
        guard let shareMetadata = await getShareMetadata(from: url) else {
            // Handle invalid URL error
            return
        }
        
        do {
            try await CloudKitSharingManager.shared.acceptShare(metadata: shareMetadata)
            // Handle successful acceptance
        } catch {
            // Handle acceptance error
        }
    }
    
    /// Extracts CloudKit share metadata from a URL
    private func getShareMetadata(from url: URL) async -> CKShare.Metadata? {
        return try? await CKContainer.default().shareMetadata(for: url)
    }
    
    // ... existing code ...
    ```

*   **Access Control in Dog Model:**
    ```swift:WpoopedFeb/shared(usedEverywhere)/Dog.swift
    // ... existing model properties ...
    
    var permissions: CKShare.Permission?
    var sharedBy: String?  // Owner's user ID
    var sharedWith: [String] = []  // Co-parent IDs
    
    var isOwnedByCurrentUser: Bool {
        sharedBy == nil || sharedBy == AuthManager.shared.currentUser()?.id
    }
    
    var canEdit: Bool {
        guard let permissions else { return true }
        return permissions.contains(.readWrite) 
        && isOwnedByCurrentUser
    }
    ```
## Data Flow

1.  **User Authentication:**
    *   The app checks the authentication state on launch.
    *   If the user is not authenticated, `WelcomeView` is shown.
    *   `AuthManager` handles the Apple Sign-In process.
    *   User data is stored in `UserDefaults` upon successful sign-in.

2.  **Dog Registration:**
    *   Users can add new dogs through `DogRegistrationView`.
    *   `Dog` objects are created and saved to SwiftData.
    *   `Dog.saveToCloudKit()` is called to synchronize data with CloudKit.

3.  **Dog Listing and Details:**
    *   `DogsListView` displays the list of dogs fetched from SwiftData.
    *   `DogDetailView` shows details of a selected dog.

4.  **Dog Sharing:**
    *   `DogDetailView` initiates sharing via `CloudKitSharingManager.shareDog()`.
    *   A `CKShare` is created (or retrieved if it already exists).
    *   A sharing URL is generated.
    *   A QR code is generated from the sharing URL and stored in `UserDefaults`.
    *   The `Dog` object is updated with sharing information.

5.  **Data Synchronization:**
    *   Data is saved to CloudKit when a new `Dog` is created and when a dog is shared.
    *   The project includes a `fetchDogs()` method in `CloudKitManager`, but lacks automatic sync triggers. Implement periodic fetching and change token tracking.

6. **Cross-Device Sharing Visualization:**
    ````
    Owner Device                          CloudKit                           Co-Parent Device
         │                                    │                                    │
         │ 1. Create CKShare for Dog          │                                    │
         │───────────────────────────────────>│                                    │
         │                                    │                                    │
         │ 2. Generate QR from Share URL     │                                    │
         │<───────────────────────────────────│                                    │
         │                                    │                                    │
         │                                    │ 3. Scan QR Code & Accept Share     │
         │                                    │<───────────────────────────────────│
         │                                    │                                    │
         │                                    │ 4. Extract Owner Name from Share   │
         │                                    │───────────────────────────────────>│
         │                                    │                                    │
         │                                    │ 5. Store Owner Name for Zone ID    │
         │                                    │───────────────────────────────────>│
         │                                    │                                    │
         │ 6. Sync Updates (Dogs & Walks)    │                                    │
         │<──────────────────────────────────>───────────────────────────────────>│
    ````

## Key Considerations

*   **CloudKit Synchronization:** Implementing a robust synchronization strategy between SwiftData and CloudKit is essential for data consistency. This includes handling conflicts, offline access, and updates from multiple devices.
*   **Error Handling:** The project includes some error handling, but it should be expanded to cover more cases and provide user-friendly error messages.
*   **Testing:** Unit and UI tests are crucial for ensuring the stability and correctness of the code.
*   **Share Metadata Validation:** Ensure URLs contain valid CloudKit share metadata before attempting acceptance
*   **Error Handling:** Provide clear feedback for invalid URLs, expired shares, and permission issues using `CloudKitManagerError` cases
*   **UI Feedback:** Implement loading states and success/error alerts during the acceptance process
*   **Data Refresh:** After successful acceptance, trigger a refresh of the dog list to show newly shared records
*   **Access Control:** Implement role-based permissions using `CKShare.Permission` levels
*   **Ownership Detection:** Use `isOwnedByCurrentUser` to differentiate UI/UX
*   **Permission Propagation:** Ensure permission changes sync across all devices
*   **UI Differentiation:** Clearly distinguish owned vs shared records using:
  - Different iconography (person.2.fill vs person.fill)
  - Color coding (blue for owned, gray for shared)
  - Contextual menu options
*   **Sync Indicators:** Show last sync time and CloudKit status icons
*   **Conflict Resolution:** Implement version tracking for concurrent edits

## Known Issues

1. **Permission Handling:** 
   - `canEdit` check uses incorrect `.readWrite` instead of checking share participant permissions
   - Missing role-based permission propagation between devices

2. **Sync Indicators:**
   - Last sync time tracking not implemented
   - CloudKit status icons missing from UI

3. **Conflict Resolution:**
   - No version tracking for concurrent edits
   - No merge strategy implementation

4. **Walk Sharing:**
   - Walks are now properly shared between users with dynamic zone ID handling
   - Both users can log walks for shared dogs and see each other's logged walks
   - The app stores the share owner's name from metadata when a share is accepted
   - This owner name is used to dynamically determine the correct zone ID for CloudKit operations





