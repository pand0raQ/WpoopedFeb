// apple sign in , signout checking if user sign in and informing that no need to call welcome view

import Foundation
import AuthenticationServices
import SwiftUI

class AuthManager: NSObject, ObservableObject {
    static let shared = AuthManager()
    @Published var isAuthenticated = false
    @Published var error: String?
    @Published var isLoading = false
    
    private override init() {
        super.init()
        loadStoredAuthState()
    }
    
    struct UserData: Codable {
        let id: String
        let name: String
        let email: String
        let signUpDate: Date
        
        var formattedSignUpDate: String {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            return formatter.string(from: signUpDate)
        }
    }
    
    // MARK: - Auth State
    private func loadStoredAuthState() {
        isAuthenticated = currentUser() != nil
    }
    
    // MARK: - Sign In
    func signInWithApple() {
        let provider = ASAuthorizationAppleIDProvider()
        let request = provider.createRequest()
        request.requestedScopes = [.fullName, .email]
        
        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.performRequests()
    }
    
    // MARK: - Auth Handling
    func handleAppleSignIn(_ credential: ASAuthorizationAppleIDCredential) {
        let userData = UserData(
            id: credential.user,
            name: [credential.fullName?.givenName, credential.fullName?.familyName]
                .compactMap { $0 }
                .joined(separator: " "),
            email: credential.email ?? "",
            signUpDate: Date()
        )
        
        persistUserData(userData)
        isAuthenticated = true
    }
    
    func signOut() {
        UserDefaults.standard.removeObject(forKey: "userData")
        isAuthenticated = false
    }
    
    // MARK: - Data Persistence
    private func persistUserData(_ data: UserData) {
        if let encoded = try? JSONEncoder().encode(data) {
            UserDefaults.standard.set(encoded, forKey: "userData")
        }
    }
    
    func currentUser() -> UserData? {
        guard let data = UserDefaults.standard.data(forKey: "userData"),
              let userData = try? JSONDecoder().decode(UserData.self, from: data) else {
            return nil
        }
        return userData
    }
}

// MARK: - ASAuthorizationControllerDelegate
extension AuthManager: ASAuthorizationControllerDelegate {
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
            handleAppleSignIn(appleIDCredential)
        }
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        self.error = error.localizedDescription
    }
}

// MARK: - ASAuthorizationControllerPresentationContextProviding
extension AuthManager: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = scene.windows.first else {
            return UIWindow()
        }
        return window
    }
}