//
//  WalkIntentsV2.swift
//  WpoopedFebWidget
//
//  Enhanced AppIntents with iOS 26 Interactive Snippets
//

import WidgetKit
import AppIntents
import SwiftUI

// MARK: - Data Dependencies

@available(iOS 26.0, *)
@MainActor
class WalkDataStore: ObservableObject {
    static let shared = WalkDataStore()

    @Published var recentWalks: [WalkData] = []
    @Published var isLoading = false
    @Published var lastSyncStatus: SyncStatus = .unknown

    private init() {
        loadRecentWalks()
    }

    func logWalk(dogID: String, walkType: WalkType) async -> WalkResult {
        isLoading = true

        let walkData = WalkData(
            id: UUID().uuidString,
            dogID: dogID,
            date: Date(),
            walkType: walkType,
            ownerName: "Widget User"
        )

        // Update local data immediately
        recentWalks.insert(walkData, at: 0)
        SharedDataManager.shared.saveLatestWalk(dogID: dogID, walkData: walkData)

        // Attempt Firebase sync
        let syncResult = await syncToFirebase(walkData: walkData)

        lastSyncStatus = syncResult.success ? .synced : .pending
        isLoading = false

        return WalkResult(
            walkData: walkData,
            syncStatus: lastSyncStatus,
            coParentNotified: syncResult.coParentNotified
        )
    }

    func getDog(by id: String) -> DogData? {
        return SharedDataManager.shared.getAllDogs().first { $0.id == id }
    }

    private func loadRecentWalks() {
        // Load recent walks from SharedDataManager
        let dogs = SharedDataManager.shared.getAllDogs()
        recentWalks = dogs.compactMap { $0.lastWalk }.sorted { $0.date > $1.date }
    }

    private func syncToFirebase(walkData: WalkData) async -> (success: Bool, coParentNotified: Bool) {
        // Simulate Firebase sync with realistic delay
        try? await Task.sleep(nanoseconds: 800_000_000) // 0.8 seconds

        // Check if dog is shared to determine co-parent notification
        let isSharedDog = SharedDataManager.shared.isDogShared(walkData.dogID)

        // In production, implement actual Firebase sync here
        let networkAvailable = await checkNetworkAvailability()

        if networkAvailable {
            // Walk synced successfully - in production this would update Firebase
            return (success: true, coParentNotified: isSharedDog)
        } else {
            SharedDataManager.shared.addPendingWidgetWalk(walkData)
            return (success: false, coParentNotified: false)
        }
    }

    private func checkNetworkAvailability() async -> Bool {
        // Simple network check
        do {
            let url = URL(string: "https://www.google.com")!
            let (_, response) = try await URLSession.shared.data(from: url)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            return false
        }
    }
}

enum SyncStatus {
    case unknown, syncing, synced, pending, failed

    var displayText: String {
        switch self {
        case .unknown: return "Status unknown"
        case .syncing: return "Syncing..."
        case .synced: return "Synced to cloud"
        case .pending: return "Will sync later"
        case .failed: return "Sync failed"
        }
    }

    var color: Color {
        switch self {
        case .unknown: return .gray
        case .syncing: return .blue
        case .synced: return .green
        case .pending: return .orange
        case .failed: return .red
        }
    }
}

struct WalkResult {
    let walkData: WalkData
    let syncStatus: SyncStatus
    let coParentNotified: Bool
}

// MARK: - Primary Walk Logging Intent (Shows Snippet)

@available(iOS 26.0, *)
struct LogWalkWithSnippetIntent: AppIntent {
    static var title: LocalizedStringResource = "Log Dog Walk"
    static var description = IntentDescription("Log a walk for your dog with confirmation")

    @Parameter(title: "Dog ID", description: "The dog to log a walk for")
    var dogID: String

    @Parameter(title: "Walk Type", description: "Type of walk to log")
    var walkType: WalkType

    @Dependency
    var walkStore: WalkDataStore

    init() {
        self.dogID = ""
        self.walkType = .walk
    }

    init(dogID: String, walkType: WalkType) {
        self.dogID = dogID
        self.walkType = walkType
    }

    func perform() async throws -> some IntentResult & ShowsSnippetView {
        print("🎯 LogWalkWithSnippetIntent: Starting walk log for dog \(dogID), type \(walkType.displayName)")

        // Log the walk and get the result
        let result = await WalkDataStore.shared.logWalk(dogID: dogID, walkType: walkType)

        // Return the snippet view directly
        return .result(view: WalkConfirmationSnippetView(
            result: result,
            walkStore: WalkDataStore.shared
        ))
    }
}

// MARK: - Interactive Snippet Intent (iOS 26+ only)

// iOS 26 Snippet functionality commented out for now as it requires proper iOS 26 SDK
// @available(iOS 26.0, *)
// struct WalkConfirmationSnippetIntent: SnippetIntent {
//     static var title: LocalizedStringResource = "Walk Confirmation"
//     static var description = IntentDescription("Show walk confirmation with interactive options")
//
//     let dogID: String
//     let walkType: WalkType
//
//     @Dependency
//     var walkStore: WalkDataStore
//
//     init(dogID: String, walkType: WalkType) {
//         self.dogID = dogID
//         self.walkType = walkType
//     }
//
//     func perform() async throws -> some IntentResult & ShowsSnippetView {
//         print("🎬 WalkConfirmationSnippetIntent: Performing for dog \(dogID)")
//
//         // Log the walk and get the result
//         let result = await walkStore.logWalk(dogID: dogID, walkType: walkType)
//
//         return .result(view: WalkConfirmationSnippetView(
//             result: result,
//             walkStore: walkStore
//         ))
//     }
// }

// MARK: - Interactive Snippet View

@available(iOS 26.0, *)
struct WalkConfirmationSnippetView: View {
    let result: WalkResult
    @ObservedObject var walkStore: WalkDataStore

    @State private var showingSuccess = false

    var dogName: String {
        walkStore.getDog(by: result.walkData.dogID)?.name ?? "Unknown Dog"
    }

    var body: some View {
        VStack(spacing: 16) {
            // Header with dog info
            HStack {
                DogAvatarView(dogID: result.walkData.dogID, size: 40)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Walk Logged!")
                        .font(.headline)
                        .fontWeight(.semibold)

                    Text("\(result.walkData.walkType.displayName) for \(dogName)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Success checkmark with animation
                Image(systemName: "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(.green)
                    .scaleEffect(showingSuccess ? 1.2 : 1.0)
                    .animation(.spring(response: 0.5, dampingFraction: 0.6), value: showingSuccess)
            }

            // Sync status indicator
            SyncStatusView(
                status: result.syncStatus,
                coParentNotified: result.coParentNotified,
                isLoading: walkStore.isLoading
            )

            // Interactive action buttons
            HStack(spacing: 12) {
                // Add another walk button
                Button(intent: LogWalkIntent(dogID: result.walkData.dogID, walkType: .walk)) {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle.fill")
                        Text("Another Walk")
                    }
                    .font(.subheadline)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.blue.opacity(0.1))
                    .foregroundColor(.blue)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)

                // View all walks button
                Button(intent: TestIntent()) {
                    HStack(spacing: 6) {
                        Image(systemName: "list.bullet")
                        Text("Recent Walks")
                    }
                    .font(.subheadline)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.gray.opacity(0.1))
                    .foregroundColor(.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }

            // Timestamp
            Text("Logged at \(result.walkData.date.formatted(date: .omitted, time: .shortened))")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(16)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .contentTransition(.numericText())
        .onAppear {
            showingSuccess = true
        }
    }
}

// MARK: - Sync Status View Component

@available(iOS 26.0, *)
struct SyncStatusView: View {
    let status: SyncStatus
    let coParentNotified: Bool
    let isLoading: Bool

    var body: some View {
        HStack(spacing: 8) {
            // Status indicator
            if isLoading {
                ProgressView()
                    .scaleEffect(0.8)
            } else {
                Circle()
                    .fill(status.color)
                    .frame(width: 8, height: 8)
            }

            // Status text
            Text(isLoading ? "Syncing..." : status.displayText)
                .font(.caption)
                .foregroundColor(.secondary)

            Spacer()

            // Co-parent notification indicator
            if coParentNotified {
                HStack(spacing: 4) {
                    Image(systemName: "person.2.fill")
                        .font(.caption2)
                    Text("Co-parent notified")
                        .font(.caption2)
                }
                .foregroundColor(.blue)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Recent Walks Snippet Intent

// iOS 26 Snippet functionality commented out for now
// @available(iOS 26.0, *)
// struct ShowRecentWalksSnippetIntent: SnippetIntent {
//     static var title: LocalizedStringResource = "Recent Walks"
//     static var description = IntentDescription("Show recent walk history")
//
//     @Dependency
//     var walkStore: WalkDataStore
//
//     func perform() async throws -> some IntentResult & ShowsSnippetView {
//         return .result(view: RecentWalksSnippetView(walkStore: walkStore))
//     }
// }

@available(iOS 26.0, *)
struct RecentWalksSnippetView: View {
    @ObservedObject var walkStore: WalkDataStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Walks")
                .font(.headline)
                .fontWeight(.semibold)

            if walkStore.recentWalks.isEmpty {
                Text("No recent walks")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 20)
            } else {
                ForEach(walkStore.recentWalks.prefix(3), id: \.id) { walk in
                    RecentWalkRowView(walk: walk, walkStore: walkStore)
                }
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

@available(iOS 26.0, *)
struct RecentWalkRowView: View {
    let walk: WalkData
    @ObservedObject var walkStore: WalkDataStore

    var dogName: String {
        walkStore.getDog(by: walk.dogID)?.name ?? "Unknown Dog"
    }

    var body: some View {
        HStack {
            DogAvatarView(dogID: walk.dogID, size: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(dogName)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text("\(walk.walkType.displayName) • \(timeAgo(from: walk.date))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Image(systemName: walk.walkType.iconName)
                .font(.caption)
                .foregroundColor(walk.walkType == .walkAndPoop ? .brown : .blue)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Helper Views

@available(iOS 26.0, *)
struct DogAvatarView: View {
    let dogID: String
    let size: CGFloat

    var body: some View {
        Group {
            if let dog = WalkDataStore.shared.getDog(by: dogID),
               let imageData = dog.imageData,
               let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Image(systemName: "pawprint.fill")
                    .foregroundColor(.accentColor)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .background(
            Circle()
                .fill(Color.gray.opacity(0.2))
        )
    }
}

// MARK: - Helper Functions

private func timeAgo(from date: Date) -> String {
    let interval = Date().timeIntervalSince(date)

    if interval < 60 {
        return "Just now"
    } else if interval < 3600 {
        let minutes = Int(interval / 60)
        return "\(minutes)m ago"
    } else if interval < 86400 {
        let hours = Int(interval / 3600)
        return "\(hours)h ago"
    } else {
        let days = Int(interval / 86400)
        return "\(days)d ago"
    }
}