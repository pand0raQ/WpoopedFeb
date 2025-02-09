import Foundation
import CoreImage.CIFilterBuiltins
import UIKit

/// A utility class for generating QR codes from sharing URLs
class ShareQRGenerator {
    static let shared = ShareQRGenerator()
    
    private let context = CIContext()
    private let generator = CIFilter.qrCodeGenerator()
    
    private init() {}
    
    /// Generates a QR code image from a URL string
    /// - Parameters:
    ///   - url: The URL to encode in the QR code
    ///   - size: The desired size of the QR code image (default: 200)
    /// - Returns: A UIImage containing the QR code, or nil if generation fails
    func generateQRCode(from url: URL, size: CGFloat = 200) -> UIImage? {
        print("🔄 Generating QR code for URL: \(url)")
        
        // Convert URL to data
        guard let data = url.absoluteString.data(using: .utf8) else {
            print("❌ Failed to convert URL to data")
            return nil
        }
        
        // Generate QR code
        generator.setValue(data, forKey: "inputMessage")
        
        guard let outputImage = generator.outputImage else {
            print("❌ Failed to generate QR code")
            return nil
        }
        
        // Scale the image
        let scaleFactor = size / outputImage.extent.width
        let scaled = outputImage.transformed(by: CGAffineTransform(scaleX: scaleFactor, y: scaleFactor))
        
        // Convert to UIImage
        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else {
            print("❌ Failed to create CGImage")
            return nil
        }
        
        print("✅ QR code generated successfully")
        return UIImage(cgImage: cgImage)
    }
    
    /// Generates a QR code image from a sharing URL string
    /// - Parameters:
    ///   - urlString: The URL string to encode in the QR code
    ///   - size: The desired size of the QR code image (default: 200)
    /// - Returns: A UIImage containing the QR code, or nil if generation fails
    func generateQRCode(from urlString: String, size: CGFloat = 200) -> UIImage? {
        guard let url = URL(string: urlString) else {
            print("❌ Invalid URL string")
            return nil
        }
        return generateQRCode(from: url, size: size)
    }
    
    /// Generates a QR code for a shared dog
    /// - Parameters:
    ///   - dog: The shared dog to generate a QR code for
    ///   - size: The desired size of the QR code image (default: 200)
    /// - Returns: A UIImage containing the QR code, or nil if generation fails
    func generateQRCodeForDog(_ dog: Dog, size: CGFloat = 200) -> UIImage? {
        // If we already have a QR code saved, return it
        if let qrCodeData = dog.qrCodeData,
           let savedQRCode = UIImage(data: qrCodeData) {
            print("✅ Using saved QR code")
            return savedQRCode
        }
        
        guard let shareURL = dog.shareURL else {
            print("❌ No share URL available for dog")
            return nil
        }
        
        guard let qrCode = generateQRCode(from: shareURL, size: size) else {
            return nil
        }
        
        // Save the generated QR code
        if let qrCodeData = qrCode.pngData() {
            dog.qrCodeData = qrCodeData
            
            // Save to CloudKit
            Task {
                await dog.saveToCloudKit()
            }
        }
        
        return qrCode
    }
}