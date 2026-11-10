import AVFoundation
import UIKit

class CameraViewController: UIViewController {
    var captureSession: AVCaptureSession?
    var previewLayer: AVCaptureVideoPreviewLayer?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupCamera()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    func setupCamera() {
        let session = AVCaptureSession()
        session.sessionPreset = .high

        // Get front camera
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) else {
            print("❌ No front camera found")
            return
        }

        do {
            let input = try AVCaptureDeviceInput(device: device)

            // Check if input can be added
            if session.canAddInput(input) {
                session.addInput(input)
                print("✅ Camera input added")
            }

            // Create preview layer
            let preview = AVCaptureVideoPreviewLayer(session: session)
            preview.videoGravity = .resizeAspectFill
            preview.frame = view.bounds
            view.layer.addSublayer(preview)

            print("✅ Preview layer added")

            self.previewLayer = preview
            self.captureSession = session

            // Start session
            DispatchQueue.global(qos: .userInitiated).async {
                session.startRunning()
                print("✅ Camera session started")
            }

        } catch {
            print("❌ Camera setup error: \(error.localizedDescription)")
        }
    }
}
