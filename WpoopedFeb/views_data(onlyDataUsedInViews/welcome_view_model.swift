import SwiftUI
import AuthenticationServices

@MainActor
class WelcomeViewModel: ObservableObject {
    private let authManager = AuthManager.shared
    
    func signInWithApple() {
        authManager.signInWithApple()
    }
    
    func getStarted() {
        UserDefaults.standard.set(true, forKey: "hasSeenWelcome")
    }
} 