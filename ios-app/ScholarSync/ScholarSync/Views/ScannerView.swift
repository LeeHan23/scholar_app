import SwiftUI
import Vision
import AVFoundation

struct ScannerView: UIViewControllerRepresentable {
    @Binding var scannedCode: String?

    class Coordinator: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
        var parent: ScannerView
        private var hasScanned = false
        /// When true, actively process frames for scanning.
        var isScanning = false
        /// Latest pixel buffer for on-demand capture.
        var latestBuffer: CVPixelBuffer?

        init(parent: ScannerView) {
            self.parent = parent
        }

        func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
            guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

            // Always store the latest frame for manual capture
            latestBuffer = pixelBuffer

            // Only process when actively scanning (manual trigger or continuous mode)
            guard isScanning, !hasScanned else { return }

            processBuffer(pixelBuffer)
        }

        func processBuffer(_ pixelBuffer: CVPixelBuffer) {
            guard !hasScanned else { return }

            // Vision Text Request for DOIs
            let textRequest = VNRecognizeTextRequest { [weak self] request, error in
                guard let self = self, !self.hasScanned else { return }
                guard let observations = request.results as? [VNRecognizedTextObservation] else { return }
                for observation in observations {
                    guard let topCandidate = observation.topCandidates(1).first else { continue }
                    let text = topCandidate.string
                    if text.contains("10.") && text.contains("/") {
                        self.reportCode(text)
                        return
                    } else if text.lowercased().contains("arxiv:") {
                        self.reportCode(text)
                        return
                    }
                }
            }
            textRequest.recognitionLevel = .accurate

            // Vision Barcode Request — filter to EAN-13 / EAN-8 (ISBN barcodes)
            let barcodeRequest = VNDetectBarcodesRequest { [weak self] request, error in
                guard let self = self, !self.hasScanned else { return }
                guard let observations = request.results as? [VNBarcodeObservation] else { return }
                for observation in observations {
                    // Accept EAN-13 (ISBN-13) and EAN-8 barcodes
                    let symbology = observation.symbology
                    guard symbology == .ean13 || symbology == .ean8 else { continue }
                    if let payload = observation.payloadStringValue, !payload.isEmpty {
                        self.reportCode(payload)
                        return
                    }
                }
            }

            let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
            do {
                try handler.perform([textRequest, barcodeRequest])
            } catch {
                print("Vision error: \(error)")
            }
        }

        /// Manually scan the latest captured frame.
        func manualCapture() {
            guard let buffer = latestBuffer else { return }
            hasScanned = false
            processBuffer(buffer)
        }

        private func reportCode(_ code: String) {
            guard !hasScanned else { return }
            hasScanned = true
            isScanning = false
            DispatchQueue.main.async {
                HapticManager.shared.scanSuccess()
                self.parent.scannedCode = code
            }
        }

        func reset() {
            hasScanned = false
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIViewController(context: Context) -> ScannerViewController {
        let vc = ScannerViewController()
        vc.coordinator = context.coordinator
        return vc
    }

    func updateUIViewController(_ uiViewController: ScannerViewController, context: Context) {}
}

// MARK: - Scanner View Controller with overlay UI

class ScannerViewController: UIViewController {
    var coordinator: ScannerView.Coordinator?
    private var captureSession: AVCaptureSession?
    private var previewLayer: AVCaptureVideoPreviewLayer?

    override func viewDidLoad() {
        super.viewDidLoad()
        setupCamera()
        setupOverlay()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.layer.bounds
    }

    private func setupCamera() {
        let session = AVCaptureSession()
        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device) else { return }

        if session.canAddInput(input) {
            session.addInput(input)
        }

        // Enable auto-focus for close-range barcodes
        if device.isFocusModeSupported(.continuousAutoFocus) {
            try? device.lockForConfiguration()
            device.focusMode = .continuousAutoFocus
            device.unlockForConfiguration()
        }

        let output = AVCaptureVideoDataOutput()
        output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        if session.canAddOutput(output) {
            session.addOutput(output)
            output.setSampleBufferDelegate(coordinator, queue: DispatchQueue(label: "videoQueue"))
        }

        let preview = AVCaptureVideoPreviewLayer(session: session)
        preview.videoGravity = .resizeAspectFill
        preview.frame = view.layer.bounds
        view.layer.addSublayer(preview)

        self.captureSession = session
        self.previewLayer = preview

        DispatchQueue.global(qos: .userInitiated).async {
            session.startRunning()
        }
    }

    private func setupOverlay() {
        // Semi-transparent guide frame
        let guideFrame = UIView()
        guideFrame.translatesAutoresizingMaskIntoConstraints = false
        guideFrame.layer.borderColor = UIColor.white.cgColor
        guideFrame.layer.borderWidth = 2
        guideFrame.layer.cornerRadius = 12
        guideFrame.backgroundColor = UIColor.clear
        view.addSubview(guideFrame)

        // Instruction label
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "Point at a barcode, DOI, or arXiv ID"
        label.textColor = .white
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.textAlignment = .center
        label.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        label.layer.cornerRadius = 8
        label.clipsToBounds = true
        view.addSubview(label)

        // Scan button
        let scanButton = UIButton(type: .system)
        scanButton.translatesAutoresizingMaskIntoConstraints = false
        scanButton.setTitle("  Scan Now  ", for: .normal)
        scanButton.setImage(UIImage(systemName: "viewfinder"), for: .normal)
        scanButton.titleLabel?.font = .systemFont(ofSize: 18, weight: .semibold)
        scanButton.tintColor = .white
        scanButton.backgroundColor = UIColor.systemBlue
        scanButton.layer.cornerRadius = 25
        scanButton.addTarget(self, action: #selector(scanTapped), for: .touchUpInside)
        view.addSubview(scanButton)

        NSLayoutConstraint.activate([
            guideFrame.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            guideFrame.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -40),
            guideFrame.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.8),
            guideFrame.heightAnchor.constraint(equalToConstant: 160),

            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.topAnchor.constraint(equalTo: guideFrame.bottomAnchor, constant: 16),

            scanButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            scanButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -24),
            scanButton.heightAnchor.constraint(equalToConstant: 50),
            scanButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 160),
        ])
    }

    @objc private func scanTapped() {
        coordinator?.manualCapture()
    }
}
