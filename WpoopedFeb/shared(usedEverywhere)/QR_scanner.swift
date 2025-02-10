// qr scanner view

import AVFoundation
import UIKit

/// Protocol for handling QR code scanning events
protocol QRCodeScannerDelegate: AnyObject {
    func didFind(code: String)
    func didFail(with error: Error)
}

/// A reusable QR code scanner view controller
class QRScannerVC: UIViewController {
    // MARK: - Properties
    weak var delegate: QRCodeScannerDelegate?
    private var captureSession: AVCaptureSession?
    private let previewLayer = AVCaptureVideoPreviewLayer()
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupCaptureSession()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer.frame = view.bounds
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        startScanning()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopScanning()
    }
    
    // MARK: - Setup
    private func setupCaptureSession() {
        let captureSession = AVCaptureSession()
        
        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video) else {
            delegate?.didFail(with: QRScannerError.noCameraAvailable)
            return
        }
        
        let videoInput: AVCaptureDeviceInput
        
        do {
            videoInput = try AVCaptureDeviceInput(device: videoCaptureDevice)
        } catch {
            delegate?.didFail(with: error)
            return
        }
        
        if captureSession.canAddInput(videoInput) {
            captureSession.addInput(videoInput)
        } else {
            delegate?.didFail(with: QRScannerError.invalidInput)
            return
        }
        
        let metadataOutput = AVCaptureMetadataOutput()
        
        if captureSession.canAddOutput(metadataOutput) {
            captureSession.addOutput(metadataOutput)
            metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            metadataOutput.metadataObjectTypes = [.qr]
        } else {
            delegate?.didFail(with: QRScannerError.invalidOutput)
            return
        }
        
        previewLayer.session = captureSession
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
        
        self.captureSession = captureSession
    }
    
    // MARK: - Public Methods
    func startScanning() {
        if let captureSession = captureSession, !captureSession.isRunning {
            DispatchQueue.global(qos: .userInitiated).async {
                captureSession.startRunning()
            }
        }
    }
    
    func stopScanning() {
        if let captureSession = captureSession, captureSession.isRunning {
            captureSession.stopRunning()
        }
    }
}

// MARK: - AVCaptureMetadataOutputObjectsDelegate
extension QRScannerVC: AVCaptureMetadataOutputObjectsDelegate {
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        guard let metadataObject = metadataObjects.first,
              let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject,
              let stringValue = readableObject.stringValue else { return }
        
        delegate?.didFind(code: stringValue)
    }
}

// MARK: - QRScannerError
enum QRScannerError: LocalizedError {
    case noCameraAvailable
    case invalidInput
    case invalidOutput
    
    var errorDescription: String? {
        switch self {
        case .noCameraAvailable:
            return "No camera is available on this device"
        case .invalidInput:
            return "Could not setup camera input"
        case .invalidOutput:
            return "Could not setup camera output"
        }
    }
}
