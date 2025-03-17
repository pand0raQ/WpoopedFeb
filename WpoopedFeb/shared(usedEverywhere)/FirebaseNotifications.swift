import Foundation
import FirebaseFirestore
import FirebaseMessaging

/// Extension for Firebase notification handling
extension Notification.Name {
    static let firestoreDataChanged = Notification.Name("firestoreDataChanged")
    static let dogUpdated = Notification.Name("dogUpdated")
    static let walkUpdated = Notification.Name("walkUpdated")
}

/// A class to handle Firebase Cloud Messaging notifications
class FirebaseNotificationManager: NSObject, MessagingDelegate {
    static let shared = FirebaseNotificationManager()
    
    private override init() {
        super.init()
        setupMessaging()
    }
    
    private func setupMessaging() {
        Messaging.messaging().delegate = self
    }
    
    /// Called when a new FCM token is generated
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let token = fcmToken else { return }
        print("✅ Firebase registration token: \(token)")
        
        // Store this token in Firestore for the current user
        if let userID = AuthManager.shared.currentUser()?.id {
            let db = Firestore.firestore()
            db.collection("users").document(userID).updateData([
                "fcmToken": token,
                "lastTokenUpdate": Date()
            ]) { error in
                if let error = error {
                    print("❌ Error updating FCM token: \(error.localizedDescription)")
                } else {
                    print("✅ FCM token updated successfully")
                }
            }
        }
    }
    
    /// Subscribes the user to notifications for a specific dog
    /// - Parameter dogID: The ID of the dog to subscribe to
    func subscribeToDogUpdates(dogID: String) {
        Messaging.messaging().subscribe(toTopic: "dog_\(dogID)") { error in
            if let error = error {
                print("❌ Error subscribing to dog updates: \(error.localizedDescription)")
            } else {
                print("✅ Subscribed to updates for dog: \(dogID)")
            }
        }
    }
    
    /// Unsubscribes the user from notifications for a specific dog
    /// - Parameter dogID: The ID of the dog to unsubscribe from
    func unsubscribeFromDogUpdates(dogID: String) {
        Messaging.messaging().unsubscribe(fromTopic: "dog_\(dogID)") { error in
            if let error = error {
                print("❌ Error unsubscribing from dog updates: \(error.localizedDescription)")
            } else {
                print("✅ Unsubscribed from updates for dog: \(dogID)")
            }
        }
    }
    
    /// Handles incoming Firebase notifications
    /// - Parameter userInfo: The notification payload
    func handleNotification(userInfo: [AnyHashable: Any]) {
        print("📲 Processing Firebase notification")
        
        // Extract notification type
        guard let notificationType = userInfo["type"] as? String else {
            print("⚠️ Notification missing type information")
            return
        }
        
        switch notificationType {
        case "dog_update":
            if let dogID = userInfo["dogID"] as? String {
                handleDogUpdate(dogID: dogID)
            }
        case "walk_update":
            if let walkID = userInfo["walkID"] as? String {
                handleWalkUpdate(walkID: walkID)
            }
        case "share_invitation":
            if let shareID = userInfo["shareID"] as? String {
                handleShareInvitation(shareID: shareID)
            }
        default:
            print("⚠️ Unknown notification type: \(notificationType)")
        }
    }
    
    private func handleDogUpdate(dogID: String) {
        print("🐕 Handling dog update notification for ID: \(dogID)")
        
        // Fetch the updated dog data from Firestore
        Task {
            do {
                let dogDoc = try await Firestore.firestore().collection("dogs").document(dogID).getDocument()
                if dogDoc.exists {
                    // Post notification with the updated dog
                    NotificationCenter.default.post(
                        name: .dogUpdated,
                        object: nil,
                        userInfo: ["dogID": dogID]
                    )
                }
            } catch {
                print("❌ Error fetching updated dog: \(error.localizedDescription)")
            }
        }
    }
    
    private func handleWalkUpdate(walkID: String) {
        print("🚶‍♂️ Handling walk update notification for ID: \(walkID)")
        
        // Fetch the updated walk data from Firestore
        Task {
            do {
                let walkDoc = try await Firestore.firestore().collection("walks").document(walkID).getDocument()
                if walkDoc.exists {
                    // Post notification with the updated walk
                    NotificationCenter.default.post(
                        name: .walkUpdated,
                        object: nil,
                        userInfo: ["walkID": walkID]
                    )
                }
            } catch {
                print("❌ Error fetching updated walk: \(error.localizedDescription)")
            }
        }
    }
    
    private func handleShareInvitation(shareID: String) {
        print("🔗 Handling share invitation notification for ID: \(shareID)")
        
        // Post notification about the share invitation
        NotificationCenter.default.post(
            name: .shareReceived,
            object: nil,
            userInfo: ["shareID": shareID]
        )
    }
}

// Additional notification name for share invitations
extension Notification.Name {
    static let shareReceived = Notification.Name("shareReceived")
}
