// This file is deprecated and should not be used
// Use SharingURLGenerator.swift instead

import Foundation

/// A utility class for handling sharing URLs in the app
// Commented out to avoid duplicate declaration
/* class SharingURLGenerator {
    static let shared = SharingURLGenerator()
    
    private init() {}
    
    /// Generates a sharing URL for a share ID
    /// - Parameter shareID: The share ID to include in the URL
    /// - Returns: A URL that can be used to share the record
    /// - Throws: FirestoreError if URL generation fails
    func generateShareURL(shareID: String) -> URL {
        // Create a URL with a custom scheme that the app can handle
        return URL(string: "wpooped://share?id=\(shareID)")!
    }
    
    /// Validates if a given URL is a valid sharing URL
    func isValidShareURL(_ url: URL) -> Bool {
        // Check if it's our custom scheme
        if url.scheme == "wpooped" && url.host == "share" {
            return true
        }
        
        // Check if it's a Firebase dynamic link
        let isFirebaseDynamicLink = url.host?.contains("firebasedynamiclinks.com") == true || 
                                   url.host?.contains("app.goo.gl") == true
        
        return isFirebaseDynamicLink
    }
    
    /// Processes and cleans a sharing URL
    /// - Parameter url: The URL to process
    /// - Returns: A cleaned URL suitable for sharing
    /// - Throws: FirestoreError if URL is invalid
    func processAndCleanURL(_ url: URL) throws -> URL {
        // For direct URLs, remove fragment and query parameters
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        components?.fragment = nil
        
        guard let cleanURL = components?.url else {
            throw FirestoreError.invalidShareURL
        }
        return cleanURL
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
        
        // Handle Firebase dynamic links
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
} */