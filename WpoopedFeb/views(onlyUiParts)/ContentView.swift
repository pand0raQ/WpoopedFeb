import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var authManager = AuthManager.shared
    
    var body: some View {
        TabView {
            NavigationStack {
                Text("Home")
                    .navigationTitle("Home")
            }
            .tabItem {
                Label("Home", systemImage: "house.fill")
            }
            
            NavigationStack {
                DogsListView(modelContext: modelContext)
            }
            .tabItem {
                Label("Dogs", systemImage: "pawprint.fill")
            }
            
            NavigationStack {
                ProfileView(viewModel: ProfileViewModel(modelContext: modelContext))
            }
            .tabItem {
                Label("Profile", systemImage: "person.fill")
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Dog.self)
} 