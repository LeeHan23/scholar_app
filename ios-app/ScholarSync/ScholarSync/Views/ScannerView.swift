import SwiftUI
import Vision
import AVFoundation

struct ScannerView: UIViewControllerRepresentable {
    @Binding var scannedCode: String?
    
    class Coordinator: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
        var parent: ScannerView
        
        init(parent: ScannerView) {
            self.parent = parent
        }
        
        func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
            guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
            
            // Vision Text Request for DOIs
            let textRequest = VNRecognizeTextRequest { request, error in
                guard let observations = request.results as? [VNRecognizedTextObservation] else { return }
                for observation in observations {
                    guard let topCandidate = observation.topCandidates(1).first else { continue }
                    let text = topCandidate.string
                    // Very simple regex for DOI (e.g., 10.xxxx/xxxxx)
                    if text.contains("10.") && text.contains("/") {
                        DispatchQueue.main.async {
                            HapticManager.shared.scanSuccess()
                            self.parent.scannedCode = text
                        }
                    } else if text.contains("arxiv:") {
                        DispatchQueue.main.async {
                            HapticManager.shared.scanSuccess()
                            self.parent.scannedCode = text
                        }
                    }
                }
            }
            textRequest.recognitionLevel = .accurate
            
            // Vision Barcode Request for ISBNs
            let barcodeRequest = VNDetectBarcodesRequest { request, error in
                guard let observations = request.results as? [VNBarcodeObservation] else { return }
                for observation in observations {
                    if let payload = observation.payloadStringValue {
                        DispatchQueue.main.async {
                            HapticManager.shared.scanSuccess()
                            self.parent.scannedCode = payload
                        }
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
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }
    
    func makeUIViewController(context: Context) -> UIViewController {
        let viewController = UIViewController()
        let captureSession = AVCaptureSession()
        
        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video),
              let videoInput = try? AVCaptureDeviceInput(device: videoCaptureDevice) else {
            return viewController
        }
        
        if captureSession.canAddInput(videoInput) {
            captureSession.addInput(videoInput)
        }
        
        let videoOutput = AVCaptureVideoDataOutput()
        if captureSession.canAddOutput(videoOutput) {
            captureSession.addOutput(videoOutput)
            videoOutput.setSampleBufferDelegate(context.coordinator, queue: DispatchQueue(label: "videoQueue"))
        }
        
        let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.frame = viewController.view.layer.bounds
        previewLayer.videoGravity = .resizeAspectFill
        viewController.view.layer.addSublayer(previewLayer)
        
        captureSession.startRunning()
        return viewController
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
}
