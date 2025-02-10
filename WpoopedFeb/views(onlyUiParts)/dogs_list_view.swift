// here is the list of dogs image and name

import SwiftUI
import SwiftData
import CloudKit

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
                    NavigationLink(destination: DogDetailView(dog: dog)) {
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
                
                Button("Refresh Context") {
                    // Force a refresh of the model context
                    try? modelContext.save()
                    print("🔄 Context refreshed")
                }
                
                Button("Check Shared Dog") {
                    Task {
                        do {
                            let container = CKContainer(identifier: CloudKitManager.containerIdentifier)
                            
                            // First get the share record
                            let shareZoneID = CKRecordZone.ID(zoneName: "DogsZone", ownerName: "_95f15e1388a74c44496595cb77c50953")
                            let shareRecordID = CKRecord.ID(recordName: "Share-89E50232-0877-42D1-B878-75D011C88836", zoneID: shareZoneID)
                            
                            print("🔄 Fetching share record...")
                            let share = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<CKRecord, Error>) in
                                container.sharedCloudDatabase.fetch(withRecordID: shareRecordID) { record, error in
                                    if let error = error {
                                        continuation.resume(throwing: error)
                                        return
                                    }
                                    guard let record = record else {
                                        continuation.resume(throwing: CloudKitManagerError.recordNotFound)
                                        return
                                    }
                                    continuation.resume(returning: record)
                                }
                            }
                            print("✅ Found share record: \(share)")
                            
                            // Then get the dog record through the share
                            let dogZoneID = share.recordID.zoneID
                            let dogRecordID = CKRecord.ID(recordName: "F4ACC5EE-2A96-4F23-9B54-F2E5FD40AD98", zoneID: dogZoneID)
                            
                            print("🔄 Fetching dog record...")
                            let record = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<CKRecord, Error>) in
                                container.sharedCloudDatabase.fetch(withRecordID: dogRecordID) { record, error in
                                    if let error = error {
                                        continuation.resume(throwing: error)
                                        return
                                    }
                                    guard let record = record else {
                                        continuation.resume(throwing: CloudKitManagerError.recordNotFound)
                                        return
                                    }
                                    continuation.resume(returning: record)
                                }
                            }
                            print("✅ Found dog record: \(record)")
                            
                            if let dog = try? Dog.fromCKRecord(record) {
                                print("✅ Successfully converted to Dog: \(dog.name ?? "Unknown")")
                                modelContext.insert(dog)
                                try modelContext.save()
                            }
                        } catch {
                            print("❌ Error checking shared dog: \(error)")
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



