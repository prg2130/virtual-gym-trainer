import AVFoundation
import UIKit

protocol CameraViewControllerDelegate: AnyObject {
    func didDetectPose(_ feedback: [FormFeedback])
    func didFailPoseDetection()
}

class CameraViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {
    var captureSession: AVCaptureSession?
    var previewLayer: AVCaptureVideoPreviewLayer?
    weak var delegate: CameraViewControllerDelegate?
    var lastProcessingTime: Date = Date()

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

            // Add video output for frame processing
            let videoOutput = AVCaptureVideoDataOutput()
            videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "poseDetectionQueue"))
            if session.canAddOutput(videoOutput) {
                session.addOutput(videoOutput)
                print("✅ Video output added")
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

    // Process each video frame
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        // Process only every 3rd frame to reduce CPU load
        let now = Date()
        if now.timeIntervalSince(lastProcessingTime) < 0.1 {
            return
        }
        lastProcessingTime = now

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        // Detect pose
        PoseDetectionManager.shared.detectPose(from: pixelBuffer) { [weak self] joints in
            guard let joints = joints else {
                self?.delegate?.didFailPoseDetection()
                return
            }

            // Analyze push-up form
            let feedback = PoseDetectionManager.shared.analyzePushUpForm(joints: joints)
            DispatchQueue.main.async {
                self?.delegate?.didDetectPose(feedback)
            }
        }
    }
}
