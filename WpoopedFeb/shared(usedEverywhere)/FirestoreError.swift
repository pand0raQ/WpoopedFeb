import Foundation

/// Errors that can occur during Firestore operations
enum FirestoreError: Error, LocalizedError {
    case documentNotFound
    case invalidDocumentData
    case unexpectedDocumentType
    case invalidShareData
    case imageUploadFailed
    case imageDownloadFailed
    case userNotAuthenticated
    case operationFailed(String)
    case invalidDocumentID
    case saveFailed(String)
    case updateFailed(String)
    case deleteFailed(String)
    case fetchFailed(String)
    case shareFailed(String)
    case userNotFound
    case invalidShareURL
    case shareAcceptanceFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .documentNotFound:
            return "The requested document was not found in Firestore."
        case .invalidDocumentData:
            return "The document data is invalid or corrupted."
        case .unexpectedDocumentType:
            return "The document type does not match the expected format."
        case .invalidShareData:
            return "The share data is invalid or missing required fields."
        case .imageUploadFailed:
            return "Failed to upload image to Firebase Storage."
        case .imageDownloadFailed:
            return "Failed to download image from Firebase Storage."
        case .userNotAuthenticated:
            return "User is not authenticated. Please sign in to continue."
        case .operationFailed(let message):
            return "Operation failed: \(message)"
        case .invalidDocumentID:
            return "Invalid document ID"
        case .saveFailed(let message):
            return "Save failed: \(message)"
        case .updateFailed(let message):
            return "Update failed: \(message)"
        case .deleteFailed(let message):
            return "Delete failed: \(message)"
        case .fetchFailed(let message):
            return "Fetch failed: \(message)"
        case .shareFailed(let message):
            return "Share failed: \(message)"
        case .userNotFound:
            return "User not found"
        case .invalidShareURL:
            return "Invalid share URL"
        case .shareAcceptanceFailed(let message):
            return "Share acceptance failed: \(message)"
        }
    }
}
