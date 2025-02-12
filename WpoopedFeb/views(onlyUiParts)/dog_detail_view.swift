// here is gonna be the dog detail view. dog image and name, button to generate qr code / button that reveal saved qr code 

import SwiftUI
import CloudKit
import SwiftData

struct DogDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var viewModel: DogDetailViewModel
    private let iconSize: CGFloat = 30
    
    init(dog: Dog, modelContext: ModelContext) {
        let viewModel = DogDetailViewModel(dog: dog, modelContext: modelContext)
        self._viewModel = StateObject(wrappedValue: viewModel)
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                DogDetailHeaderView(
                    dog: viewModel.dog,
                    showingQRCode: $viewModel.isShowingQRCode,
                    qrCodeImage: viewModel.qrCodeImage,
                    iconSize: iconSize,
                    onShare: viewModel.shareButtonTapped
                )
                .padding(.horizontal)
                
                // Walk Logging Section
                WalkLoggingSection()
                
                // Walk History Section
                WalkHistorySection()
                
                // Add debug section at the bottom of the list
                Section("Debug") {
                    Button("Create Test Walk") {
                        Task {
                            print("\n🔍 DEBUG: Creating Test Walk")
                            print("🐕 Dog: \(viewModel.dog.name ?? "Unknown")")
                            print("📝 Dog Details:")
                            print("  - Record ID: \(viewModel.dog.recordID ?? "nil")")
                            print("  - Is Shared: \(viewModel.dog.isShared ?? false)")
                            print("  - Share Record ID: \(viewModel.dog.shareRecordID ?? "nil")")
                            
                            do {
                                // Create and save test walk
                                let walk = Walk(walkType: .walk, dog: viewModel.dog)
                                print("\n📝 Created Walk:")
                                print("  - ID: \(walk.id?.uuidString ?? "nil")")
                                print("  - Record ID: \(walk.recordID ?? "nil")")
                                
                                // Get CKRecord for debugging
                                let record = walk.toCKRecord()
                                print("\n🔍 Walk CKRecord:")
                                print("  - Record ID: \(record.recordID.recordName)")
                                print("  - Zone Name: \(record.recordID.zoneID.zoneName)")
                                print("  - Zone Owner: \(record.recordID.zoneID.ownerName)")
                                if let dogRef = record["dogReference"] as? CKRecord.Reference {
                                    print("  - Dog Reference:")
                                    print("    - Record Name: \(dogRef.recordID.recordName)")
                                    print("    - Zone Name: \(dogRef.recordID.zoneID.zoneName)")
                                    print("    - Zone Owner: \(dogRef.recordID.zoneID.ownerName)")
                                }
                                
                                // Try to save
                                print("\n💾 Saving walk...")
                                try await CloudKitManager.shared.saveWalk(walk)
                                
                                // Refresh to verify
                                print("\n🔄 Refreshing walks...")
                                await viewModel.refreshWalks()
                                
                                print("\n✅ Test walk creation completed")
                            } catch {
                                print("\n❌ Error creating test walk: \(error)")
                                if let ckError = error as? CKError {
                                    print("🔍 CloudKit error details:")
                                    print("  - Error code: \(ckError.code.rawValue)")
                                    print("  - Description: \(ckError.localizedDescription)")
                                }
                            }
                        }
                    }
                    
                    Button("Debug Walk Fetch") {
                        Task {
                            print("\n🔍 DEBUG: Walk Fetch for Dog")
                            print("🐕 Dog: \(viewModel.dog.name ?? "Unknown")")
                            print("📝 Details:")
                            print("  - Record ID: \(viewModel.dog.recordID ?? "nil")")
                            print("  - Is Shared: \(viewModel.dog.isShared ?? false)")
                            print("  - Share Record ID: \(viewModel.dog.shareRecordID ?? "nil")")
                            print("  - Share URL: \(viewModel.dog.shareURL ?? "nil")")
                            
                            do {
                                let walks = try await CloudKitManager.shared.fetchWalks(for: viewModel.dog)
                                print("\n✅ Successfully fetched \(walks.count) walks")
                                for walk in walks {
                                    print("\n🦮 Walk:")
                                    print("  - Record ID: \(walk.recordID ?? "nil")")
                                    print("  - Date: \(walk.date?.description ?? "nil")")
                                    print("  - Type: \(walk.walkType?.displayName ?? "nil")")
                                }
                            } catch {
                                print("\n❌ Error fetching walks: \(error)")
                                if let ckError = error as? CKError {
                                    print("🔍 CloudKit error details:")
                                    print("  - Error code: \(ckError.code.rawValue)")
                                    print("  - Description: \(ckError.localizedDescription)")
                                    if let serverRecord = ckError.serverRecord {
                                        print("  - Server record type: \(serverRecord.recordType)")
                                        print("  - Server record zone: \(serverRecord.recordID.zoneID.zoneName)")
                                    }
                                }
                            }
                        }
                    }
                    
                    Button("Print Zone Info") {
                        Task {
                            await CloudKitManager.shared.debugPrintZoneInfo()
                        }
                    }
                    
                    Button("Force Refresh Walks") {
                        Task {
                            print("\n🔄 Force refreshing walks...")
                            await viewModel.refreshWalks()
                        }
                    }
                    
                    Button("Check Walk References") {
                        Task {
                            print("\n🔍 Checking walk references...")
                            if let walks = viewModel.dog.walks {
                                print("📊 Local walks count: \(walks.count)")
                                for walk in walks {
                                    print("\n🦮 Walk Check:")
                                    print("  - Walk ID: \(walk.recordID ?? "nil")")
                                    print("  - Dog Reference Valid: \(walk.dog?.recordID == viewModel.dog.recordID)")
                                    print("  - Zone Match: \(walk.dog?.isShared == viewModel.dog.isShared)")
                                }
                            } else {
                                print("❌ No walks found in local context")
                            }
                        }
                    }
                }
            }
            .padding(.vertical)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(viewModel.dog.name ?? "Dog Details")
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(viewModel.errorMessage)
        }
        .task {
            await viewModel.refreshWalks()
        }
    }
    
    private func WalkLoggingSection() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Log Walk")
                .font(.headline)
            
            HStack(spacing: 16) {
                Button {
                    Task {
                        await viewModel.logWalk(.walk)
                    }
                } label: {
                    Label("Walk", systemImage: WalkType.walk.iconName)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                
                Button {
                    Task {
                        await viewModel.logWalk(.walkAndPoop)
                    }
                } label: {
                    Label("Walk + Poop", systemImage: WalkType.walkAndPoop.iconName)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.brown)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
    
    private func WalkHistorySection() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Walk History")
                .font(.headline)
            
            if viewModel.isLoadingWalks {
                ProgressView()
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else if let walks = viewModel.dog.walks, !walks.isEmpty {
                ForEach(walks) { walk in
                    HStack {
                        Image(systemName: walk.walkType?.iconName ?? "figure.walk")
                            .foregroundColor(.accentColor)
                        
                        VStack(alignment: .leading) {
                            Text(walk.walkType?.displayName ?? "Walk")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            if let date = walk.date {
                                Text(date.formatted(date: .abbreviated, time: .shortened))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                        
                        if walk.walkType == .walkAndPoop {
                            Image(systemName: "leaf.fill")
                                .foregroundColor(.brown)
                        }
                    }
                    .padding(.vertical, 8)
                    Divider()
                }
            } else {
                Text("No walks recorded yet")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
        .task {
            // Only fetch walks when this section becomes visible
            await viewModel.refreshWalks()
        }
    }
}

private struct DogDetailHeaderView: View {
    let dog: Dog
    @Binding var showingQRCode: Bool
    let qrCodeImage: UIImage?
    let iconSize: CGFloat
    let onShare: () async -> Void
    
    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 16) {
                if let imageData = dog.imageData, let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 100, height: 100)
                        .clipShape(Circle())
                        .shadow(radius: 2)
                } else {
                    Image(systemName: "pawprint.circle.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 100, height: 100)
                        .foregroundColor(.accentColor)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text(dog.name ?? "Unknown Dog")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    if dog.isShared ?? false {
                        Label("Shared", systemImage: "person.2.fill")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                if !(dog.isShared ?? false) {
                    Button(action: {
                        Task {
                            await onShare()
                        }
                    }) {
                        Image(systemName: "qrcode")
                            .font(.system(size: iconSize))
                            .foregroundColor(.accentColor)
                    }
                } else if let qrImage = qrCodeImage {
                    Image(uiImage: qrImage)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(width: iconSize * 2, height: iconSize * 2)
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(radius: 1)
        }
    }
} 
