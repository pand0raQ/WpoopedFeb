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



