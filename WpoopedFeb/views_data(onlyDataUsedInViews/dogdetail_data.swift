// all needed data for the dog detail view

import Foundation
import SwiftUI
import CloudKit
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
    
    @Published var qrCodeImage: UIImage?
    
    init(dog: Dog, modelContext: ModelContext) {
        self.dog = dog
        self.modelContext = modelContext
        loadQRCode()
    }
    
    private func loadQRCode() {
        if let savedQRData = dog.qrCodeData,
           let savedQRImage = UIImage(data: savedQRData) {
            qrCodeImage = savedQRImage
            isShowingQRCode = true
        } else if let shareURLString = dog.shareURL,
                  let shareURL = URL(string: shareURLString) {
            generateQRCodeFromURL(shareURL)
            isShowingQRCode = true
        }
    }
    
    func shareButtonTapped() async {
        isSharing = true
        defer { isSharing = false }
        
        do {
            let share = try await CloudKitSharingManager.shared.shareDog(dog)
            if let shareURL = try? await SharingURLGenerator.shared.generateShareURL(from: share) {
                generateQRCodeFromURL(shareURL)
                isShowingQRCode = true
            }
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
            let walk = Walk(walkType: type, dog: dog)
            modelContext.insert(walk)
            
            // Only sync with CloudKit if the dog is shared
            if dog.isShared ?? false {
                try await CloudKitManager.shared.saveWalk(walk)
            }
            
            try modelContext.save()
            
            // For shared dogs, we need to refresh from CloudKit to ensure consistency
            if dog.isShared ?? false {
                await refreshWalks()
            }
        } catch {
            showError = true
            errorMessage = "Failed to log walk: \(error.localizedDescription)"
        }
    }
    
    func refreshWalks() async {
        guard !isLoadingWalks else { return }
        
        isLoadingWalks = true
        defer { isLoadingWalks = false }
        
        do {
            // For shared dogs, fetch walks from CloudKit to ensure consistency
            if dog.isShared ?? false {
                let walks = try await CloudKitManager.shared.fetchWalks(for: dog)
                dog.walks = walks
                try modelContext.save()
            }
            // For non-shared dogs, walks are already in the local database
            // through the SwiftData relationship, no need to fetch
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
