import Foundation
import SwiftUI

// Extension to AuthManager for debugging purposes
extension AuthManager {
    // Force authentication state update
    func forceAuthStateUpdate() {
        // Try to load from UserDefaults
        if let data = UserDefaults.standard.data(forKey: "userData"),
           let userData = try? JSONDecoder().decode(User.self, from: data) {
            
            // Update state on the main thread
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                self.currentUserData = userData
                self.isAuthenticated = true
                
                // Post notification for auth state change
                NotificationCenter.default.post(name: .authStateChanged, object: nil)
                
                print("✅ Force updated auth state: isAuthenticated = \(self.isAuthenticated)")
            }
        } else {
            print("❌ No user data found in UserDefaults to force auth state update")
        }
    }
    
    // Debug method to print current auth state
    func printAuthState() {
        print("🔍 AUTH STATE 🔍")
        print("isAuthenticated: \(isAuthenticated)")
        print("currentUserData: \(String(describing: currentUserData))")
        
        // Check UserDefaults
        if let data = UserDefaults.standard.data(forKey: "userData") {
            print("UserDefaults has userData stored")
        } else {
            print("❌ No userData found in UserDefaults")
        }
    }
} 