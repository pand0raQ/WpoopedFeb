import AVFoundation
import CloudKit
import SwiftUI
import SwiftData

@MainActor
class QRCodeScannerViewModel: NSObject, ObservableObject {
    // MARK: - Published Properties
    @Published var scannedCode: String?
    @Published var error: Error?
    @Published var isScanning = true
    @Published var extractedURL: URL?
    @Published var showingShareAcceptance = false
    @Published var shareMetadata: (dogName: String, ownerName: String)?
    @Published var isProcessingShare = false
    @Published var shareError: String?
    @Published var shareAcceptanceStatus: String = ""
    
    // MARK: - Private Properties
    private let sharingManager = CloudKitSharingManager.shared
    private var lastScannedCode: String?
    private let modelContext: ModelContext
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        super.init()
    }
    
    // MARK: - QRCodeScannerDelegate Implementation
    nonisolated func didFind(code: String) {
        Task { @MainActor in
            // Prevent processing the same code multiple times
            guard code != lastScannedCode else { return }
            
            // Only process if it's a valid URL
            guard let url = URL(string: code) else { return }
            
            isScanning = false
            lastScannedCode = code
            scannedCode = code
            extractedURL = url
            
            await processShareURL(url)
        }
    }
    
    nonisolated func didFail(with error: Error) {
        Task { @MainActor in
            self.error = error
            isScanning = true
        }
    }
    
    // MARK: - Share Handling
    private func processShareURL(_ url: URL) async {
        isProcessingShare = true
        shareError = nil
        shareAcceptanceStatus = "Testing..."
        
        do {
            // Fetch share metadata using CloudKitSharingManager
            let metadata = try await sharingManager.getShareMetadata(from: url)
            await MainActor.run {
                self.shareMetadata = metadata
                self.showingShareAcceptance = true
            }
        } catch {
            print("❌ Share metadata fetch failed with error: \(error.localizedDescription)")
            print("🔍 Detailed error: \(error)")
            shareError = error.localizedDescription
            shareAcceptanceStatus = "❌ Failed to fetch share metadata: \(error.localizedDescription)"
        }
        
        isProcessingShare = false
    }
    
    func acceptShare() async {
        guard let url = extractedURL else {
            print("❌ No valid URL to accept share")
            shareError = "No valid URL to accept share"
            return
        }
        
        await MainActor.run {
            isProcessingShare = true
            shareError = nil
        }
        
        do {
            // Use the injected modelContext instead of creating a new one
            try await sharingManager.acceptShare(from: url, context: modelContext)
            
            await MainActor.run {
                shareAcceptanceStatus = "✅ Share accepted successfully"
                showingShareAcceptance = false
                isProcessingShare = false
            }
        } catch {
            print("❌ Share acceptance failed with error: \(error.localizedDescription)")
            print("🔍 Detailed error: \(error)")
            
            await MainActor.run {
                shareError = error.localizedDescription
                shareAcceptanceStatus = "❌ Failed to accept share: \(error.localizedDescription)"
                isProcessingShare = false
            }
        }
    }
    
    // MARK: - Public Methods
    func resetScanner() {
        isScanning = true
        scannedCode = nil
        lastScannedCode = nil
        extractedURL = nil
        error = nil
        shareMetadata = nil
        shareError = nil
        shareAcceptanceStatus = ""
    }
}

// Make QRCodeScannerViewModel conform to QRCodeScannerDelegate
extension QRCodeScannerViewModel: QRCodeScannerDelegate {}
