// all needed data for the dog detail view

import Foundation
import SwiftUI
import FirebaseFirestore
import SwiftData

@MainActor
class DogDetailViewModel: ObservableObject {
    @Published var dog: Dog
    @Published var showError = false
    @Published var errorMessage = ""
    @Published var isShowingQRCode = false
    @Published var isSharing = false
    @Published var shareError: Error?
    @Published var showingError = false
    @Published var isLoadingWalks = false
    @ObservationIgnored private let modelContext: ModelContext
    
    // Add a flag to prevent notification loops
    private var isHandlingNotification = false
    
    // Firestore listener for real-time updates
    private var walksListener: ListenerRegistration?
    
    // Track if listener is already set up
    private var isListenerSetup = false
    
    @Published var qrCodeImage: UIImage?
    
    init(dog: Dog, modelContext: ModelContext) {
        self.dog = dog
        self.modelContext = modelContext
        loadQRCode()
        
        // Set up real-time listener for walks - will be done in onAppear
        // setupWalksListener()
        
        // Still register for Firestore data change notifications as a fallback
        setupFirestoreNotifications()
    }
    
    deinit {
        // We need to handle this differently since deinit is synchronous
        // and we can't use await in deinit
        
        // Remove notification observer - this is safe to do from any thread
        NotificationCenter.default.removeObserver(self)
        
        // Remove Firestore listener - this is also safe from any thread
        walksListener?.remove()
        walksListener = nil
        isListenerSetup = false
        
        print("🔥 Cleaned up resources in deinit")
    }
    
    func onAppear() {
        // Set up the listener when the view appears if not already set up
        if !isListenerSetup {
            setupWalksListener()
            isListenerSetup = true
        }
    }
    
    func onDisappear() {
        // Clean up the listener when the view disappears
        // Do the cleanup directly here to avoid MainActor issues
        
        // Remove notification observer - this is safe to do from any thread
        NotificationCenter.default.removeObserver(self)
        
        // Remove Firestore listener - this is also safe from any thread
        if let listener = walksListener {
            listener.remove()
            walksListener = nil
            isListenerSetup = false
            print("🔥 Removed Firestore walks listener on disappear")
        }
        
        print("📳 Removed Firestore data change notification observer on disappear")
    }
    
    // Keep this method for any future internal use that needs MainActor context
    private func cleanupListeners() {
        // Remove notification observer
        NotificationCenter.default.removeObserver(self)
        
        // Remove Firestore listener
        if let listener = walksListener {
            listener.remove()
            walksListener = nil
            isListenerSetup = false
            print("🔥 Removed Firestore walks listener")
        }
        
        print("📳 Removed Firestore data change notification observer")
    }
    
    // This method is called from the MainActor context
    private func setupWalksListener() {
        guard let dogID = dog.id?.uuidString else {
            print("❌ Cannot set up walks listener: Dog ID is nil")
            return
        }
        
        print("🔥 Setting up Firestore real-time listener for walks")
        
        // Get Firestore instance from the shared configuration manager
        let db = FirebaseConfigurationManager.shared.getFirestore()
        
        // Create a query for walks for this dog, ordered by date (newest first)
        let walksQuery = db.collection("walks")
            .whereField("dogID", isEqualTo: dogID)
            .order(by: "date", descending: true)
            .limit(to: 50)  // Limit to most recent 50 walks for performance
        
        // Set up the listener with optimized settings
        walksListener = walksQuery.addSnapshotListener(includeMetadataChanges: true) { [weak self] snapshot, error in
            guard let self = self else { return }
            
            if let error = error {
                print("❌ Error listening for walks: \(error.localizedDescription)")
                return
            }
            
            guard let snapshot = snapshot else {
                print("❌ Missing snapshot in walks listener")
                return
            }
            
            // Check if this is from cache or server
            let source = snapshot.metadata.isFromCache ? "cache" : "server"
            print("🔥 Received data from: \(source)")
            
            // For shared dogs, we want to process all updates, even if they're from cache
            let isShared = self.dog.isShared ?? false
            
            // Only process if there are actual document changes or if this is a server update for a shared dog
            if !snapshot.documentChanges.isEmpty || (isShared && !snapshot.metadata.isFromCache) {
                print("🔥 Received real-time update with \(snapshot.documents.count) walks and \(snapshot.documentChanges.count) changes")
                
                // Process the walks on the main actor with high priority
                Task(priority: .high) { @MainActor in
                    await self.processWalksSnapshot(snapshot)
                }
            } else {
                print("ℹ️ Skipping update - no changes or cache read for non-shared dog")
            }
        }
    }
    
    private func processWalksSnapshot(_ snapshot: QuerySnapshot) async {
        // This method is already running on the MainActor
        
        // Skip processing if we're already handling a notification
        guard !isHandlingNotification else {
            print("🔥 Already handling an update, skipping this one")
            return
        }
        
        isHandlingNotification = true
        defer { isHandlingNotification = false }
        
        // Check if this is from cache or server
        let source = snapshot.metadata.isFromCache ? "cache" : "server"
        print("🔥 Processing snapshot from: \(source)")
        
        // For shared dogs, prioritize server updates
        let isShared = dog.isShared ?? false
        
        // Check if there are any actual changes that require UI updates
        let hasAddedOrModifiedDocs = snapshot.documentChanges.contains { change in
            return change.type == .added || change.type == .modified
        }
        
        if !hasAddedOrModifiedDocs && !snapshot.documentChanges.isEmpty && !isShared {
            print("ℹ️ No relevant changes in snapshot (only removals or metadata changes)")
            return
        }
        
        // Process walks with high priority for shared dogs
        var walks: [Walk] = []
        var highPriorityWalks: [Walk] = []
        
        // Keep track of document IDs we've processed to avoid duplicates
        var processedDocIds = Set<String>()
        
        for document in snapshot.documents {
            // Skip if we've already processed this document
            if processedDocIds.contains(document.documentID) {
                continue
            }
            
            processedDocIds.insert(document.documentID)
            
            do {
                let walk = try await Walk.fromFirestoreDocument(document)
                walk.dog = dog
                
                // Check if this is a high priority walk
                if let priority = document.data()["priority"] as? String, priority == "high" {
                    highPriorityWalks.append(walk)
                } else {
                    walks.append(walk)
                }
            } catch {
                print("❌ Failed to convert document to Walk: \(error)")
            }
        }
        
        // Combine walks, with high priority walks first
        walks = highPriorityWalks + walks
        
        if walks.isEmpty {
            print("ℹ️ No walks found in snapshot")
            return
        }
        
        print("🔥 Processed \(walks.count) walks from Firestore snapshot")
        
        // For shared dogs or server updates, update immediately
        if isShared || !snapshot.metadata.isFromCache {
            print("🔥 Immediate update for shared dog or server data")
            updateWalksInUI(walks)
        } else {
            // For non-shared dogs with cache data, update with a slight delay
            // to allow for potential server updates to arrive
            print("🔥 Delayed update for non-shared dog with cache data")
            try? await Task.sleep(nanoseconds: 100_000_000) // 100ms delay
            updateWalksInUI(walks)
        }
    }
    
    private func updateWalksInUI(_ newWalks: [Walk]) {
        print("🔄 Updating walks in UI with \(newWalks.count) walks from Firestore")
        
        // Create a set of IDs for efficient deduplication
        var processedIds = Set<String>()
        var updatedWalks = [Walk]()
        
        // First, add all new walks from Firestore (these are the source of truth)
        for walk in newWalks {
            if let id = walk.id?.uuidString, !processedIds.contains(id) {
                updatedWalks.append(walk)
                processedIds.insert(id)
            }
        }
        
        // Then, add any existing walks that aren't in the new walks (only if they have valid IDs)
        // This ensures we don't lose any local walks that haven't synced to Firestore yet
        for walk in dog.walks ?? [] {
            if let id = walk.id?.uuidString, !processedIds.contains(id) {
                updatedWalks.append(walk)
                processedIds.insert(id)
            }
        }
        
        // Sort by date (newest first)
        updatedWalks.sort { ($0.date ?? Date.distantPast) > ($1.date ?? Date.distantPast) }
        
        // Only update if there's a difference in the walks
        let currentWalksCount = dog.walks?.count ?? 0
        if updatedWalks.count != currentWalksCount || !areWalksIdentical(updatedWalks, dog.walks ?? []) {
            print("✅ Updating UI with \(updatedWalks.count) walks (was \(currentWalksCount))")
            
            // Notify observers that the object will change
            objectWillChange.send()
            
            // Update the dog's walks with the deduplicated list
            dog.walks = updatedWalks
            
            // Save the context but don't trigger Firestore saves
            do {
                try modelContext.save()
            } catch {
                print("❌ Error saving model context: \(error.localizedDescription)")
            }
            
            print("✅ Walks updated successfully: \(dog.walks?.count ?? 0) total walks")
        } else {
            print("ℹ️ No changes to walks - skipping UI update")
        }
    }
    
    // Helper method to check if two walk arrays have the same walks (by ID)
    private func areWalksIdentical(_ walks1: [Walk], _ walks2: [Walk]) -> Bool {
        guard walks1.count == walks2.count else { return false }
        
        // Create sets of walk IDs for comparison
        let ids1 = Set(walks1.compactMap { $0.id?.uuidString })
        let ids2 = Set(walks2.compactMap { $0.id?.uuidString })
        
        return ids1 == ids2
    }
    
    private func setupFirestoreNotifications() {
        // Subscribe to Firestore data change notifications as a fallback
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleFirestoreDataChanged(_:)),
            name: .firestoreDataChanged,
            object: nil
        )
        print("📳 Registered for Firestore data change notifications (fallback)")
    }
    
    @objc private func handleFirestoreDataChanged(_ notification: Notification) {
        print("📳 Received Firestore data change notification (fallback)")
        
        // Prevent notification loops
        guard !isHandlingNotification else {
            print("📳 Already handling a notification, ignoring to prevent loops")
            return
        }
        
        // Check if this notification is relevant to our dog
        if let userInfo = notification.userInfo,
           let dogID = userInfo["dogID"] as? String,
           let currentDogID = dog.id?.uuidString,
           dogID == currentDogID {
            
            // Check if this is a shared dog that needs syncing
            let isSharedDog = dog.isShared ?? false
            
            print("📳 Notification is relevant to this dog (shared: \(isSharedDog)), refreshing walks")
            
            // Only refresh if this is a shared dog or if the notification contains a walkID
            // This helps prevent unnecessary refreshes
            if isSharedDog || userInfo["walkID"] != nil {
                Task {
                    // Set flag to prevent loops
                    isHandlingNotification = true
                    
                    await refreshWalks()
                    
                    // Reset flag after refresh completes
                    isHandlingNotification = false
                }
            } else {
                print("📳 Skipping refresh for non-shared dog without walkID")
            }
        } else {
            print("📳 Notification is not relevant to this dog, ignoring")
        }
    }
    
    private func loadQRCode() {
        if let savedQRData = dog.qrCodeData,
           let savedQRImage = UIImage(data: savedQRData) {
            qrCodeImage = savedQRImage
            // Don't automatically show QR code
            // isShowingQRCode = true
        } else if let shareURLString = dog.shareURL,
                  let shareURL = URL(string: shareURLString) {
            generateQRCodeFromURL(shareURL)
            // Don't automatically show QR code
            // isShowingQRCode = true
        }
    }
    
    func shareButtonTapped() async {
        isSharing = true
        defer { isSharing = false }
        
        do {
            // Get the current user's email from Apple Sign In
            guard let currentUser = AuthManager.shared.currentUser() else {
                throw NSError(domain: "DogDetailViewModel", code: 1, userInfo: [NSLocalizedDescriptionKey: "User not signed in"])
            }
            
            // Use the email from Apple Sign In
            let userEmail = currentUser.email
            
            // Use a default recipient email if needed (you can replace this with a UI prompt)
            let recipientEmail = "recipient@example.com"
            
            // Share the dog using Firebase
            let shareURL = try await FirebaseSharingManager.shared.shareDog(dog, withEmail: recipientEmail)
            generateQRCodeFromURL(shareURL)
            isShowingQRCode = true
        } catch {
            shareError = error
            showingError = true
        }
    }
    
    private func generateQRCodeFromURL(_ url: URL) {
        if let qrCode = ShareQRGenerator.shared.generateQRCode(from: url) {
            if let qrData = qrCode.pngData() {
                dog.qrCodeData = qrData
            }
            qrCodeImage = qrCode
        }
    }
    
    func generateQRCode() {
        loadQRCode()
    }
    
    func showQRCode() {
        isShowingQRCode = true
    }
    
    func hideQRCode() {
        isShowingQRCode = false
    }
    
    // MARK: - Walk Management
    
    func logWalk(_ type: WalkType) async {
        do {
            print("🚶‍♂️ Logging walk for dog: \(dog.name ?? "Unknown")")
            
            // Create walk without auto-saving to Firestore
            let walk = Walk(walkType: type, dog: dog, shouldSaveToFirestore: false)
            modelContext.insert(walk)
            
            // Set flag to prevent notification loops
            isHandlingNotification = true
            defer { isHandlingNotification = false }
            
            // For shared dogs, we need to optimize for real-time updates
            let isShared = dog.isShared ?? false
            
            // Save to Firestore with high priority for faster processing
            try await Task.detached(priority: .high) {
                return try await FirestoreManager.shared.saveWalk(walk)
            }.value
            
            // NEW: Update shared data for widget immediately after successful Firestore save
            if let dogID = dog.id?.uuidString,
               let walkID = walk.id?.uuidString,
               let walkDate = walk.date {
                
                let walkData = WalkData(
                    id: walkID,
                    dogID: dogID,
                    date: walkDate,
                    walkType: type,
                    ownerName: AuthManager.shared.currentUser()?.displayName
                )
                
                SharedDataManager.shared.saveLatestWalk(dogID: dogID, walkData: walkData)
                print("📱 Updated widget data for walk: \(type.displayName)")
            }
            
            // Notify observers that the object will change
            objectWillChange.send()
            
            // Update the local model
            try modelContext.save()
            
            print("✅ Walk logged successfully: \(type.displayName)")
            
            // For shared dogs, we can add the walk directly to the UI
            // This provides immediate feedback while waiting for Firestore
            if isShared {
                // Update the UI immediately with the new walk
                await MainActor.run {
                    // Create a temporary array with the new walk at the beginning
                    var updatedWalks = dog.walks ?? []
                    
                    // Check if the walk is already in the list (by ID)
                    let walkId = walk.id?.uuidString
                    let alreadyExists = updatedWalks.contains { $0.id?.uuidString == walkId }
                    
                    // Only add if it doesn't already exist
                    if !alreadyExists && walkId != nil {
                        updatedWalks.insert(walk, at: 0)
                        
                        // Sort to ensure newest first
                        updatedWalks.sort { ($0.date ?? Date.distantPast) > ($1.date ?? Date.distantPast) }
                        
                        // Update the dog's walks
                        dog.walks = updatedWalks
                        
                        print("✅ Added walk to UI immediately for shared dog")
                    } else {
                        print("ℹ️ Walk already exists in UI, skipping immediate update")
                    }
                }
            }
        } catch {
            // Reset flag in case of error
            isHandlingNotification = false
            
            showError = true
            errorMessage = "Failed to log walk: \(error.localizedDescription)"
        }
    }
    
    func refreshWalks() async {
        guard !isLoadingWalks else { return }
        
        isLoadingWalks = true
        defer { isLoadingWalks = false }
        
        do {
            print("🔄 Manual refresh of walks for dog: \(dog.name ?? "Unknown")")
            
            // Set flag to prevent notification loops during refresh
            isHandlingNotification = true
            defer { isHandlingNotification = false }
            
            // Fetch walks from Firestore to ensure consistency
            let walks = try await FirestoreManager.shared.fetchWalks(for: dog)
            print("🔄 Fetched \(walks.count) walks from Firestore")
            
            // Update on the main thread to ensure UI updates
            await MainActor.run {
                // Use the same update logic as the real-time listener
                updateWalksInUI(walks)
            }
        } catch {
            showError = true
            errorMessage = "Failed to refresh walks: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Error Handling
    
    private func showError(_ message: String) {
        errorMessage = message
        showError = true
    }
}
