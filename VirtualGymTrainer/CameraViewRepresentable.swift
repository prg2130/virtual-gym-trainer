import SwiftUI

struct CameraViewRepresentable: UIViewControllerRepresentable {
    var onPoseDetected: ([FormFeedback]) -> Void
    var onPoseFailed: () -> Void

    func makeUIViewController(context: Context) -> CameraViewController {
        let controller = CameraViewController()
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: CameraViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onPoseDetected: onPoseDetected, onPoseFailed: onPoseFailed)
    }

    class Coordinator: NSObject, CameraViewControllerDelegate {
        let onPoseDetected: ([FormFeedback]) -> Void
        let onPoseFailed: () -> Void

        init(onPoseDetected: @escaping ([FormFeedback]) -> Void, onPoseFailed: @escaping () -> Void) {
            self.onPoseDetected = onPoseDetected
            self.onPoseFailed = onPoseFailed
        }

        func didDetectPose(_ feedback: [FormFeedback]) {
            onPoseDetected(feedback)
        }

        func didFailPoseDetection() {
            onPoseFailed()
        }
    }
}
