// here is gonna be the dog detail view. dog image and name, button to generate qr code / button that reveal saved qr code 

import SwiftUI
import SwiftData
import FirebaseFirestore

// Main view - simplified to reduce complexity
struct DogDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var viewModel: DogDetailViewModel
    private let iconSize: CGFloat = 30
    
    init(dog: Dog, modelContext: ModelContext) {
        let viewModel = DogDetailViewModel(dog: dog, modelContext: modelContext)
        self._viewModel = StateObject(wrappedValue: viewModel)
    }
    
    var body: some View {
        // Move all complex view building to a separate struct
        DogDetailContentView(viewModel: viewModel, iconSize: iconSize)
    }
}

// Content view - handles the layout and passes data to subviews
private struct DogDetailContentView: View {
    @ObservedObject var viewModel: DogDetailViewModel
    let iconSize: CGFloat
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Dog Header Section
                headerSection
                
                // Walk Logging Section
                loggingSection
                
                // Walk History Section
                historySection
                
                // Add debug section at the bottom of the list
            }
            .padding(.vertical)
        }
        .navigationTitle(viewModel.dog.name ?? "Dog Details")
        .sheet(isPresented: $viewModel.isShowingQRCode) {
            if let qrCodeImage = viewModel.qrCodeImage {
                VStack {
                    Text("QR Code for \(viewModel.dog.name ?? "Dog")")
                        .font(.headline)
                        .padding()
                    
                    Image(uiImage: qrCodeImage)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 250, height: 250)
                    
                    Text("Scan this code to share your dog's profile")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding()
                    
                    Button("Dismiss") {
                        viewModel.isShowingQRCode = false
                    }
                    .padding()
                }
            } else {
                Text("Unable to generate QR code")
                    .padding()
            }
        }
        .onAppear {
            // Set up Firestore listener when view appears
            viewModel.onAppear()
        }
        .onDisappear {
            // Clean up Firestore listener when view disappears
            viewModel.onDisappear()
        }
    }
    
    // MARK: - Computed Properties
    
    private var headerSection: some View {
        DogDetailHeaderView(
            dog: viewModel.dog,
            showingQRCode: $viewModel.isShowingQRCode,
            qrCodeImage: viewModel.qrCodeImage,
            iconSize: iconSize,
            onShare: viewModel.shareButtonTapped
        )
        .padding(.horizontal)
    }
    
    private var loggingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Log Walk")
                .font(.headline)
            
            walkButtonsRow
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
        .padding(.horizontal)
    }
    
    private var walkButtonsRow: some View {
        HStack(spacing: 16) {
            walkButton
            walkAndPoopButton
        }
    }
    
    private var walkButton: some View {
        Button {
            Task {
                await viewModel.logWalk(.walk)
            }
        } label: {
            Label("Walk", systemImage: WalkType.walk.iconName)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
    }
    
    private var walkAndPoopButton: some View {
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
    
    private var historySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Walk History")
                    .font(.headline)
                
                Spacer()
                
                // Add manual refresh button
                Button {
                    Task {
                        await viewModel.refreshWalks()
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.subheadline)
                }
                .disabled(viewModel.isLoadingWalks)
            }
            
            walkHistoryContent
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
        .padding(.horizontal)
    }
    
    @ViewBuilder
    private var walkHistoryContent: some View {
        if viewModel.isLoadingWalks {
            loadingView
        } else if let walks = viewModel.dog.walks, !walks.isEmpty {
            walksList(walks: walks)
        } else {
            emptyWalksView
        }
    }
    
    private var loadingView: some View {
        ProgressView()
            .frame(maxWidth: .infinity, alignment: .center)
            .padding()
    }
    
    private var emptyWalksView: some View {
        Text("No walks recorded yet")
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding()
    }
    
    private func walksList(walks: [Walk]) -> some View {
        // Sort walks by date (newest first) to ensure correct order
        let sortedWalks = walks.sorted { ($0.date ?? Date.distantPast) > ($1.date ?? Date.distantPast) }
        
        // Create a unique identifier for each walk that includes both ID and date
        // This ensures ForEach has unique identifiers even if there are duplicate IDs
        return ForEach(Array(zip(sortedWalks.indices, sortedWalks)), id: \.0) { index, walk in
            walkRow(walk: walk)
            Divider()
        }
    }
    
    private func walkRow(walk: Walk) -> some View {
        HStack {
            Image(systemName: walk.walkType?.iconName ?? "figure.walk")
                .foregroundColor(.accentColor)
            
            walkInfo(walk: walk)
            
            Spacer()
            
            if walk.walkType == .walkAndPoop {
                Image(systemName: "leaf.fill")
                    .foregroundColor(.brown)
            }
        }
        .padding(.vertical, 8)
    }
    
    private func walkInfo(walk: Walk) -> some View {
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
    }
    
}

// Header view - extracted to its own struct for clarity
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
                
                // Show QR code button for all dogs (both owned and shared)
                Button {
                    showingQRCode = true
                } label: {
                    Image(systemName: "qrcode")
                        .resizable()
                        .scaledToFit()
                        .frame(width: iconSize, height: iconSize)
                        .foregroundColor(.accentColor)
                }
                
                // Only show share button for owned dogs
                if !(dog.isShared ?? false) {
                    Button {
                        Task {
                            await onShare()
                        }
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                            .resizable()
                            .scaledToFit()
                            .frame(width: iconSize, height: iconSize)
                            .foregroundColor(.accentColor)
                    }
                }
            }
            
            // Dog breed section removed as the Dog model doesn't have a breed property
        }
    }
}
