// here is gonna be the dog detail view. dog image and name, button to generate qr code / button that reveal saved qr code 

import SwiftUI
import CloudKit

struct DogDetailView: View {
    @StateObject private var viewModel: DogDetailViewModel
    private let qrCodeSize: CGFloat = 200
    
    init(dog: Dog) {
        _viewModel = StateObject(wrappedValue: DogDetailViewModel(dog: dog))
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Dog Image Section
                dogImageView
                
                // Dog Name
                Text(viewModel.dog.name)
                    .font(.title)
                    .fontWeight(.bold)
                
                // Sharing Status
                if viewModel.dog.isShared && viewModel.dog.isShareAccepted {
                    sharingStatusView
                }
                
                // Share Button or QR Code
                if !viewModel.dog.isShared {
                    shareButton
                } else if viewModel.isShowingQRCode {
                    qrCodeView
                } else {
                    showQRButton
                }
            }
            .padding()
        }
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
    
    private var dogImageView: some View {
        Group {
            if let imageData = viewModel.dog.imageData,
               let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .shadow(radius: 5)
            } else {
                Image(systemName: "pawprint.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 200)
                    .foregroundColor(.accentColor)
            }
        }
    }
    
    private var sharingStatusView: some View {
        HStack {
            Image(systemName: "person.2.fill")
            Text("Shared")
        }
        .foregroundColor(.green)
        .padding(.vertical, 5)
    }
    
    private var shareButton: some View {
        Button(action: viewModel.shareButtonTapped) {
            HStack {
                Image(systemName: "square.and.arrow.up")
                Text("Share Dog")
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.accentColor)
            .foregroundColor(.white)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .disabled(viewModel.isSharing)
        .overlay {
            if viewModel.isSharing {
                ProgressView()
                    .tint(.white)
            }
        }
    }
    
    private var showQRButton: some View {
        Button(action: viewModel.showQRCode) {
            HStack {
                Image(systemName: "qrcode")
                Text("Show QR Code")
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.accentColor)
            .foregroundColor(.white)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }
    
    private var qrCodeView: some View {
        VStack {
            if let qrImage = viewModel.qrCodeImage {
                Image(uiImage: qrImage)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(width: qrCodeSize, height: qrCodeSize)
                    .padding()
                    .background(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .shadow(radius: 5)
                
                Button(action: viewModel.hideQRCode) {
                    Text("Hide QR Code")
                        .foregroundColor(.accentColor)
                }
                .padding(.top)
            }
        }
        .onAppear {
            viewModel.generateQRCode()
        }
    }
} 