// data needed for showiing user info on profile view user defaults + data for signing out (user defaults cleaning)

import SwiftUI
import SwiftData

struct ProfileView: View {
    @StateObject var viewModel: ProfileViewModel
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        List {
            // User Profile Section
            Section("Profile Information") {
                if let user = viewModel.userDetails {
                    LabeledContent("Name", value: user.name)
                    LabeledContent("Email", value: user.email)
                    LabeledContent("Member Since", value: user.formattedSignUpDate)
                }
            }
            
            // Actions Section
            Section("Actions") {
                Button(role: .destructive, action: {
                    Task {
                        await viewModel.deleteAllUserData()
                    }
                }) {
                    Label("Delete All Data", systemImage: "trash")
                }
                
                Button(role: .destructive, action: viewModel.signOut) {
                    Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                }
            }
        }
        .navigationTitle("Profile")
        .refreshable {
            await viewModel.fetchUserData()
        }
        .alert(item: $viewModel.alertItem) { alertItem in
            Alert(
                title: Text(alertItem.title),
                message: Text(alertItem.message)
            )
        }
    }
}

#Preview {
    NavigationStack {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: Dog.self, configurations: config)
        ProfileView(viewModel: ProfileViewModel(modelContext: container.mainContext))
    }
}
