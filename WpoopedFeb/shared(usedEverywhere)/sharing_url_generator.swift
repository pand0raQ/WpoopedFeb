// where share url is generated 

import Foundation
import CloudKit

/// A utility class for handling sharing URLs in the app
class SharingURLGenerator {
    static let shared = SharingURLGenerator()
    
    private init() {}
    
    /// Generates a sharing URL from a CKShare object
    /// - Parameter share: The CKShare object to generate a URL for
    /// - Returns: A URL that can be used to share the record
    /// - Throws: CloudKitManagerError if URL generation fails
    func generateShareURL(from share: CKShare) async throws -> URL {
        guard let shareURL = share.url else {
            throw CloudKitManagerError.shareFailed("Could not generate share URL")
        }
        return shareURL
    }
    
    /// Validates if a given URL is a valid CloudKit sharing URL
    func isValidShareURL(_ url: URL) -> Bool {
        let isValidCloudKitURL = url.scheme?.hasPrefix("cloudkit-") == true
        let isValidICloudURL = url.host?.contains("icloud.com") == true && url.path.contains("/share/")
        return isValidCloudKitURL || isValidICloudURL
    }
    
    /// Processes and cleans a sharing URL
    /// - Parameter url: The URL to process
    /// - Returns: A cleaned URL suitable for sharing
    /// - Throws: CloudKitManagerError if URL is invalid
    func processAndCleanURL(_ url: URL) throws -> URL {
        // For direct URLs, remove fragment and query parameters
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        components?.fragment = nil
        components?.query = nil
        
        guard let cleanURL = components?.url else {
            throw CloudKitManagerError.invalidShareURL
        }
        return cleanURL
    }
} 