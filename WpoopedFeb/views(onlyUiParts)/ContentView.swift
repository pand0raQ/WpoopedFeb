import SwiftUI
import SwiftData
import FirebaseFirestore

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var authManager = AuthManager.shared
    @State private var isLoading = true
    @State private var loadingError: String?
    @State private var showingPermissionAlert = false
    
    var body: some View {
        Group {
            if isLoading {
                VStack {
                    ProgressView()
                        .scaleEffect(1.5)
                        .padding()
                    Text("Loading your data...")
                        .font(.headline)
                    
                    // Add debug button
                    Button("Debug Firebase Auth") {
                        Task {
                            FirestoreManager.shared.printFirebaseAuthStatus()
                            
                            // Try to force auth update
                            AuthDebugger.shared.forceUpdateAuthState()
                            
                            // Wait a moment and check again
                            try? await Task.sleep(nanoseconds: 1_000_000_000)
                            FirestoreManager.shared.printFirebaseAuthStatus()
                        }
                    }
                    .padding(.top, 20)
                    .font(.caption)
                    .foregroundColor(.gray)
                }
            } else if let error = loadingError {
                VStack(spacing: 20) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 50))
                        .foregroundColor(.orange)
                    
                    Text("Error Loading Data")
                        .font(.title)
                    
                    Text(error)
                        .multilineTextAlignment(.center)
                        .padding()
                    
                    Button("Try Again") {
                        loadInitialData()
                    }
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                    
                    // Add a button to continue anyway
                    Button("Continue Anyway") {
                        isLoading = false
                        loadingError = nil
                    }
                    .padding()
                    .background(Color.gray.opacity(0.3))
                    .foregroundColor(.blue)
                    .cornerRadius(8)
                    
                    // Add debug button
                    Button("Debug Firebase Auth") {
                        Task {
                            FirestoreManager.shared.printFirebaseAuthStatus()
                            
                            // Try to force auth update
                            AuthDebugger.shared.forceUpdateAuthState()
                            
                            // Wait a moment and check again
                            try? await Task.sleep(nanoseconds: 1_000_000_000)
                            FirestoreManager.shared.printFirebaseAuthStatus()
                        }
                    }
                    .padding(.top, 10)
                    .font(.caption)
                    .foregroundColor(.gray)
                }
                .padding()
            } else {
                TabView {
                    NavigationStack {
                        Text("Home")
                            .navigationTitle("Home")
                    }
                    .tabItem {
                        Label("Home", systemImage: "house.fill")
                    }
                    
                    NavigationStack {
                        DogsListView(modelContext: modelContext)
                    }
                    .tabItem {
                        Label("Dogs", systemImage: "pawprint.fill")
                    }
                    
                    NavigationStack {
                        ProfileView(viewModel: ProfileViewModel(modelContext: modelContext))
                    }
                    .tabItem {
                        Label("Profile", systemImage: "person.fill")
                    }
                }
            }
        }
        .onAppear {
            print("ContentView appeared, auth state: \(AuthManager.shared.isAuthenticated)")
            loadInitialData()
        }
        .withFirebasePermissionErrorHandling()
    }
    
    private func loadInitialData() {
        isLoading = true
        loadingError = nil
        
        Task {
            do {
                // Add a small delay to ensure Firebase is fully initialized
                try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                
                // Check if we need to clear existing sample dogs
                await MainActor.run {
                    clearExistingSampleDogs()
                }
                
                // Fetch dogs from Firestore with fallback to sample data
                let dogs = await FirestoreManager.shared.fetchDogsWithFallback()
                print("✅ Successfully fetched \(dogs.count) dogs (may include sample data)")
                
                // Add dogs to the model context if they're not already there
                await MainActor.run {
                    for dog in dogs {
                        // Check if the dog is already in the context
                        if let dogId = dog.id {
                            let descriptor = FetchDescriptor<Dog>(predicate: #Predicate { existingDog in
                                existingDog.id == dogId
                            })
                            
                            do {
                                let existingDogs = try modelContext.fetch(descriptor)
                                if existingDogs.isEmpty {
                                    modelContext.insert(dog)
                                    print("✅ Added dog to model context: \(dog.name ?? "Unknown")")
                                } else {
                                    print("ℹ️ Dog already exists in context: \(dog.name ?? "Unknown")")
                                }
                            } catch {
                                print("❌ Error checking for existing dog: \(error.localizedDescription)")
                                // Insert anyway
                                modelContext.insert(dog)
                            }
                        } else if let recordID = dog.recordID {
                            let descriptor = FetchDescriptor<Dog>(predicate: #Predicate { existingDog in
                                existingDog.recordID == recordID
                            })
                            
                            do {
                                let existingDogs = try modelContext.fetch(descriptor)
                                if existingDogs.isEmpty {
                                    modelContext.insert(dog)
                                    print("✅ Added dog to model context: \(dog.name ?? "Unknown")")
                                }
                            } catch {
                                print("❌ Error checking for existing dog: \(error.localizedDescription)")
                                // Insert anyway
                                modelContext.insert(dog)
                            }
                        } else {
                            // No ID to check against, just insert
                            modelContext.insert(dog)
                            print("✅ Added dog to model context without ID check: \(dog.name ?? "Unknown")")
                        }
                    }
                    
                    isLoading = false
                }
            } catch let error as NSError {
                print("❌ Error loading initial data: \(error.localizedDescription)")
                
                // Use our error handler to get a user-friendly message
                let errorType = FirestoreErrorHandler.getErrorType(from: error)
                
                // Update UI on main thread
                await MainActor.run {
                    if errorType == .permissionDenied {
                        loadingError = "Firebase permission error. Your security rules need to be updated."
                        showingPermissionAlert = true
                    } else {
                        loadingError = errorType.userFriendlyMessage
                    }
                    isLoading = false
                }
            } catch {
                print("❌ Error loading initial data: \(error.localizedDescription)")
                
                // Update UI on main thread
                await MainActor.run {
                    loadingError = "Could not load your data. Please check your internet connection and try again."
                    isLoading = false
                }
            }
        }
    }
    
    // Helper method to clear existing sample dogs
    private func clearExistingSampleDogs() {
        // Find all dogs with sample UUIDs
        let sampleIDs = [
            UUID(uuidString: "00000000-0000-0000-0000-000000000001"),
            UUID(uuidString: "00000000-0000-0000-0000-000000000002")
        ]
        
        for sampleID in sampleIDs.compactMap({ $0 }) {
            let descriptor = FetchDescriptor<Dog>(predicate: #Predicate { dog in
                dog.id == sampleID
            })
            
            do {
                let sampleDogs = try modelContext.fetch(descriptor)
                for dog in sampleDogs {
                    modelContext.delete(dog)
                    print("🗑️ Deleted existing sample dog: \(dog.name ?? "Unknown")")
                }
            } catch {
                print("❌ Error finding sample dogs: \(error.localizedDescription)")
            }
        }
        
        // Also look for dogs with "Sample Dog" in the name
        let nameDescriptor = FetchDescriptor<Dog>(predicate: #Predicate { dog in
            dog.name?.contains("Sample Dog") == true
        })
        
        do {
            let sampleDogs = try modelContext.fetch(nameDescriptor)
            for dog in sampleDogs {
                // Skip if it's one of our fixed sample dogs
                if sampleIDs.contains(dog.id ?? UUID()) {
                    continue
                }
                modelContext.delete(dog)
                print("🗑️ Deleted existing sample dog by name: \(dog.name ?? "Unknown")")
            }
        } catch {
            print("❌ Error finding sample dogs by name: \(error.localizedDescription)")
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Dog.self)
} 