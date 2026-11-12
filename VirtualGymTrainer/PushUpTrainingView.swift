import SwiftUI
import AVFoundation

struct FormTip: Identifiable {
    let id = UUID()
    let message: String
    let isGood: Bool
}

struct PushUpTrainingView: View {
    @Binding var isPresented: Bool
    @State private var elapsedTime = 0
    @State private var timer: Timer?
    @State private var tips: [FormTip] = []
    @State private var isDetecting = true
    @State private var useFrontCamera = true
    @State private var repCount = 0

    private func handlePoseDetected(_ feedback: [FormFeedback], repCount: Int) {
        self.repCount = repCount
        tips = feedback.map { FormTip(message: $0.message, isGood: $0.isGood) }
    }

    private func handlePoseFailed() {
        isDetecting = false
        // Nobody in view: drop the old tips instead of leaving stale ones on screen.
        tips = []
    }

    var body: some View {
        ZStack {
            // Camera background with pose detection
            CameraViewRepresentable(
                cameraPosition: useFrontCamera ? .front : .back,
                onPoseDetected: handlePoseDetected,
                onPoseFailed: handlePoseFailed
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Text("Push-up Training")
                        .font(.headline)
                        .foregroundColor(.white)

                    Spacer()

                    Button(action: {
                        useFrontCamera.toggle()
                        tips = []
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.triangle.2.circlepath.camera.fill")
                            Text(useFrontCamera ? "Front" : "Back")
                        }
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.black.opacity(0.5))
                        .cornerRadius(8)
                    }
                    .accessibilityLabel(useFrontCamera ? "Switch to back camera" : "Switch to front camera")

                    Text("\(elapsedTime)s")
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.black.opacity(0.5))
                        .cornerRadius(8)
                }
                .padding()
                .background(Color.black.opacity(0.3))

                Spacer()

                VStack(spacing: 16) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("Live Form Analysis")
                            .font(.headline)
                            .foregroundColor(.white)

                        Spacer()

                        Text("\(repCount)")
                            .font(.system(size: 44, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundColor(.white)
                            .contentTransition(.numericText())
                            .animation(.default, value: repCount)
                        Text(repCount == 1 ? "rep" : "reps")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Live form analysis, \(repCount) \(repCount == 1 ? "rep" : "reps")")

                    if tips.isEmpty {
                        VStack {
                            ProgressView()
                                .tint(.white)
                            Text("Analyzing your form...")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        .padding()
                        .frame(height: 100)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(12)
                    } else {
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(tips) { tip in
                                TipRow(icon: tip.isGood ? "checkmark.circle.fill" : "exclamationmark.circle.fill",
                                      text: tip.message,
                                      color: tip.isGood ? .green : .orange)
                            }
                        }
                        .padding()
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(12)
                    }
                }
                .padding()
                .background(Color.black.opacity(0.2))

                HStack(spacing: 12) {
                    Button(action: { isPresented = false }) {
                        HStack {
                            Image(systemName: "xmark.circle.fill")
                            Text("Done")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red.opacity(0.7))
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                }
                .padding()
                .background(Color.black.opacity(0.3))
            }
        }
        .onAppear {
            startTimer()
        }
        .onDisappear {
            stopTimer()
        }
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            elapsedTime += 1
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}

struct TipRow: View {
    let icon: String
    let text: String
    let color: Color

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
            Text(text)
                .foregroundColor(.white)
            Spacer()
        }
        .font(.subheadline)
    }
}

#Preview {
    PushUpTrainingView(isPresented: .constant(true))
}
