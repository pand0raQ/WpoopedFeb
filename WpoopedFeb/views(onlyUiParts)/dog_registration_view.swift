import SwiftUI
import PhotosUI
import SwiftData

struct DogRegistrationView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var dogName = ""
    @State private var selectedImage: UIImage?
    @State private var croppedImage: UIImage?
    @State private var showingImagePicker = false
    @State private var showingImageEditor = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        Form {
            Section(header: Text("Dog Information")) {
                TextField("Dog Name", text: $dogName)
                
                if let image = croppedImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(height: 200)
                }
                
                Button(action: {
                    showingImagePicker = true
                }) {
                    Text("Select Image")
                }
            }
            
            Section {
                Button(action: saveDog) {
                    Text("Register Dog")
                        .frame(maxWidth: .infinity)
                        .padding()
                }
                .disabled(dogName.isEmpty)
                .buttonStyle(.borderedProminent)
            }
        }
        .navigationTitle("Register Dog")
        .navigationBarItems(leading: Button("Cancel") {
            dismiss()
        })
        .sheet(isPresented: $showingImagePicker) {
            ImagePicker(image: $selectedImage)
        }
        .onChange(of: selectedImage) {
            if selectedImage != nil {
                showingImageEditor = true
            }
        }
        .sheet(isPresented: $showingImageEditor) {
            if let selectedImage {
                ImageCropperView(image: selectedImage) { croppedImage in
                    self.croppedImage = croppedImage
                    showingImageEditor = false
                }
            }
        }
        .alert("Registration", isPresented: $showingAlert) {
            Button("OK") {
                if alertMessage == "Dog registered successfully!" {
                    dismiss()
                }
            }
        } message: {
            Text(alertMessage)
        }
    }
    
    private func saveDog() {
        do {
            let dog = Dog(name: dogName)
            
            // Save image data if available
            if let image = croppedImage {
                dog.imageData = image.jpegData(compressionQuality: 0.7)
            }
            
            modelContext.insert(dog)
            try modelContext.save()
            alertMessage = "Dog registered successfully!"
            showingAlert = true
        } catch {
            alertMessage = "Error saving dog: \(error.localizedDescription)"
            showingAlert = true
        }
    }
}

struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    
    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .images
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            
            guard let provider = results.first?.itemProvider else { return }
            
            if provider.canLoadObject(ofClass: UIImage.self) {
                provider.loadObject(ofClass: UIImage.self) { image, _ in
                    DispatchQueue.main.async {
                        self.parent.image = image as? UIImage
                    }
                }
            }
        }
    }
}

struct ImageCropperView: View {
    let image: UIImage
    let onCropped: (UIImage) -> Void
    
    @State private var scale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height) * 0.9
            
            VStack {
                Spacer()
                
                ZStack {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(width: size, height: size)
                        .scaleEffect(scale)
                        .offset(offset)
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    offset = value.translation
                                }
                                .onEnded { _ in
                                    withAnimation {
                                        offset = limitOffset(offset, in: geometry.size)
                                    }
                                }
                        )
                        .gesture(
                            MagnificationGesture()
                                .onChanged { value in
                                    scale = value
                                }
                                .onEnded { _ in
                                    withAnimation {
                                        scale = min(max(scale, 1), 3)
                                    }
                                }
                        )
                        .clipShape(Circle())
                    
                    Circle()
                        .strokeBorder(Color.white, lineWidth: 2)
                        .frame(width: size, height: size)
                }
                
                Spacer()
                
                HStack {
                    Button("Cancel") {
                        dismiss()
                    }
                    .padding()
                    .background(Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    
                    Spacer()
                    
                    Button("Crop") {
                        let renderer = ImageRenderer(content:
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .scaleEffect(scale)
                                .offset(offset)
                                .frame(width: size, height: size)
                                .clipShape(Circle())
                        )
                        renderer.proposedSize = ProposedViewSize(width: size, height: size)
                        if let uiImage = renderer.uiImage {
                            onCropped(uiImage)
                        }
                        dismiss()
                    }
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .padding()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black.edgesIgnoringSafeArea(.all))
        }
    }
    
    private func limitOffset(_ offset: CGSize, in size: CGSize) -> CGSize {
        let maxOffset = (size.width / 2) * (scale - 1)
        return CGSize(
            width: min(max(offset.width, -maxOffset), maxOffset),
            height: min(max(offset.height, -maxOffset), maxOffset)
        )
    }
}
