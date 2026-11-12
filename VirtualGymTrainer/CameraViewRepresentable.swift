import SwiftUI
import AVFoundation

struct CameraViewRepresentable: UIViewControllerRepresentable {
    var cameraPosition: AVCaptureDevice.Position = .front
    var onPoseDetected: ([FormFeedback], Int) -> Void
    var onPoseFailed: () -> Void

    func makeUIViewController(context: Context) -> CameraViewController {
        let controller = CameraViewController()
        controller.setCameraPosition(cameraPosition)
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: CameraViewController, context: Context) {
        uiViewController.setCameraPosition(cameraPosition)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onPoseDetected: onPoseDetected, onPoseFailed: onPoseFailed)
    }

    class Coordinator: NSObject, CameraViewControllerDelegate {
        let onPoseDetected: ([FormFeedback], Int) -> Void
        let onPoseFailed: () -> Void

        init(onPoseDetected: @escaping ([FormFeedback], Int) -> Void, onPoseFailed: @escaping () -> Void) {
            self.onPoseDetected = onPoseDetected
            self.onPoseFailed = onPoseFailed
        }

        func didDetectPose(_ feedback: [FormFeedback], repCount: Int) {
            onPoseDetected(feedback, repCount)
        }

        func didFailPoseDetection() {
            onPoseFailed()
        }
    }
}
