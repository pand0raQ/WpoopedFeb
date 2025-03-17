import UIKit
import FirebaseCore
import FirebaseFirestore
import UserNotifications

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
        
        // Process the notification
        handleNotification(userInfo: userInfo)
        
        completionHandler(.newData)
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
