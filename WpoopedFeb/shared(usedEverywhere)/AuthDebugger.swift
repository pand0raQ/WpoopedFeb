import Foundation
import SwiftUI
import FirebaseAuth
import FirebaseFirestore

// This class will help debug and fix authentication issues
class AuthDebugger {
    static let shared = AuthDebugger()
    
    func debugAuthState() {
        let authManager = AuthManager.shared
        
        print("🔍 AUTH DEBUGGER 🔍")
        print("isAuthenticated: \(authManager.isAuthenticated)")
        print("currentUserData: \(String(describing: authManager.currentUserData))")
        
        // Check UserDefaults for stored auth data
        if let data = UserDefaults.standard.data(forKey: "userData") {
            print("UserDefaults has userData stored")
            if let userData = try? JSONDecoder().decode(User.self, from: data) {
                print("Successfully decoded User from UserDefaults:")
                print("  - ID: \(userData.id)")
                print("  - Email: \(userData.email)")
                print("  - Display Name: \(userData.displayName ?? "nil")")
            } else {
                print("❌ Failed to decode User from UserDefaults")
            }
        } else {
            print("❌ No userData found in UserDefaults")
        }
        
        // Force update auth state
        self.forceUpdateAuthState()
    }
    
    func forceUpdateAuthState() {
        let authManager = AuthManager.shared
        
        // Try to load from UserDefaults
        if let data = UserDefaults.standard.data(forKey: "userData"),
           let userData = try? JSONDecoder().decode(User.self, from: data) {
            
            // Force update the auth state on the main thread
            DispatchQueue.main.async {
                authManager.currentUserData = userData
                authManager.isAuthenticated = true
                print("✅ AUTH DEBUGGER: Forced auth state update to authenticated")
                
                // Post a notification to trigger UI updates
                NotificationCenter.default.post(name: .authStateChanged, object: nil)
                
                // Try to authenticate with Firebase
                self.authenticateWithFirebase(userData: userData)
            }
        }
    }
    
    // New method to authenticate with Firebase using anonymous auth
    func authenticateWithFirebase(userData: User) {
        // Check if already authenticated with Firebase
        if Auth.auth().currentUser != nil {
            print("✅ Already authenticated with Firebase")
            return
        }
        
        print("🔄 Attempting to authenticate with Firebase anonymously")
        
        // Sign in anonymously to Firebase
        Auth.auth().signInAnonymously { authResult, error in
            if let error = error {
                print("❌ Failed to sign in anonymously to Firebase: \(error.localizedDescription)")
                return
            }
            
            guard let firebaseUser = authResult?.user else {
                print("❌ No Firebase user returned from anonymous sign in")
                return
            }
            
            print("✅ Successfully signed in anonymously to Firebase")
            print("🔑 Firebase UID: \(firebaseUser.uid)")
            
            // Update the user document in Firestore to link the Apple ID with the Firebase UID
            let db = Firestore.firestore()
            
            // First, create/update the user document with the Firebase UID
            db.collection("users").document(firebaseUser.uid).setData([
                "id": firebaseUser.uid,
                "appleUserID": userData.id,
                "email": userData.email,
                "displayName": userData.displayName ?? "",
                "createdAt": userData.createdAt,
                "lastLogin": Date()
            ]) { error in
                if let error = error {
                    print("❌ Failed to update user document: \(error.localizedDescription)")
                } else {
                    print("✅ Successfully updated user document with Firebase UID")
                    
                    // Update the stored user data with Firebase UID
                    DispatchQueue.main.async {
                        AuthManager.shared.currentUserData?.id = firebaseUser.uid
                        
                        // Persist the updated user data
                        if let updatedUserData = AuthManager.shared.currentUserData,
                           let encoded = try? JSONEncoder().encode(updatedUserData) {
                            UserDefaults.standard.set(encoded, forKey: "userData")
                            print("✅ Updated stored user data with Firebase UID")
                        }
                    }
                }
            }
        }
    }
}

// Add a notification name for auth state changes
extension Notification.Name {
    static let authStateChanged = Notification.Name("authStateChanged")
}

// Add a view modifier to listen for auth state changes
struct AuthStateListenerModifier: ViewModifier {
    @Binding var isAuthenticated: Bool
    
    func body(content: Content) -> some View {
        content
            .onAppear {
                // Debug auth state when view appears
                AuthDebugger.shared.debugAuthState()
                
                // Add notification observer
                NotificationCenter.default.addObserver(
                    forName: .authStateChanged,
                    object: nil,
                    queue: .main
                ) { _ in
                    // Update binding when auth state changes
                    isAuthenticated = AuthManager.shared.isAuthenticated
                    print("📱 Auth state changed to: \(isAuthenticated)")
                }
            }
    }
}

// Extension to make the modifier easier to use
extension View {
    func listenToAuthStateChanges(isAuthenticated: Binding<Bool>) -> some View {
        self.modifier(AuthStateListenerModifier(isAuthenticated: isAuthenticated))
    }
} 