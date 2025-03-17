import Foundation

/// Error types for sharing URL operations
enum SharingURLError: Error, LocalizedError {
    case invalidShareURL
    case shareFailed(String)
    case unsupportedURLType
    
    var errorDescription: String? {
        switch self {
        case .invalidShareURL:
            return "Invalid sharing URL"
        case .shareFailed(let message):
            return "Failed to share: \(message)"
        case .unsupportedURLType:
            return "Unsupported URL type"
        }
    }
}

/// A utility class for generating and handling sharing URLs
class SharingURLGenerator {
    static let shared = SharingURLGenerator()
    
    private init() {}
    
    /// Generates a sharing URL for a dog
    /// - Parameter shareID: The share ID to include in the URL
    /// - Returns: A URL that can be used to share the dog
    func generateSharingURL(shareID: String) -> URL {
        // Create a URL with a custom scheme that the app can handle
        return URL(string: "wpooped://share?id=\(shareID)")!
    }
    
    /// Extracts a share ID from a sharing URL
    /// - Parameter url: The URL to extract from
    /// - Returns: The share ID if found, nil otherwise
    func extractShareID(from url: URL) -> String? {
        // Handle our custom URL scheme
        if url.scheme == "wpooped", url.host == "share" {
            // Parse URL components
            guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
                  let queryItems = components.queryItems else {
                return nil
            }
            
            // Find the id parameter
            return queryItems.first(where: { $0.name == "id" })?.value
        }
        
        // Handle Firebase dynamic links (if used)
        if url.host?.contains("firebasedynamiclinks.com") == true || 
           url.host?.contains("app.goo.gl") == true {
            guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
                  let queryItems = components.queryItems else {
                return nil
            }
            
            return queryItems.first(where: { $0.name == "shareId" })?.value
        }
        
        return nil
    }
    
    /// Validates if a given URL is a valid sharing URL
    /// - Parameter url: The URL to validate
    /// - Returns: True if the URL is valid for sharing
    func isValidShareURL(_ url: URL) -> Bool {
        // Check if it's our custom URL scheme
        if url.scheme == "wpooped" && url.host == "share" {
            return true
        }
        
        // Check if it's a Firebase dynamic link
        if url.host?.contains("firebasedynamiclinks.com") == true || 
           url.host?.contains("app.goo.gl") == true {
            return true
        }
        
        return false
    }
    
    /// Processes and cleans a sharing URL
    /// - Parameter url: The URL to process
    /// - Returns: A cleaned URL suitable for sharing
    /// - Throws: SharingURLError if URL is invalid
    func processAndCleanURL(_ url: URL) throws -> URL {
        // For direct URLs, remove fragment and query parameters
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        
        // Keep only essential query parameters
        if let queryItems = components?.queryItems {
            let essentialParams = queryItems.filter { item in
                return ["id", "shareId"].contains(item.name)
            }
            components?.queryItems = essentialParams.isEmpty ? nil : essentialParams
        }
        
        components?.fragment = nil
        
        guard let cleanURL = components?.url else {
            throw SharingURLError.invalidShareURL
        }
        return cleanURL
    }
}
