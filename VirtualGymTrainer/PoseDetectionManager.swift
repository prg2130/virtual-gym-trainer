import Vision

class PoseDetectionManager {
    static let shared = PoseDetectionManager()

    func detectPose(from pixelBuffer: CVPixelBuffer, completion: @escaping ([VNHumanBodyPoseObservation.JointName: VNRecognizedPoint]?) -> Void) {
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .right)
        let request = VNDetectHumanBodyPoseRequest()

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try handler.perform([request])

                if let observations = request.results as? [VNHumanBodyPoseObservation],
                   let observation = observations.first {
                    let joints = try observation.recognizedPoints(.all)
                    DispatchQueue.main.async {
                        completion(joints)
                    }
                } else {
                    DispatchQueue.main.async {
                        completion(nil)
                    }
                }
            } catch {
                print("❌ Pose detection error: \(error)")
                DispatchQueue.main.async {
                    completion(nil)
                }
            }
        }
    }

    // Analyze push-up form
    func analyzePushUpForm(joints: [VNHumanBodyPoseObservation.JointName: VNRecognizedPoint]) -> [FormFeedback] {
        var feedback: [FormFeedback] = []

        // Check shoulders alignment
        if let leftShoulder = joints[.leftShoulder],
           let rightShoulder = joints[.rightShoulder] {
            let shoulderDiff = abs(leftShoulder.location.y - rightShoulder.location.y)
            if shoulderDiff < 0.1 {
                feedback.append(FormFeedback(message: "✓ Shoulders aligned", isGood: true))
            } else {
                feedback.append(FormFeedback(message: "⚠️ Level your shoulders", isGood: false))
            }
        }

        // Check body straight (hip to shoulder alignment)
        if let leftShoulder = joints[.leftShoulder],
           let leftHip = joints[.leftHip] {
            let bodyAngle = abs(leftShoulder.location.x - leftHip.location.x)
            if bodyAngle < 0.15 {
                feedback.append(FormFeedback(message: "✓ Body is straight", isGood: true))
            } else {
                feedback.append(FormFeedback(message: "⚠️ Keep body straight", isGood: false))
            }
        }

        // Check elbow depth
        if let leftWrist = joints[.leftWrist],
           let leftElbow = joints[.leftElbow],
           let leftShoulder = joints[.leftShoulder] {
            let elbowBend = leftElbow.location.y - leftWrist.location.y
            if elbowBend > 0.15 {
                feedback.append(FormFeedback(message: "✓ Good depth", isGood: true))
            } else {
                feedback.append(FormFeedback(message: "⚠️ Go deeper", isGood: false))
            }
        }

        return feedback
    }
}

struct FormFeedback: Identifiable {
    let id = UUID()
    let message: String
    let isGood: Bool
}
