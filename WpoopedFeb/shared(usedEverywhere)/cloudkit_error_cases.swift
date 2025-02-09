import Foundation

enum CloudKitManagerError: LocalizedError {
    case userNotFound
    case saveFailed(String)
    case updateFailed(String)
    case recordNotFound
    case unexpectedRecordType
    case assetCreationFailed
    case shareFailed(String)
    case invalidShareURL
    
    var errorDescription: String? {
        switch self {
        case .userNotFound:
            return "iCloud account not found. Please sign in to iCloud in Settings."
        case .saveFailed(let message):
            return "Failed to save to iCloud: \(message)"
        case .updateFailed(let message):
            return "Failed to update in iCloud: \(message)"
        case .recordNotFound:
            return "Record not found in iCloud"
        case .unexpectedRecordType:
            return "Unexpected record type received from iCloud"
        case .assetCreationFailed:
            return "Failed to create asset for iCloud storage"
        case .shareFailed(let message):
            return "Failed to share: \(message)"
        case .invalidShareURL:
            return "Invalid sharing URL"
        }
    }
}
