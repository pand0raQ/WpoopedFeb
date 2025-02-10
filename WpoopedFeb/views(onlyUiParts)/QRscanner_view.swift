import SwiftUI
import AVFoundation

struct QRScannerView: View {
    @StateObject var viewModel: QRCodeScannerViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            QRScannerViewRepresentable(viewModel: viewModel)
            
            VStack {
                Spacer()
                
                if let error = viewModel.error {
                    Text(error.localizedDescription)
                        .foregroundColor(.red)
                        .padding()
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(10)
                }
                
                if let url = viewModel.extractedURL {
                    VStack(spacing: 10) {
                        Text("QR Code Scanned!")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        Text(url.absoluteString)
                            .font(.subheadline)
                            .foregroundColor(.white)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    .padding()
                    .background(Color.black.opacity(0.7))
                    .cornerRadius(10)
                    .transition(.move(edge: .bottom))
                }
                
                Button(action: {
                    if viewModel.extractedURL != nil {
                        viewModel.resetScanner()
                    } else {
                        dismiss()
                    }
                }) {
                    Text(viewModel.extractedURL != nil ? "Scan Again" : "Cancel")
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(10)
                }
                .padding(.bottom)
            }
        }
        .edgesIgnoringSafeArea(.all)
    }
}

struct QRScannerViewRepresentable: UIViewControllerRepresentable {
    @ObservedObject var viewModel: QRCodeScannerViewModel
    
    func makeUIViewController(context: Context) -> QRScannerVC {
        let controller = QRScannerVC()
        controller.delegate = viewModel
        return controller
    }
    
    func updateUIViewController(_ uiViewController: QRScannerVC, context: Context) {
        if viewModel.isScanning {
            uiViewController.startScanning()
        } else {
            uiViewController.stopScanning()
        }
    }
}
