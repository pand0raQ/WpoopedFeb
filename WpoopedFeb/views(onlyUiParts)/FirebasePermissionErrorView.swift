import SwiftUI

struct FirebasePermissionErrorView: ViewModifier {
    @State private var showingPermissionAlert = false
    @State private var errorMessage = ""
    
    func body(content: Content) -> some View {
        content
            .onReceive(NotificationCenter.default.publisher(for: .firestorePermissionError)) { notification in
                if let error = notification.userInfo?["error"] as? Error {
                    errorMessage = error.localizedDescription
                } else {
                    errorMessage = "Missing or insufficient permissions to access Firestore."
                }
                showingPermissionAlert = true
            }
            .alert("Firebase Permission Error", isPresented: $showingPermissionAlert) {
                Button("View Instructions") {
                    // Open the helper script
                    #if os(macOS)
                    NSWorkspace.shared.openFile("update_firebase_rules.sh")
                    #else
                    if let url = URL(string: "https://console.firebase.google.com/") {
                        UIApplication.shared.open(url)
                    }
                    #endif
                }
                Button("OK", role: .cancel) {}
            } message: {
                Text("Your app doesn't have permission to access Firestore. This is likely because the Firebase security rules need to be updated.\n\nError: \(errorMessage)\n\nPlease run the update_firebase_rules.sh script for instructions.")
            }
    }
}

extension View {
    func withFirebasePermissionErrorHandling() -> some View {
        self.modifier(FirebasePermissionErrorView())
    }
} 