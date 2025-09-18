// here is the list of dogs image and name

import SwiftUI
import SwiftData
import FirebaseFirestore

struct DogsListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var dogs: [Dog]
    @State private var showingDogRegistration = false
    @State private var showingQRScanner = false
    @StateObject private var qrScannerViewModel: QRCodeScannerViewModel
    
    init(modelContext: ModelContext) {
        _qrScannerViewModel = StateObject(wrappedValue: QRCodeScannerViewModel(modelContext: modelContext))
    }
    
    var body: some View {
        List {
            Section {
                ForEach(dogs) { dog in
                    NavigationLink {
                        DogDetailView(dog: dog, modelContext: modelContext)
                    } label: {
                        DogRowView(dog: dog)
                    }
                }
            }
            
            // Debug section
            Section("Debug") {
                Button("Print Dogs Count") {
                    print("🐕 Current dogs count: \(dogs.count)")
                    for dog in dogs {
                        print("Dog: \(dog.name ?? "Unknown"), isShared: \(dog.isShared ?? false), shareRecordID: \(dog.shareRecordID ?? "none")")
                    }
                }
                
                Button("Print Firestore Dogs") {
                    Task {
                        do {
                            let dogs = try await FirestoreManager.shared.fetchDogs()
                            print("📊 Fetched \(dogs.count) dogs from Firestore")
                            for dog in dogs {
                                print("Dog: \(dog.name ?? "Unknown"), isShared: \(dog.isShared ?? false), shareID: \(dog.shareRecordID ?? "none")")
                            }
                        } catch {
                            print("❌ Error fetching dogs: \(error.localizedDescription)")
                        }
                    }
                }
                
                Button("Create Real Dog in Firestore") {
                    Task {
                        do {
                            // Ensure Firebase is authenticated
                            FirestoreManager.shared.printFirebaseAuthStatus()
                            
                            // Create a new dog with the current user ID
                            let newDog = Dog(name: "Real Firestore Dog", shouldSaveToFirestore: true)
                            
                            // Add to local context
                            modelContext.insert(newDog)
                            
                            print("✅ Created new dog in Firestore and local context")
                        } catch {
                            print("❌ Error creating dog: \(error.localizedDescription)")
                        }
                    }
                }
                
                Button("Clear Sample Dogs") {
                    Task {
                        // Find all dogs with "Sample" in the name
                        let descriptor = FetchDescriptor<Dog>(predicate: #Predicate { dog in
                            dog.name?.contains("Sample") == true
                        })
                        
                        do {
                            let sampleDogs = try modelContext.fetch(descriptor)
                            print("🔍 Found \(sampleDogs.count) sample dogs to delete")
                            
                            for dog in sampleDogs {
                                modelContext.delete(dog)
                            }
                            
                            print("🗑️ Deleted all sample dogs")
                        } catch {
                            print("❌ Error clearing sample dogs: \(error.localizedDescription)")
                        }
                    }
                }
                
                Button("Sync Dogs to Widget") {
                    Task {
                        SharedDataManager.shared.syncFromMainApp(dogs: dogs)
                        print("🔄 Manually synced \(dogs.count) dogs to widget")
                    }
                }
                
                Button("Debug Widget Data") {
                    SharedDataManager.shared.printDebugInfo()
                }
                
                Button("Check Pending Widget Walks") {
                    let pendingWalks = SharedDataManager.shared.getPendingWidgetWalks()
                    print("📱 === PENDING WIDGET WALKS CHECK ===")
                    print("📱 Found \(pendingWalks.count) pending widget walks")
                    for (index, walk) in pendingWalks.enumerated() {
                        print("📱 Walk \(index + 1):")
                        print("  - ID: \(walk.id)")
                        print("  - Dog ID: \(walk.dogID)")  
                        print("  - Type: \(walk.walkType.displayName)")
                        print("  - Date: \(walk.date)")
                        print("  - Owner: \(walk.ownerName ?? "Unknown")")
                    }
                    print("📱 === END PENDING WALKS CHECK ===")
                }
                
                Button("Check Widget Debug Logs") {
                    if let sharedDefaults = UserDefaults(suiteName: "group.bumblebee.WpoopedFeb") {
                        let debugLogs = sharedDefaults.stringArray(forKey: "widget_debug_logs") ?? []
                        print("📱 === WIDGET DEBUG LOGS ===")
                        print("📱 Found \(debugLogs.count) debug log entries")
                        for log in debugLogs {
                            print("📱 \(log)")
                        }
                        print("📱 === END WIDGET DEBUG LOGS ===")
                    } else {
                        print("📱 Could not access shared UserDefaults")
                    }
                }
                
                Button("Force Sync Pending Walks") {
                    Task {
                        print("📱 Manually triggering pending walks sync...")
                        // Call the same sync function that the app uses
                        await forceSyncPendingWalks()
                    }
                }
                
                Button("Debug Firebase Auth") {
                    Task {
                        FirestoreManager.shared.printFirebaseAuthStatus()
                        
                        // Try to force auth update
                        AuthDebugger.shared.forceUpdateAuthState()
                        
                        // Wait a moment and check again
                        try? await Task.sleep(nanoseconds: 1_000_000_000)
                        FirestoreManager.shared.printFirebaseAuthStatus()
                        
                        // Try to fetch dogs again
                        do {
                            let isAuthenticated = await FirestoreManager.shared.ensureFirebaseAuth()
                            print("✅ Firebase authenticated: \(isAuthenticated)")
                            
                            let dogs = try await FirestoreManager.shared.fetchDogs()
                            print("📊 Fetched \(dogs.count) dogs from Firestore after auth check")
                        } catch {
                            print("❌ Error fetching dogs after auth check: \(error.localizedDescription)")
                        }
                    }
                }
                
                Button("Refresh Context") {
                    // Force a refresh of the model context
                    try? modelContext.save()
                    print("🔄 Context refreshed")
                }
                
                Button("Check Shared Dogs") {
                    Task {
                        do {
                            // Get all shares from Firestore
                            let db = Firestore.firestore()
                            let snapshot = try await db.collection("shares").whereField("sharedWithEmail", isEqualTo: AuthManager.shared.currentUser()?.email ?? "").getDocuments()
                            
                            print("🔄 Found \(snapshot.documents.count) shares")
                            
                            for document in snapshot.documents {
                                guard let dogID = document.data()["dogID"] as? String else { continue }
                                
                                print("🔄 Fetching shared dog with ID: \(dogID)")
                                let dogDoc = try await db.collection("dogs").document(dogID).getDocument()
                                
                                if dogDoc.exists {
                                    let dog = try await Dog.fromFirestoreDocument(dogDoc)
                                    print("✅ Found shared dog: \(dog.name ?? "Unknown")")
                                    
                                    // Check if already in context
                                    let descriptor = FetchDescriptor<Dog>(predicate: #Predicate { $0.id?.uuidString == dogID })
                                    if let _ = try? modelContext.fetch(descriptor).first {
                                        print("ℹ️ Dog already exists in context")
                                    } else {
                                        // Add to context
                                        dog.isShared = true
                                        dog.shareRecordID = document.documentID
                                        modelContext.insert(dog)
                                        print("✅ Added shared dog to context")
                                    }
                                }
                            }
                        } catch {
                            print("❌ Error checking shared dogs: \(error.localizedDescription)")
                        }
                    }
                }
            }
        }
        .navigationTitle("My Dogs")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack {
                    Button(action: {
                        showingQRScanner = true
                    }) {
                        Image(systemName: "qrcode.viewfinder")
                    }
                    
                    Button(action: {
                        showingDogRegistration = true
                    }) {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        .sheet(isPresented: $showingDogRegistration) {
            DogRegistrationView()
        }
        .sheet(isPresented: $showingQRScanner) {
            QRScannerView(viewModel: qrScannerViewModel)
        }
        .alert("Accept Share?", isPresented: .init(
            get: { qrScannerViewModel.showingShareAcceptance },
            set: { qrScannerViewModel.showingShareAcceptance = $0 }
        )) {
            Button("Accept") {
                Task {
                    await qrScannerViewModel.acceptShare()
                    showingQRScanner = false
                }
            }
            Button("Cancel", role: .cancel) {
                qrScannerViewModel.resetScanner()
                showingQRScanner = false
            }
        } message: {
            if let metadata = qrScannerViewModel.shareMetadata {
                Text("Would you like to accept shared dog '\(metadata.dogName)' from \(metadata.ownerName)?")
            }
        }
        .alert("Share Error", isPresented: .init(
            get: { qrScannerViewModel.shareError != nil },
            set: { _ in qrScannerViewModel.shareError = nil }
        )) {
            Button("OK", role: .cancel) {
                qrScannerViewModel.resetScanner()
                showingQRScanner = false
            }
        } message: {
            if let error = qrScannerViewModel.shareError {
                Text(error)
            }
        }
        .onChange(of: dogs.count) { _, newCount in
            // Sync dogs to widget whenever the count changes
            Task {
                SharedDataManager.shared.syncFromMainApp(dogs: dogs)
                print("🔄 Auto-synced \(newCount) dogs to widget after change")
            }
        }
    }
    
    // MARK: - Helper Functions
    private func forceSyncPendingWalks() async {
        print("🔄 === FORCE SYNCING PENDING WIDGET WALKS ===")
        
        let pendingWalks = SharedDataManager.shared.getPendingWidgetWalks()
        print("🔄 Found \(pendingWalks.count) pending widget walks")
        
        guard !pendingWalks.isEmpty else {
            print("✅ No pending widget walks to sync")
            return
        }
        
        print("🔄 Syncing \(pendingWalks.count) pending widget walks to Firebase...")
        
        for (index, walkData) in pendingWalks.enumerated() {
            print("🔄 Processing walk \(index + 1)/\(pendingWalks.count):")
            print("  - Walk ID: \(walkData.id)")
            print("  - Dog ID: \(walkData.dogID)")
            print("  - Walk Type: \(walkData.walkType.displayName)")
            print("  - Date: \(walkData.date)")
            print("  - Owner: \(walkData.ownerName ?? "Unknown")")
            
            do {
                // Convert WalkData to Firebase format and save
                let walkDoc: [String: Any] = [
                    "id": walkData.id,
                    "dogID": walkData.dogID,
                    "date": Timestamp(date: walkData.date),
                    "walkType": walkData.walkType.rawValue,
                    "ownerName": walkData.ownerName ?? "Widget User",
                    "createdFromWidget": true
                ]
                
                print("🔄 Saving to Firebase collection 'walks' with document ID: \(walkData.id)")
                
                // Save to Firebase
                let db = Firestore.firestore()
                let walkRef = db.collection("walks").document(walkData.id)
                try await walkRef.setData(walkDoc)
                
                print("✅ Successfully synced widget walk to Firebase: \(walkData.walkType.displayName)")
                
                // Remove from pending list after successful sync
                SharedDataManager.shared.removePendingWidgetWalk(withID: walkData.id)
                print("✅ Removed walk from pending list")
                
                // Important: Add the walk to the local SwiftData model so it appears in the app
                print("🔄 Adding walk to local model context...")
                let newWalk = Walk(walkType: walkData.walkType, shouldSaveToFirestore: false)
                newWalk.id = UUID(uuidString: walkData.id)
                newWalk.date = walkData.date
                
                // Find the dog and add the walk
                if let targetDog = dogs.first(where: { $0.id?.uuidString == walkData.dogID }) {
                    newWalk.dog = targetDog
                    modelContext.insert(newWalk)
                    print("✅ Added walk to local model for dog: \(targetDog.name ?? "Unknown")")
                } else {
                    print("⚠️ Could not find dog with ID: \(walkData.dogID)")
                }
                
                // Save the context
                try? modelContext.save()
                print("✅ Saved model context")
                
            } catch {
                print("❌ Failed to sync widget walk \(walkData.id) to Firebase: \(error)")
                print("❌ Error details: \(error.localizedDescription)")
            }
        }
        
        // After processing all walks, sync the updated dogs to the widget
        print("🔄 Syncing updated dogs to widget...")
        SharedDataManager.shared.syncFromMainApp(dogs: dogs)
        print("✅ Updated widget with latest walk data")
        
        print("✅ === FINISHED FORCE SYNCING PENDING WIDGET WALKS ===")
    }
}

struct DogRowView: View {
    let dog: Dog
    
    var body: some View {
        HStack {
            if let image = dog.image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 50, height: 50)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.blue, lineWidth: 1))
            } else {
                Image(systemName: "pawprint.circle.fill")
                    .resizable()
                    .frame(width: 50, height: 50)
                    .foregroundColor(.blue)
            }
            
            VStack(alignment: .leading) {
                Text(dog.name ?? "Unknown")
                    .font(.headline)
                
                if dog.isShared ?? false {
                    HStack {
                        Image(systemName: "person.2.fill")
                        Text("Shared")
                            .font(.caption)
                    }
                    .foregroundColor(.green)
                }
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(.gray)
                .font(.caption)
        }
        .padding(.vertical, 8)
    }
}



