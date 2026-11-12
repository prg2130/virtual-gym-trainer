import AVFoundation
import UIKit

protocol CameraViewControllerDelegate: AnyObject {
    func didDetectPose(_ feedback: [FormFeedback], repCount: Int)
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
        PoseDetectionManager.shared.resetSession()
        setupCamera()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    /// Which camera is in use. Change it with `setCameraPosition(_:)`.
    private(set) var cameraPosition: AVCaptureDevice.Position = .front
    private let sessionQueue = DispatchQueue(label: "cameraSessionQueue")

    private func makeInput(for position: AVCaptureDevice.Position) -> AVCaptureDeviceInput? {
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position) else {
            print("❌ No \(position == .front ? "front" : "back") camera found")
            return nil
        }
        do {
            return try AVCaptureDeviceInput(device: device)
        } catch {
            print("❌ Camera setup error: \(error.localizedDescription)")
            return nil
        }
    }

    func setupCamera() {
        let session = AVCaptureSession()
        session.sessionPreset = .high

        guard let input = makeInput(for: cameraPosition) else { return }

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

        self.previewLayer = preview
        self.captureSession = session

        sessionQueue.async {
            session.startRunning()
            print("✅ Camera session started")
        }
    }

    /// Switches between the front and back camera while the session keeps running.
    func setCameraPosition(_ position: AVCaptureDevice.Position) {
        guard position != cameraPosition else { return }
        cameraPosition = position

        guard let session = captureSession else {
            // Camera was never set up (e.g. the first attempt failed); try again.
            setupCamera()
            return
        }

        sessionQueue.async { [weak self] in
            guard let self, let newInput = self.makeInput(for: position) else { return }
            session.beginConfiguration()
            let oldInputs = session.inputs
            oldInputs.forEach { session.removeInput($0) }
            if session.canAddInput(newInput) {
                session.addInput(newInput)
            } else {
                // Couldn't switch: put the previous camera back.
                oldInputs.forEach { if session.canAddInput($0) { session.addInput($0) } }
            }
            session.commitConfiguration()
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

        // The front camera's frames are mirrored; the back camera's are not.
        let orientation: CGImagePropertyOrientation = cameraPosition == .front ? .leftMirrored : .right

        // Detect pose
        PoseDetectionManager.shared.detectPose(from: pixelBuffer, orientation: orientation) { [weak self] joints in
            guard let joints = joints else {
                self?.delegate?.didFailPoseDetection()
                return
            }

            // Analyze push-up form
            let feedback = PoseDetectionManager.shared.analyzePushUpForm(joints: joints)
            let repCount = PoseDetectionManager.shared.repCount
            DispatchQueue.main.async {
                self?.delegate?.didDetectPose(feedback, repCount: repCount)
            }
        }
    }
}
