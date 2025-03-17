import SwiftUI
import FirebaseAuth
import AuthenticationServices

struct MainWelcomeView: View {
    @StateObject private var authManager = AuthManager.shared
    @State private var email = ""
    @State private var password = ""
    @State private var isSignUp = false
    @State private var displayName = ""
    @State private var errorMessage: String?
    @State private var isLoading = false
    @State private var showingEmailSignIn = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Logo and welcome text
                Image(systemName: "pawprint.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 80, height: 80)
                    .foregroundColor(.blue)
                    .padding(.top, 50)
                
                Text("Welcome to Wpooped")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Track your dog's walks and more")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.bottom, 30)
                
                // Sign in with Apple button
                SignInWithAppleButton(
                    .signIn,
                    onRequest: { _ in
                        // Clear any previous errors
                        errorMessage = nil
                    },
                    onCompletion: { result in
                        switch result {
                        case .success(let authorization):
                            // Handle the authorization result
                            if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
                                // Pass the credential to AuthManager
                                authManager.handleAppleSignIn(appleIDCredential)
                                
                                // Debug auth state
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                                    AuthDebugger.shared.debugAuthState()
                                }
                            }
                            print("Apple Sign In successful")
                        case .failure(let error):
                            errorMessage = error.localizedDescription
                        }
                    }
                )
                .frame(height: 50)
                .padding(.horizontal)
                
                // Divider with "or" text
                HStack {
                    VStack { Divider() }
                    Text("or")
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                    VStack { Divider() }
                }
                .padding(.horizontal)
                .padding(.vertical, 10)
                
                // Email sign in button
                Button(action: {
                    showingEmailSignIn.toggle()
                }) {
                    Text("Sign in with Email")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue.opacity(0.1))
                        .foregroundColor(.blue)
                        .cornerRadius(8)
                }
                .padding(.horizontal)
                
                // Email sign in form (shown conditionally)
                if showingEmailSignIn {
                    VStack(spacing: 15) {
                        TextField("Email", text: $email)
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                        
                        SecureField("Password", text: $password)
                            .textContentType(isSignUp ? .newPassword : .password)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                        
                        if isSignUp {
                            TextField("Display Name", text: $displayName)
                                .textContentType(.name)
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                        }
                    }
                    .padding(.horizontal)
                }
                
                // Error message
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.footnote)
                        .padding(.horizontal)
                }
                
                // Email sign in/up button (only shown when email form is visible)
                if showingEmailSignIn {
                    Button(action: {
                        Task {
                            await handleAuthentication()
                        }
                    }) {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        } else {
                            Text(isSignUp ? "Sign Up" : "Sign In")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                    }
                    .disabled(isLoading || !isValidInput())
                    .padding(.horizontal)
                    
                    // Toggle between sign in and sign up
                    Button(action: {
                        isSignUp.toggle()
                        errorMessage = nil
                    }) {
                        Text(isSignUp ? "Already have an account? Sign In" : "Don't have an account? Sign Up")
                            .foregroundColor(.blue)
                    }
                }
                
                // Continue as guest option
                Button(action: {
                    // Handle guest login
                    authManager.isAuthenticated = true
                }) {
                    Text("Continue as Guest")
                        .foregroundColor(.secondary)
                }
                .padding(.top, 20)
                
                // Debug button (only visible in debug builds)
                #if DEBUG
                Button(action: {
                    // Force update auth state
                    AuthDebugger.shared.debugAuthState()
                }) {
                    Text("Debug Auth")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .padding(.top, 10)
                #endif
                
                Spacer()
            }
            .padding()
            .navigationBarHidden(true)
        }
    }
    
    private func isValidInput() -> Bool {
        let emailIsValid = !email.isEmpty && email.contains("@")
        let passwordIsValid = password.count >= 6
        
        if isSignUp {
            return emailIsValid && passwordIsValid && !displayName.isEmpty
        } else {
            return emailIsValid && passwordIsValid
        }
    }
    
    private func handleAuthentication() async {
        errorMessage = nil
        isLoading = true
        
        do {
            if isSignUp {
                try await authManager.signUp(email: email, password: password, displayName: displayName)
            } else {
                try await authManager.signIn(email: email, password: password)
            }
        } catch {
            errorMessage = handleAuthError(error)
        }
        
        isLoading = false
    }
    
    private func handleAuthError(_ error: Error) -> String {
        if let authError = error as? AuthErrorCode {
            switch authError.code {
            case .invalidEmail:
                return "Invalid email format"
            case .wrongPassword:
                return "Incorrect password"
            case .userNotFound:
                return "No account found with this email"
            case .emailAlreadyInUse:
                return "This email is already in use"
            case .weakPassword:
                return "Password is too weak"
            case .networkError:
                return "Network error. Please try again"
            default:
                return "Authentication failed: \(authError.localizedDescription)"
            }
        }
        return "Authentication failed: \(error.localizedDescription)"
    }
}

#Preview {
    MainWelcomeView()
}
