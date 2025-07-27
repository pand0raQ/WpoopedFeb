import UIKit
import FirebaseCore
import FirebaseFirestore
import UserNotifications

extension NSNotification.Name {
    static let firestoreDataChanged = NSNotification.Name("firestoreDataChanged")
}

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        print("📱 App delegate initialized")
        
        // Use the shared Firebase configuration manager instead of directly configuring Firebase
        // This ensures Firebase is only initialized once
        _ = FirebaseConfigurationManager.shared
        print("✅ Firebase configured via shared manager")
        
        // Register for remote notifications
        registerForRemoteNotifications()
        
        // Debug auth state after a short delay to ensure everything is initialized
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            if let authDebugger = NSClassFromString("WpoopedFeb.AuthDebugger") as? NSObject.Type,
               let sharedMethod = authDebugger.value(forKey: "shared") as? NSObject,
               let debugMethod = sharedMethod.value(forKey: "debugAuthState") as? () -> Void {
                debugMethod()
            } else {
                print("⚠️ AuthDebugger not available yet")
            }
        }
        
        return true
    }
    
    private func registerForRemoteNotifications() {
        // Request notification authorization
        let notificationCenter = UNUserNotificationCenter.current()
        notificationCenter.delegate = self
        
        notificationCenter.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                print("✅ Notification authorization granted")
            } else if let error = error {
                print("❌ Notification authorization error: \(error.localizedDescription)")
            }
        }
        
        // Register for remote notifications
        DispatchQueue.main.async {
            UIApplication.shared.registerForRemoteNotifications()
        }
    }
    
    // Called when a notification is delivered to a foreground app
    func userNotificationCenter(_ center: UNUserNotificationCenter, 
                               willPresent notification: UNNotification,
                               withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Process the notification
        let userInfo = notification.request.content.userInfo
        handleNotification(userInfo: userInfo)
        
        // Show the notification in the foreground
        completionHandler([.banner, .sound])
    }
    
    // Called when user taps on a notification
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                               didReceive response: UNNotificationResponse,
                               withCompletionHandler completionHandler: @escaping () -> Void) {
        // Process the notification
        let userInfo = response.notification.request.content.userInfo
        handleNotification(userInfo: userInfo)
        
        completionHandler()
    }
    
    // Handle incoming remote notifications
    func application(_ application: UIApplication, 
                    didReceiveRemoteNotification userInfo: [AnyHashable: Any],
                    fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        print("📳 Received remote notification")
        
        // Check if this is a walk update notification that needs background processing
        if let notificationType = userInfo["type"] as? String,
           notificationType == "walk_update" {
            print("🚶‍♂️ Processing walk update notification in background")
            
            // Process walk update in background
            Task {
                await handleBackgroundWalkUpdate(userInfo: userInfo)
                completionHandler(.newData)
            }
        } else {
            // Process other notifications normally
            handleNotification(userInfo: userInfo)
            completionHandler(.newData)
        }
    }
    
    // Process Firebase notifications
    private func handleNotification(userInfo: [AnyHashable: Any]) {
        // Check if this is a Firebase notification
        if let _ = userInfo["gcm.message_id"] {
            print("📳 Received Firebase notification")
            
            // Post notification for app to handle
            NotificationCenter.default.post(name: .firestoreDataChanged, object: nil, userInfo: userInfo)
        }
    }
    
    // Handle walk update notifications in background
    private func handleBackgroundWalkUpdate(userInfo: [AnyHashable: Any]) async {
        guard let dogID = userInfo["dogID"] as? String else {
            print("❌ No dogID in walk update notification")
            return
        }
        
        print("🔄 Handling background walk update for dog: \(dogID)")
        
        do {
            // Fetch the latest walk data from Firebase
            let db = FirebaseConfigurationManager.shared.getFirestore()
            
            // Get the most recent walk for this dog
            let walksQuery = db.collection("walks")
                .whereField("dogID", isEqualTo: dogID)
                .order(by: "date", descending: true)
                .limit(to: 1)
            
            let snapshot = try await walksQuery.getDocuments()
            
            if let document = snapshot.documents.first {
                // Convert to WalkData for widget
                let data = document.data()
                
                guard let walkTypeRaw = data["walkType"] as? Int,
                      let walkType = WalkType(rawValue: walkTypeRaw),
                      let date = (data["date"] as? Timestamp)?.dateValue() else {
                    print("❌ Invalid walk data in notification")
                    return
                }
                
                let walkData = WalkData(
                    id: document.documentID,
                    dogID: dogID,
                    date: date,
                    walkType: walkType,
                    ownerName: userInfo["ownerName"] as? String
                )
                
                // Update shared data for widget
                SharedDataManager.shared.saveLatestWalk(dogID: dogID, walkData: walkData)
                
                // Trigger widget timeline refresh
                SharedDataManager.shared.updateWidgetTimeline(for: dogID)
                
                print("✅ Updated widget data from background notification")
                
                // Also post notification for the main app if it's active
                await MainActor.run {
                    NotificationCenter.default.post(
                        name: .firestoreDataChanged,
                        object: nil,
                        userInfo: ["walkID": document.documentID, "dogID": dogID, "source": "background_notification"]
                    )
                }
            } else {
                print("⚠️ No walk found for background update")
            }
        } catch {
            print("❌ Error handling background walk update: \(error.localizedDescription)")
        }
    }
    
    // Called when the app successfully registers for remote notifications
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let tokenParts = deviceToken.map { data in String(format: "%02.2hhx", data) }
        let token = tokenParts.joined()
        print("✅ Device token registered: \(token)")
    }
    
    // Called when the app fails to register for remote notifications
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("❌ Failed to register for remote notifications: \(error.localizedDescription)")
    }
}
