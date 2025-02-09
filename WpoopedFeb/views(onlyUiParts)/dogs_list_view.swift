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
                NavigationLink(destination: DogDetailView(dog: dog)) {
                    DogRowView(dog: dog)
                }
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
            
            VStack(alignment: .leading) {
                Text(dog.name)
                    .font(.headline)
                
                if dog.isShared {
                    HStack {
                        Image(systemName: "person.2.fill")
                        Text("Shared")
                            .font(.caption)
                    }
                    .foregroundColor(.green)
                }
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(.gray)
                .font(.caption)
        }
        .padding(.vertical, 8)
    }
}

#Preview {
    NavigationView {
        DogsListView()
            .modelContainer(for: Dog.self, inMemory: true)
    }
}

