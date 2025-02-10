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
}
