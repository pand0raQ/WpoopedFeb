// here is the list of dogs image and name

import SwiftUI
import SwiftData

struct DogsListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var dogs: [Dog]
    @State private var showingDogRegistration = false
    
    var body: some View {
        List {
            ForEach(dogs) { dog in
                DogRowView(dog: dog)
            }
        }
        .navigationTitle("My Dogs")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    showingDogRegistration = true
                }) {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingDogRegistration) {
            DogRegistrationView()
        }
    }
}

struct DogRowView: View {
    let dog: Dog
    
    var body: some View {
        HStack {
            if let image = dog.image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 50, height: 50)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.blue, lineWidth: 1))
            } else {
                Image(systemName: "pawprint.circle.fill")
                    .resizable()
                    .frame(width: 50, height: 50)
                    .foregroundColor(.blue)
            }
            
            Text(dog.name)
                .font(.headline)
        }
        .padding(.vertical, 8)
    }
}

#Preview {
    DogsListView()
        .modelContainer(for: Dog.self, inMemory: true)
}

