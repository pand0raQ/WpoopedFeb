import Foundation
import FirebaseAuth
import FirebaseFirestore
import SwiftUI
import AuthenticationServices
import CommonCrypto

/// A simple user model to represent the authenticated user
struct User: Codable {
    var id: String
    var email: String
    var displayName: String?
    var createdAt: Date
    
    var formattedSignUpDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: createdAt)
    }
}

/// Authentication manager for handling both Apple Sign In and Firebase Auth operations
class AuthManager: NSObject, ObservableObject {
    static let shared = AuthManager()
    
    @Published var isAuthenticated: Bool = false
    @Published var currentUserData: User?
    @Published var error: String?
    @Published var isLoading = false
    
    private let auth = Auth.auth()
    private let db = Firestore.firestore()
    private var currentNonce: String?
    
    private override init() {
        super.init()
        
        // First check if we have stored Apple Sign In data
        loadStoredAuthState()
        
        // Then check Firebase auth state
        if !isAuthenticated, let firebaseUser = auth.currentUser {
            self.isAuthenticated = true
            self.currentUserData = User(
                id: firebaseUser.uid,
                email: firebaseUser.email ?? "",
                displayName: firebaseUser.displayName,
                createdAt: Date()
            )
            
            // Fetch additional user data from Firestore
            fetchUserData(userID: firebaseUser.uid)
        }
        
        // Add Firebase auth state listener
        auth.addStateDidChangeListener { [weak self] _, user in
            DispatchQueue.main.async {
                if let firebaseUser = user {
                    self?.isAuthenticated = true
                    self?.currentUserData = User(
                        id: firebaseUser.uid,
                        email: firebaseUser.email ?? "",
                        displayName: firebaseUser.displayName,
                        createdAt: Date()
                    )
                    
                    // Fetch additional user data from Firestore
                    self?.fetchUserData(userID: firebaseUser.uid)
                } else if self?.currentUserData == nil {
                    // Only set to false if we don't have Apple Sign In data
                    self?.isAuthenticated = false
                }
            }
        }
    }
    
    // MARK: - Auth State Management
    
    private func loadStoredAuthState() {
        // Try to load from UserDefaults first (Apple Sign In)
        if let data = UserDefaults.standard.data(forKey: "userData"),
           let userData = try? JSONDecoder().decode(User.self, from: data) {
            self.isAuthenticated = true
            self.currentUserData = userData
        }
        // If not found, Firebase auth state listener will handle it
    }
    
    private func persistUserData(_ userData: User) {
        if let encoded = try? JSONEncoder().encode(userData) {
            UserDefaults.standard.set(encoded, forKey: "userData")
        }
    }
    
    /// Returns the current authenticated user
    /// - Returns: User object if authenticated, nil otherwise
    func currentUser() -> User? {
        // First check if we have a current user from Firebase or memory
        if let userData = currentUserData {
            return userData
        }
        
        // Try to load from UserDefaults (Apple Sign In)
        if let data = UserDefaults.standard.data(forKey: "userData"),
           let userData = try? JSONDecoder().decode(User.self, from: data) {
            // Cache the user data
            self.currentUserData = userData
            return userData
        }
        
        return nil
    }
    
    // MARK: - Apple Sign In Methods
    
    func signInWithApple() {
        isLoading = true
        
        // Generate a random nonce for authentication
        let nonce = randomNonceString()
        currentNonce = nonce
        
        let provider = ASAuthorizationAppleIDProvider()
        let request = provider.createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256(nonce)
        
        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        controller.performRequests()
    }
    
    func handleAppleSignIn(_ credential: ASAuthorizationAppleIDCredential) {
        print("🔄 Handling Apple Sign In")
        
        // Create a user from Apple credentials
        let fullName = [credential.fullName?.givenName, credential.fullName?.familyName]
            .compactMap { $0 }
            .joined(separator: " ")
        
        let userData = User(
            id: credential.user,
            email: credential.email ?? "",
            displayName: fullName.isEmpty ? nil : fullName,
            createdAt: Date()
        )
        
        // Save to UserDefaults and update state
        persistUserData(userData)
        
        // Update state on the main thread
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.currentUserData = userData
            self.isAuthenticated = true
            self.isLoading = false
            
            // Post notification for auth state change
            NotificationCenter.default.post(name: .authStateChanged, object: nil)
            
            print("✅ Successfully authenticated with Apple ID")
            print("🔑 Auth state updated: isAuthenticated = \(self.isAuthenticated)")
        }
        
        // Also sign in to Firebase with Apple credential if possible
        if let identityToken = credential.identityToken,
           let tokenString = String(data: identityToken, encoding: .utf8) {
            
            // Ensure we have a nonce
            guard let nonce = currentNonce else {
                print("❌ Invalid state: A login callback was received, but no login request was sent.")
                return
            }
            
            print("🔑 Got Apple identity token, signing in to Firebase")
            
            // Create Firebase credential
            let firebaseCredential = OAuthProvider.credential(
                withProviderID: "apple.com",
                idToken: tokenString,
                rawNonce: nonce
            )
            
            // Sign in to Firebase with Apple credential
            Task {
                do {
                    // Sign in to Firebase and get the user
                    let authResult = try await auth.signIn(with: firebaseCredential)
                    let firebaseUser = authResult.user
                    
                    print("✅ Successfully signed in to Firebase with Apple")
                    print("🔑 Firebase UID: \(firebaseUser.uid)")
                    print("🔑 Firebase provider data: \(firebaseUser.providerData.map { $0.providerID })")
                    
                    // Update the user data with Firebase UID if needed
                    if userData.id != firebaseUser.uid {
                        print("⚠️ Note: Apple user ID (\(userData.id)) differs from Firebase UID (\(firebaseUser.uid))")
                    }
                    
                    // Save user data to Firestore using Firebase UID to ensure permissions work
                    let firestoreUserData = User(
                        id: firebaseUser.uid,
                        email: userData.email,
                        displayName: userData.displayName,
                        createdAt: userData.createdAt
                    )
                    
                    try await saveUserToFirestore(firestoreUserData)
                    
                    // Update the stored user data with Firebase UID
                    DispatchQueue.main.async { [weak self] in
                        self?.currentUserData?.id = firebaseUser.uid
                        self?.persistUserData(firestoreUserData)
                        print("✅ Updated stored user data with Firebase UID")
                    }
                    
                } catch {
                    print("⚠️ Firebase sign in with Apple failed: \(error.localizedDescription)")
                    
                    // Even if Firebase auth fails, we still want to save to Firestore if possible
                    do {
                        try await saveUserToFirestore(userData)
                    } catch {
                        print("⚠️ Warning: Could not save Apple user to Firestore: \(error.localizedDescription)")
                    }
                }
            }
        } else {
            // Save to Firestore if possible without Firebase Auth
            Task {
                do {
                    try await saveUserToFirestore(userData)
                } catch {
                    print("⚠️ Warning: Could not save Apple user to Firestore: \(error.localizedDescription)")
                }
            }
        }
    }
    
    // MARK: - Nonce Generation for Apple Sign In
    
    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        let charset: [Character] =
            Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length
        
        while remainingLength > 0 {
            let randoms: [UInt8] = (0 ..< 16).map { _ in
                var random: UInt8 = 0
                let errorCode = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
                if errorCode != errSecSuccess {
                    fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
                }
                return random
            }
            
            randoms.forEach { random in
                if remainingLength == 0 {
                    return
                }
                
                if random < charset.count {
                    result.append(charset[Int(random)])
                    remainingLength -= 1
                }
            }
        }
        
        return result
    }
    
    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = hashSHA256(data: inputData)
        let hashString = hashedData.compactMap {
            String(format: "%02x", $0)
        }.joined()
        
        return hashString
    }
    
    private func hashSHA256(data: Data) -> Data {
        var hashData = Data(count: Int(CC_SHA256_DIGEST_LENGTH))
        
        _ = hashData.withUnsafeMutableBytes { digestBytes in
            data.withUnsafeBytes { messageBytes in
                CC_SHA256(messageBytes.baseAddress, CC_LONG(data.count), digestBytes.bindMemory(to: UInt8.self).baseAddress)
            }
        }
        return hashData
    }
    
    // MARK: - Firebase Auth Methods
    
    /// Signs in a user with email and password
    /// - Parameters:
    ///   - email: User's email
    ///   - password: User's password
    /// - Throws: Authentication errors if sign in fails
    @MainActor
    func signIn(email: String, password: String) async throws {
        print("🔄 Signing in user: \(email)")
        
        let authResult = try await auth.signIn(withEmail: email, password: password)
        let user = authResult.user
        
        self.isAuthenticated = true
        self.currentUserData = User(
            id: user.uid,
            email: user.email ?? "",
            displayName: user.displayName,
            createdAt: Date()
        )
        
        // Fetch additional user data from Firestore
        fetchUserData(userID: user.uid)
        
        print("✅ User signed in successfully")
    }
    
    /// Creates a new user account with email and password
    /// - Parameters:
    ///   - email: User's email
    ///   - password: User's password
    ///   - displayName: User's display name
    /// - Throws: Authentication errors if sign up fails
    @MainActor
    func signUp(email: String, password: String, displayName: String? = nil) async throws {
        print("🔄 Creating new user account: \(email)")
        
        let authResult = try await auth.createUser(withEmail: email, password: password)
        let user = authResult.user
        
        // Update display name if provided
        if let displayName = displayName {
            let changeRequest = user.createProfileChangeRequest()
            changeRequest.displayName = displayName
            try await changeRequest.commitChanges()
        }
        
        // Create user document in Firestore
        let userData: [String: Any] = [
            "email": email,
            "displayName": displayName ?? "",
            "createdAt": Date(),
            "lastLogin": Date()
        ]
        
        try await db.collection("users").document(user.uid).setData(userData)
        
        self.isAuthenticated = true
        self.currentUserData = User(
            id: user.uid,
            email: user.email ?? "",
            displayName: user.displayName,
            createdAt: Date()
        )
        
        print("✅ User account created successfully")
    }
    
    /// Signs out the current user
    /// - Throws: Authentication errors if sign out fails
    func signOut() throws {
        print("🔄 Signing out user")
        
        // Sign out from Firebase
        try auth.signOut()
        
        // Clear Apple Sign In data
        UserDefaults.standard.removeObject(forKey: "userData")
        
        // Update state
        self.isAuthenticated = false
        self.currentUserData = nil
        
        print("✅ User signed out successfully")
    }
    
    // MARK: - Firestore Operations
    
    /// Saves user data to Firestore
    /// - Parameter userData: The user data to save
    private func saveUserToFirestore(_ userData: User) async throws {
        print("🔄 Attempting to save user to Firestore with ID: \(userData.id)")
        
        // Check if we have a Firebase user
        if let firebaseUser = Auth.auth().currentUser {
            print("✅ Using Firebase user for Firestore operations: \(firebaseUser.uid)")
            
            // If the user IDs don't match, use the Firebase UID
            if userData.id != firebaseUser.uid {
                print("⚠️ User ID mismatch: userData.id=\(userData.id), firebaseUser.uid=\(firebaseUser.uid)")
                print("⚠️ Using Firebase UID for Firestore document ID")
            }
        } else {
            print("⚠️ No Firebase user found, using Apple ID: \(userData.id)")
        }
        
        let userDoc = db.collection("users").document(userData.id)
        
        do {
            // Check if user document already exists
            let docSnapshot = try await userDoc.getDocument()
            
            if docSnapshot.exists {
                print("✅ User document exists, updating")
                // Update existing document
                try await userDoc.updateData([
                    "lastLogin": Date(),
                    "email": userData.email,
                    "displayName": userData.displayName ?? ""
                ])
                print("✅ Successfully updated user document")
            } else {
                print("✅ User document doesn't exist, creating new one")
                // Create new document
                try await userDoc.setData([
                    "id": userData.id,
                    "email": userData.email,
                    "displayName": userData.displayName ?? "",
                    "createdAt": userData.createdAt,
                    "lastLogin": Date()
                ])
                print("✅ Successfully created user document")
            }
        } catch let error as NSError {
            print("❌ Firestore error saving user: \(error.localizedDescription)")
            print("❌ Error domain: \(error.domain), code: \(error.code)")
            
            if error.domain == FirestoreErrorDomain && 
               (error.code == 7 || error.localizedDescription.contains("Missing or insufficient permissions")) {
                print("❌ Permission error detected. Make sure Firebase security rules are updated.")
                
                // Notify about permission error
                DispatchQueue.main.async {
                    NotificationCenter.default.post(
                        name: .firestorePermissionError,
                        object: nil,
                        userInfo: ["error": error]
                    )
                }
            }
            
            throw error
        }
    }
    
    /// Fetches additional user data from Firestore
    /// - Parameter userID: The ID of the user to fetch data for
    private func fetchUserData(userID: String) {
        db.collection("users").document(userID).getDocument { [weak self] document, error in
            guard let document = document, document.exists, let data = document.data() else {
                print("❌ User document not found or error: \(error?.localizedDescription ?? "Unknown error")")
                return
            }
            
            // Update user data with Firestore data
            DispatchQueue.main.async {
                if let displayName = data["displayName"] as? String, !displayName.isEmpty {
                    self?.currentUserData?.displayName = displayName
                }
                
                if let createdAtTimestamp = data["createdAt"] as? Timestamp {
                    self?.currentUserData?.createdAt = createdAtTimestamp.dateValue()
                }
                
                // Update last login time
                self?.db.collection("users").document(userID).updateData([
                    "lastLogin": Date()
                ])
            }
        }
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
        print("❌ Apple Sign In error: \(error.localizedDescription)")
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
