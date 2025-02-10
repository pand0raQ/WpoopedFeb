// here is gonna be the dog detail view. dog image and name, button to generate qr code / button that reveal saved qr code 

import SwiftUI
import CloudKit

struct DogDetailView: View {
    @StateObject private var viewModel: DogDetailViewModel
    private let iconSize: CGFloat = 30
    
    init(dog: Dog) {
        _viewModel = StateObject(wrappedValue: DogDetailViewModel(dog: dog))
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                DogDetailHeaderView(
                    dog: viewModel.dog,
                    showingQRCode: $viewModel.isShowingQRCode,
                    qrCodeImage: viewModel.qrCodeImage,
                    iconSize: iconSize,
                    onShare: viewModel.shareButtonTapped
                )
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .background(Color(.systemGroupedBackground))
        .alert(
            "Sharing Error",
            isPresented: $viewModel.showingError,
            presenting: viewModel.shareError,
            actions: { error in
                Button("OK", role: .cancel) {}
            },
            message: { error in
                Text(error.localizedDescription)
            }
        )
    }
}

private struct DogDetailHeaderView: View {
    let dog: Dog
    @Binding var showingQRCode: Bool
    let qrCodeImage: UIImage?
    let iconSize: CGFloat
    let onShare: () async -> Void
    
    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 16) {
                if let imageData = dog.imageData, let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 100, height: 100)
                        .clipShape(Circle())
                        .shadow(radius: 2)
                } else {
                    Image(systemName: "pawprint.circle.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 100, height: 100)
                        .foregroundColor(.accentColor)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text(dog.name ?? "Unknown Dog")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    if dog.isShared ?? false {
                        Label("Shared", systemImage: "person.2.fill")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                if !(dog.isShared ?? false) {
                    Button(action: {
                        Task {
                            await onShare()
                        }
                    }) {
                        Image(systemName: "qrcode")
                            .font(.system(size: iconSize))
                            .foregroundColor(.accentColor)
                    }
                } else if let qrImage = qrCodeImage {
                    Image(uiImage: qrImage)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(width: iconSize * 2, height: iconSize * 2)
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(radius: 1)
        }
    }
} 
