import Vision
import CoreGraphics

class PoseDetectionManager {
    static let shared = PoseDetectionManager()

    typealias Joints = [VNHumanBodyPoseObservation.JointName: VNRecognizedPoint]

    /// Width / height of the upright camera image. Vision returns points in a
    /// 0...1 square, so we need this to measure real angles.
    private var imageAspect: CGFloat = 9.0 / 16.0

    /// Joints Vision is less sure about than this are treated as not visible.
    private let minimumConfidence: Float = 0.3

    // Smoothed angles, so the tips don't flicker from frame to frame.
    private var smoothedElbowAngle: CGFloat?
    private var smoothedBodyAngle: CGFloat?
    private let smoothing: CGFloat = 0.4

    /// `orientation` describes how the camera buffer is rotated for a phone held in
    /// portrait: `.leftMirrored` for the front camera, `.right` for the back camera.
    func detectPose(from pixelBuffer: CVPixelBuffer,
                    orientation: CGImagePropertyOrientation = .leftMirrored,
                    completion: @escaping (Joints?) -> Void) {
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: orientation)
        let request = VNDetectHumanBodyPoseRequest()

        // The buffer is landscape; the upright image has width and height swapped.
        let bufferWidth = CGFloat(CVPixelBufferGetWidth(pixelBuffer))
        let bufferHeight = CGFloat(CVPixelBufferGetHeight(pixelBuffer))
        let aspect = bufferWidth > 0 ? bufferHeight / bufferWidth : 9.0 / 16.0

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try handler.perform([request])

                if let observation = request.results?.first {
                    let joints = try observation.recognizedPoints(.all)
                    DispatchQueue.main.async {
                        self.imageAspect = aspect
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

    // MARK: - Push-up analysis

    /// Analyzes a push-up seen from the side. Uses joint angles (not raw x/y
    /// positions), on whichever side of the body the camera sees best.
    func analyzePushUpForm(joints: Joints) -> [FormFeedback] {
        guard let side = bestVisibleSide(in: joints) else {
            resetSmoothing()
            return [FormFeedback(message: "⚠️ Step back so your whole body is in view, side-on to the camera", isGood: false)]
        }

        // Standing or sitting up: the torso is closer to vertical than horizontal.
        let torsoTilt = tiltFromHorizontal(from: side.hip, to: side.shoulder)
        if torsoTilt > 45 {
            resetSmoothing()
            return [FormFeedback(message: "⚠️ Get into push-up position, side-on to the camera", isGood: false)]
        }

        var feedback: [FormFeedback] = []

        // 1. Body line: shoulder – hip – ankle (or knee) should be nearly straight.
        if let lowerPoint = side.ankle ?? side.knee {
            let rawAngle = angle(at: side.hip, from: side.shoulder, to: lowerPoint)
            let bodyAngle = smooth(rawAngle, previous: &smoothedBodyAngle)

            if bodyAngle >= 160 {
                feedback.append(FormFeedback(message: "✓ Body is straight", isGood: true))
            } else if hipIsBelowLine(hip: side.hip, shoulder: side.shoulder, lower: lowerPoint) {
                feedback.append(FormFeedback(message: "⚠️ Hips are sagging – tighten your core", isGood: false))
            } else {
                feedback.append(FormFeedback(message: "⚠️ Hips are too high – lower them", isGood: false))
            }
        } else {
            smoothedBodyAngle = nil
            feedback.append(FormFeedback(message: "⚠️ Legs not in view – move the phone back", isGood: false))
        }

        // 2. Depth: elbow angle between shoulder – elbow – wrist.
        if let elbow = side.elbow, let wrist = side.wrist {
            let rawAngle = angle(at: elbow, from: side.shoulder, to: wrist)
            let elbowAngle = smooth(rawAngle, previous: &smoothedElbowAngle)

            if elbowAngle <= 100 {
                feedback.append(FormFeedback(message: "✓ Good depth – push back up", isGood: true))
            } else if elbowAngle >= 155 {
                feedback.append(FormFeedback(message: "✓ Arms extended – lower your chest", isGood: true))
            } else {
                feedback.append(FormFeedback(message: "⚠️ Go deeper – bend elbows to 90°", isGood: false))
            }
        } else {
            smoothedElbowAngle = nil
            feedback.append(FormFeedback(message: "⚠️ Arm not in view", isGood: false))
        }

        return feedback
    }

    // MARK: - Helpers

    private struct BodySide {
        let shoulder: CGPoint
        let hip: CGPoint
        let elbow: CGPoint?
        let wrist: CGPoint?
        let knee: CGPoint?
        let ankle: CGPoint?
        let score: Float
    }

    /// A joint's position in aspect-corrected units, or nil if Vision isn't confident in it.
    private func point(_ name: VNHumanBodyPoseObservation.JointName, in joints: Joints) -> (CGPoint, Float)? {
        guard let joint = joints[name], joint.confidence >= minimumConfidence else { return nil }
        return (CGPoint(x: joint.location.x * imageAspect, y: joint.location.y), joint.confidence)
    }

    private func side(in joints: Joints,
                      shoulder: VNHumanBodyPoseObservation.JointName,
                      elbow: VNHumanBodyPoseObservation.JointName,
                      wrist: VNHumanBodyPoseObservation.JointName,
                      hip: VNHumanBodyPoseObservation.JointName,
                      knee: VNHumanBodyPoseObservation.JointName,
                      ankle: VNHumanBodyPoseObservation.JointName) -> BodySide? {
        // Shoulder and hip are the minimum needed to say anything.
        guard let s = point(shoulder, in: joints), let h = point(hip, in: joints) else { return nil }
        let e = point(elbow, in: joints)
        let w = point(wrist, in: joints)
        let k = point(knee, in: joints)
        let a = point(ankle, in: joints)
        let score = s.1 + h.1 + (e?.1 ?? 0) + (w?.1 ?? 0) + (k?.1 ?? 0) + (a?.1 ?? 0)
        return BodySide(shoulder: s.0, hip: h.0, elbow: e?.0, wrist: w?.0, knee: k?.0, ankle: a?.0, score: score)
    }

    /// The side of the body (left or right) the camera sees more clearly.
    private func bestVisibleSide(in joints: Joints) -> BodySide? {
        let left = side(in: joints, shoulder: .leftShoulder, elbow: .leftElbow, wrist: .leftWrist,
                        hip: .leftHip, knee: .leftKnee, ankle: .leftAnkle)
        let right = side(in: joints, shoulder: .rightShoulder, elbow: .rightElbow, wrist: .rightWrist,
                         hip: .rightHip, knee: .rightKnee, ankle: .rightAnkle)
        switch (left, right) {
        case let (l?, r?): return l.score >= r.score ? l : r
        case let (l?, nil): return l
        case let (nil, r?): return r
        default: return nil
        }
    }

    /// Angle in degrees at `vertex`, between the lines to `a` and `b` (0...180).
    private func angle(at vertex: CGPoint, from a: CGPoint, to b: CGPoint) -> CGFloat {
        let v1 = CGVector(dx: a.x - vertex.x, dy: a.y - vertex.y)
        let v2 = CGVector(dx: b.x - vertex.x, dy: b.y - vertex.y)
        let length1 = hypot(v1.dx, v1.dy)
        let length2 = hypot(v2.dx, v2.dy)
        guard length1 > 0, length2 > 0 else { return 180 }
        let cosine = max(-1, min(1, (v1.dx * v2.dx + v1.dy * v2.dy) / (length1 * length2)))
        return acos(cosine) * 180 / .pi
    }

    /// How far the line a→b is from horizontal, in degrees (0 = flat, 90 = upright).
    private func tiltFromHorizontal(from a: CGPoint, to b: CGPoint) -> CGFloat {
        atan2(abs(b.y - a.y), abs(b.x - a.x)) * 180 / .pi
    }

    /// True if the hip is under the straight line from shoulder to ankle/knee.
    /// Vision's y axis points up, so "below" means a smaller y.
    private func hipIsBelowLine(hip: CGPoint, shoulder: CGPoint, lower: CGPoint) -> Bool {
        let dx = lower.x - shoulder.x
        guard abs(dx) > 0.0001 else { return false }
        let t = (hip.x - shoulder.x) / dx
        let lineY = shoulder.y + t * (lower.y - shoulder.y)
        return hip.y < lineY
    }

    private func smooth(_ value: CGFloat, previous: inout CGFloat?) -> CGFloat {
        let result = previous.map { $0 + smoothing * (value - $0) } ?? value
        previous = result
        return result
    }

    private func resetSmoothing() {
        smoothedElbowAngle = nil
        smoothedBodyAngle = nil
    }
}

struct FormFeedback: Identifiable {
    let id = UUID()
    let message: String
    let isGood: Bool
}
