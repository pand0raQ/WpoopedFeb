// all needed data for the dog detail view

import Foundation
import SwiftUI
import CloudKit

@MainActor
class DogDetailViewModel: ObservableObject {
    let dog: Dog
    
    @Published var qrCodeImage: UIImage?
    @Published var isShowingQRCode = false
    @Published var isSharing = false
    @Published var shareError: Error?
    @Published var showingError = false
    
    init(dog: Dog) {
        self.dog = dog
    }
    
    func shareButtonTapped() {
        Task {
            isSharing = true
            defer { isSharing = false }
            
            do {
                let share = try await CloudKitSharingManager.shared.shareDog(dog)
                if let shareURL = try? await SharingURLGenerator.shared.generateShareURL(from: share) {
                    if let qrCode = ShareQRGenerator.shared.generateQRCode(from: shareURL) {
                        // Save QR code to UserDefaults
                        if let qrData = qrCode.pngData() {
                            dog.qrCodeData = qrData
                        }
                        qrCodeImage = qrCode
                        isShowingQRCode = true
                    }
                }
            } catch {
                shareError = error
                showingError = true
            }
        }
    }
    
    func generateQRCode() {
        // First try to load from UserDefaults
        if let savedQRData = dog.qrCodeData,
           let savedQRImage = UIImage(data: savedQRData) {
            qrCodeImage = savedQRImage
            return
        }
        
        // If not in UserDefaults, generate from shareURL
        if let shareURL = dog.shareURL,
           let qrCode = ShareQRGenerator.shared.generateQRCode(from: shareURL) {
            // Save to UserDefaults
            if let qrData = qrCode.pngData() {
                dog.qrCodeData = qrData
            }
            qrCodeImage = qrCode
        }
    }
    
    func showQRCode() {
        isShowingQRCode = true
    }
    
    func hideQRCode() {
        isShowingQRCode = false
    }
}